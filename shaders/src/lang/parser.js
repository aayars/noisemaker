/**
 * Recursive-descent parser for the Polymorphic DSL.
 *
 * Grammar (EBNF):
 * Program        ::= Statement* RenderDirective?
 * Statement      ::= VarAssign | ChainStmt | IfStmt | LoopStmt | Break | Continue | Return
 * RenderDirective::= 'render' '(' OutputRef ')'
 * Block          ::= '{' Statement* '}'
 * IfStmt         ::= 'if' '(' Expr ')' Block ('elif' '(' Expr ')' Block)* ('else' Block)?
 * LoopStmt       ::= 'loop' Expr? Block
 * Break          ::= 'break'
 * Continue       ::= 'continue'
 * Return         ::= 'return' Expr?
 * VarAssign      ::= 'let' Ident '=' Expr
 * ChainStmt      ::= Chain ('.out(' OutputRef? ')')?
 * Chain          ::= Call ('.' Call)*
 * Expr           ::= Chain | NumberExpr | String | Boolean | Color | Ident | Member | OutputRef | SourceRef | Func | '(' Expr ')'
 * Call           ::= Ident '(' ArgList? ')'
 * ArgList        ::= Arg (',' Arg)* ','?
 * Arg            ::= NumberExpr | String | Boolean | Color | Ident | Member | OutputRef | SourceRef | Func
 * NumberExpr     ::= Number | 'Math.PI' | '(' NumberExpr ')' | NumberExpr ( '+' | '-' | '*' | '/' ) NumberExpr
 * Member         ::= Ident ('.' Ident)+
 * Func           ::= '(' ')' '=>' Expr
 * OutputRef      ::= 'o' Digit
 * Ident          ::= Letter ( Letter | Digit | '_' )*
 * Number         ::= Digit+ ( '.' Digit+ )?
 * String         ::= '"' [^"\n]* '"'
 * Digit          ::= '0'…'9'
 * Letter         ::= 'A'…'Z' | 'a'…'z'
 * Boolean        ::= 'true' | 'false'
 * Color          ::= '#' HexDigit HexDigit HexDigit ( HexDigit HexDigit HexDigit )?
 * HexDigit       ::= Digit | 'A'…'F' | 'a'…'f'
 * @param {Array} tokens Token stream from the lexer
 * @returns {object} AST
 */
export function parse(tokens) {
    let current = 0
    let loopDepth = 0

    const DEFAULT_NAMESPACE_ORDER = Object.freeze(['basics', 'nd'])

    function buildNamespaceSearchOrder(primary = null) {
        const order = []
        const seen = new Set()
        const append = (value) => {
            if (typeof value !== 'string') { return }
            const trimmed = value.trim()
            if (!trimmed || seen.has(trimmed)) { return }
            seen.add(trimmed)
            order.push(trimmed)
        }
        append(primary)
        DEFAULT_NAMESPACE_ORDER.forEach(append)
        return order
    }

    const namespaceStack = [{
        name: DEFAULT_NAMESPACE_ORDER[0],
        source: 'implicit',
        explicit: false
    }]
    const programNamespace = {
        imports: DEFAULT_NAMESPACE_ORDER.map((name) => ({
            name,
            source: 'implicit',
            explicit: false
        })),
        default: { name: DEFAULT_NAMESPACE_ORDER[0], source: 'implicit', explicit: false }
    }
    let namespaceDeclaration = null

    const peek = () => tokens[current]
    const advance = () => tokens[current++]
    const expect = (type, msg) => {
        const token = peek()
        if (token.type === type) return advance()
        throw new SyntaxError(`${msg} at line ${token.line} col ${token.col}`)
    }

    const exprStartTokens = new Set([
        'PLUS', 'MINUS', 'NUMBER', 'STRING', 'HEX', 'FUNC',
        'IDENT', 'OUTPUT_REF', 'SOURCE_REF', 'LPAREN',
        'TRUE', 'FALSE'
    ])

    const memberTokenTypes = new Set([
        'IDENT', 'SOURCE_REF', 'OUTPUT_REF',
        'LET', 'RENDER', 'TRUE', 'FALSE', 'IF', 'ELIF', 'ELSE',
        'LOOP', 'BREAK', 'CONTINUE', 'RETURN', 'OUT'
    ])

    const cloneNamespaceMeta = (meta) => {
        if (!meta || typeof meta !== 'object') { return null }
        try {
            if (typeof structuredClone === 'function') {
                return structuredClone(meta)
            }
        } catch {
            // fall back to JSON clone
        }
        try {
            return JSON.parse(JSON.stringify(meta))
        } catch {
            return null
        }
    }

    const getActiveNamespace = () => namespaceStack[namespaceStack.length - 1] || null

    function pushNamespaceContext(name, source = 'namespace') {
        const active = getActiveNamespace()
        const resolvedName = (typeof name === 'string' && name.trim()) || active?.name || DEFAULT_NAMESPACE_ORDER[0]
        namespaceStack.push({
            name: resolvedName,
            source,
            explicit: source === 'explicit'
        })
    }

    function popNamespaceContext() {
        if (namespaceStack.length <= 1) { return }
        namespaceStack.pop()
    }

    function buildCallNamespace(prefixSegments) {
        const segments = Array.isArray(prefixSegments) ? prefixSegments : []
        if (segments.length > 0) {
            const resolved = segments.join('.')
            return {
                name: resolved,
                path: segments.slice(),
                explicit: true,
                source: 'qualified',
                resolved,
                defaulted: false
            }
        }
        const active = getActiveNamespace()
        if (!active || !active.name) { return null }
        if (!active.source) {
            throw new Error(`Parser bug: active namespace "${active.name}" has no source`)
        }
        return {
            name: active.name,
            path: [],
            explicit: false,
            source: active.source,
            resolved: active.name,
            defaulted: true
        }
    }

    function transformFromInvocation(call, nameToken) {
        const fail = (message) => {
            if (nameToken && typeof nameToken.line === 'number' && typeof nameToken.col === 'number') {
                throw new SyntaxError(`${message} at line ${nameToken.line} col ${nameToken.col}`)
            }
            throw new SyntaxError(message)
        }
        if (call.kwargs && Object.keys(call.kwargs).length) {
            fail("'from' does not support named arguments")
        }
        const args = Array.isArray(call.args) ? call.args : []
        if (args.length !== 2) {
            fail("'from' requires exactly two arguments (namespace, call)")
        }
        const [namespaceArg, targetArg] = args
        if (!namespaceArg || namespaceArg.type !== 'String' || typeof namespaceArg.value !== 'string') {
            fail("'from' namespace argument must be a string literal")
        }
        const namespaceName = namespaceArg.value.trim()
        if (!namespaceName) {
            fail("'from' namespace argument must be non-empty")
        }
        let targetCall = null
        if (targetArg && targetArg.type === 'Call') {
            targetCall = targetArg
        } else if (targetArg && targetArg.type === 'Chain' && Array.isArray(targetArg.chain) && targetArg.chain.length === 1) {
            const head = targetArg.chain[0]
            if (head && head.type === 'Call') {
                targetCall = head
            }
        }
        if (!targetCall) {
            fail("'from' second argument must be a call expression")
        }
        const replacement = {
            ...targetCall,
            args: Array.isArray(targetCall.args) ? targetCall.args.map((arg) => arg) : []
        }
        if (targetCall.kwargs) {
            replacement.kwargs = { ...targetCall.kwargs }
        }
        const existingNamespace = targetCall.namespace && typeof targetCall.namespace === 'object'
            ? targetCall.namespace
            : null
        const overrideNamespace = {
            name: namespaceName,
            path: [namespaceName],
            explicit: true,
            source: 'from',
            resolved: namespaceName,
            defaulted: false,
            searchOrder: buildNamespaceSearchOrder(namespaceName),
            fromOverride: true
        }
        replacement.namespace = existingNamespace
            ? { ...existingNamespace, ...overrideNamespace }
            : overrideNamespace
        return replacement
    }

    function hasCallAfterDot(index) {
        let i = index + 1
        if (tokens[i]?.type !== 'DOT') { return false }
        while (tokens[i]?.type === 'DOT') {
            const segToken = tokens[i + 1]
            if (!segToken || !memberTokenTypes.has(segToken.type)) { return false }
            i += 2
        }
        return tokens[i]?.type === 'LPAREN'
    }

    function parseRenderDirective() {
        advance()
        expect('LPAREN', "Expect '('")
        if (peek().type !== 'OUTPUT_REF') {
            throw new SyntaxError('Expected output reference in render()')
        }
        const out = { type: 'OutputRef', name: advance().lexeme }
        expect('RPAREN', "Expect ')'")
        return out
    }

    function parseProgram() {
        const plans = []
        const vars = []
        let render = null
        let consumedNamespaceBlock = false

        const appendStatement = (stmt) => {
            if (!stmt || typeof stmt !== 'object') { return }
            if (stmt.type === 'VarAssign') {
                vars.push(stmt)
            } else {
                plans.push(stmt)
            }
        }

        const consumeRender = () => {
            if (render) {
                const t = peek()
                throw new SyntaxError(`Duplicate render() directive at line ${t.line} col ${t.col}`)
            }
            render = parseRenderDirective()
            while (peek().type === 'SEMICOLON') advance()
        }

        function parseNamespaceBlock() {
            if (consumedNamespaceBlock) {
                const t = peek()
                throw new SyntaxError(`Only one namespace block is allowed per program at line ${t.line} col ${t.col}`)
            }
            consumedNamespaceBlock = true
            advance()
            const nameToken = expect('IDENT', 'Expected namespace identifier')
            const namespaceName = nameToken.lexeme
            expect('LBRACE', "Expect '{' after namespace declaration")
            pushNamespaceContext(namespaceName, 'namespace')
            const blockVars = []
            const blockPlans = []
            let blockRender = null
            while (peek().type !== 'RBRACE') {
                if (peek().type === 'RENDER') {
                    if (blockRender || render) {
                        const t = peek()
                        throw new SyntaxError(`Duplicate render() directive at line ${t.line} col ${t.col}`)
                    }
                    blockRender = parseRenderDirective()
                } else {
                    const stmt = parseStatement()
                    if (stmt.type === 'VarAssign') blockVars.push(stmt)
                    else blockPlans.push(stmt)
                }
                while (peek().type === 'SEMICOLON') advance()
            }
            expect('RBRACE', "Expect '}' after namespace block")
            popNamespaceContext()
            if (blockVars.length) { vars.push(...blockVars) }
            if (blockPlans.length) { plans.push(...blockPlans) }
            if (blockRender) { render = blockRender }
            namespaceDeclaration = {
                name: namespaceName,
                explicit: true,
                source: 'namespace',
                default: {
                    name: namespaceName,
                    explicit: false,
                    source: 'namespace'
                }
            }
            while (peek().type === 'SEMICOLON') advance()
        }

        while (peek().type !== 'EOF') {
            if (peek().type === 'SEMICOLON') { advance(); continue }
            if (peek().type === 'NAMESPACE') {
                if (plans.length || vars.length || render) {
                    const t = peek()
                    throw new SyntaxError(`'namespace' block must appear before other statements at line ${t.line} col ${t.col}`)
                }
                parseNamespaceBlock()
                continue
            }
            if (peek().type === 'RENDER') {
                consumeRender()
                break
            }
            const stmt = parseStatement()
            appendStatement(stmt)
            while (peek().type === 'SEMICOLON') advance()
        }
        expect('EOF', 'Expected end of input')
        const program = { type: 'Program', plans, render }
        if (vars.length) { program.vars = vars }
        let namespaceMeta = cloneNamespaceMeta({
            imports: programNamespace.imports,
            default: programNamespace.default,
            declaration: namespaceDeclaration ? { ...namespaceDeclaration } : null
        })
        if (!namespaceMeta) {
            const importsClone = programNamespace.imports.map((entry) => ({ ...entry }))
            const defaultClone = { ...programNamespace.default }
            const declarationClone = namespaceDeclaration ? { ...namespaceDeclaration } : null
            namespaceMeta = { imports: importsClone, default: defaultClone, declaration: declarationClone }
        }
        program.namespace = namespaceMeta
        return program
    }

    function parseBlock() {
        expect('LBRACE', "Expect '{'")
        const body = []
        while (peek().type !== 'RBRACE') {
            const stmt = parseStatement()
            body.push(stmt)
            while (peek().type === 'SEMICOLON') advance()
        }
        expect('RBRACE', "Expect '}'")
        return body
    }

    function parseStatement() {
        if (peek().type === 'NAMESPACE') {
            const t = peek()
            throw new SyntaxError(`'namespace' blocks are only allowed at the top level at line ${t.line} col ${t.col}`)
        }
        if (peek().type === 'LET') {
            advance()
            const name = expect('IDENT', 'Expected identifier').lexeme
            expect('EQUAL', "Expect '='")
            if (!exprStartTokens.has(peek().type)) {
                const t = peek()
                throw new SyntaxError(`Expected expression after '=' at line ${t.line} col ${t.col}`)
            }
            const expr = parseAdditive()
            return {type: 'VarAssign', name, expr}
        }

        switch (peek().type) {
            case 'IF': {
                advance()
                expect('LPAREN', "Expect '('")
                const condition = parseAdditive()
                expect('RPAREN', "Expect ')'")
                const then = parseBlock()
                const elif = []
                while (peek().type === 'ELIF') {
                    advance()
                    expect('LPAREN', "Expect '('")
                    const ec = parseAdditive()
                    expect('RPAREN', "Expect ')'")
                    const body = parseBlock()
                    elif.push({condition: ec, then: body})
                }
                let elseBranch = null
                if (peek().type === 'ELSE') {
                    advance()
                    elseBranch = parseBlock()
                }
                return {type: 'IfStmt', condition, then, elif, else: elseBranch}
            }
            case 'LOOP': {
                advance()
                let condition = null
                if (peek().type !== 'LBRACE') {
                    condition = parseAdditive()
                }
                loopDepth++
                const body = parseBlock()
                loopDepth--
                const node = {type: 'LoopStmt', body}
                if (condition) node.condition = condition
                return node
            }
            case 'BREAK': {
                if (loopDepth === 0) {
                    const t = peek()
                    throw new SyntaxError(`'break' outside loop at line ${t.line} col ${t.col}`)
                }
                advance()
                return {type: 'Break'}
            }
            case 'CONTINUE': {
                if (loopDepth === 0) {
                    const t = peek()
                    throw new SyntaxError(`'continue' outside loop at line ${t.line} col ${t.col}`)
                }
                advance()
                return {type: 'Continue'}
            }
            case 'RETURN': {
                advance()
                if (exprStartTokens.has(peek().type)) {
                    const value = parseAdditive()
                    return {type: 'Return', value}
                }
                return {type: 'Return'}
            }
        }

        const chain = parseChain()
        let out = null
        if (peek().type === 'DOT' && tokens[current + 1]?.type === 'OUT') {
            advance() // consume '.'
            advance() // consume 'out'
            expect('LPAREN', "Expect '('")
            if (peek().type === 'OUTPUT_REF') {
                out = {type: 'OutputRef', name: advance().lexeme}
            }
            expect('RPAREN', "Expect ')'")
            // default to o0 when .out() has no argument
            if (!out) {
                out = {type: 'OutputRef', name: 'o0'}
            }
        }
        // If no .out() is present, out remains null.
        // The validator will check if this is allowed (e.g. for non-generator chains or nested usage).
        
        return {chain, out}
    }

    function parseChain(context = 'statement') {
        const calls = [parseCall()]
        while (peek().type === 'DOT') {
            if (tokens[current + 1]?.type === 'OUT') {
                if (context === 'expression') {
                    const t = tokens[current + 1]
                    throw new SyntaxError(`'.out()' is only allowed at the end of a statement at line ${t.line} col ${t.col}`)
                }
                break
            }
            advance() // consume '.'
            calls.push(parseCall())
        }
        return calls
    }

    function parseCall() {
        const nameToken = expect('IDENT', 'Expected identifier')
        const segments = [nameToken.lexeme]
        while (peek().type === 'DOT') {
            const next = tokens[current + 1]
            if (!next || !memberTokenTypes.has(next.type)) { break }
            
            // Stop if we see .out( which indicates the end of the chain
            if (next.type === 'OUT' && tokens[current + 2]?.type === 'LPAREN') {
                break
            }

            const after = tokens[current + 2]
            if (after?.type !== 'LPAREN' && after?.type !== 'DOT') { break }
            advance() // consume '.'
            advance() // consume segment token stored in next
            segments.push(next.lexeme)
        }
        expect('LPAREN', "Expect '('")
        const args = []
        const kwargs = {}
        let keyword = false
        if (peek().type !== 'RPAREN') {
            if (peek().type === 'IDENT' && tokens[current + 1]?.type === 'COLON') {
                keyword = true
                parseKwarg(kwargs)
                while (peek().type === 'COMMA') {
                    advance()
                    if (peek().type === 'RPAREN') break
                    if (!(peek().type === 'IDENT' && tokens[current + 1]?.type === 'COLON')) {
                        const t = peek()
                        throw new SyntaxError(`Cannot mix positional and keyword arguments at line ${t.line} col ${t.col}`)
                    }
                    parseKwarg(kwargs)
                }
            } else {
                args.push(parseArg())
                while (peek().type === 'COMMA') {
                    advance()
                    if (peek().type === 'RPAREN') break
                    if (peek().type === 'IDENT' && tokens[current + 1]?.type === 'COLON') {
                        const t = peek()
                        throw new SyntaxError(`Cannot mix positional and keyword arguments at line ${t.line} col ${t.col}`)
                    }
                    args.push(parseArg())
                }
            }
        }
        expect('RPAREN', "Expect ')'")
        const callName = segments[segments.length - 1]
        const namespaceInfo = buildCallNamespace(segments.slice(0, -1))
        const call = {type: 'Call', name: callName, args}
        if (keyword) call.kwargs = kwargs
        if (callName === 'from') {
            return transformFromInvocation(call, nameToken)
        }
        if (namespaceInfo) { call.namespace = namespaceInfo }
        return call
    }

    function parseArg() {
        return parseAdditive()
    }

    function parseAdditive() {
        let node = parseMultiplicative()
        while (peek().type === 'PLUS' || peek().type === 'MINUS') {
            const op = advance().type
            const right = parseMultiplicative()
            const l = toNumber(node)
            const r = toNumber(right)
            node = {type: 'Number', value: op === 'PLUS' ? l + r : l - r}
        }
        return node
    }

    function parseMultiplicative() {
        let node = parseUnary()
        while (peek().type === 'STAR' || peek().type === 'SLASH') {
            const op = advance().type
            const right = parseUnary()
            const l = toNumber(node)
            const r = toNumber(right)
            node = {type: 'Number', value: op === 'STAR' ? l * r : l / r}
        }
        return node
    }

    function parseUnary() {
        if (peek().type === 'PLUS') {
            advance()
            return parseUnary()
        }
        if (peek().type === 'MINUS') {
            advance()
            const val = parseUnary()
            return {type: 'Number', value: -toNumber(val)}
        }
        return parsePrimary()
    }

    function parsePrimary() {
        const token = peek()
        switch (token.type) {
            case 'NUMBER':
                advance()
                return {type: 'Number', value: parseFloat(token.lexeme)}
            case 'STRING':
                advance()
                return {type: 'String', value: token.lexeme}
            case 'HEX': {
                advance()
                const hex = token.lexeme.slice(1)
                let r, g, b, a = 1.0
                if (hex.length === 3) {
                    r = parseInt(hex[0] + hex[0], 16)
                    g = parseInt(hex[1] + hex[1], 16)
                    b = parseInt(hex[2] + hex[2], 16)
                } else if (hex.length === 6) {
                    r = parseInt(hex.slice(0, 2), 16)
                    g = parseInt(hex.slice(2, 4), 16)
                    b = parseInt(hex.slice(4, 6), 16)
                } else if (hex.length === 8) {
                    r = parseInt(hex.slice(0, 2), 16)
                    g = parseInt(hex.slice(2, 4), 16)
                    b = parseInt(hex.slice(4, 6), 16)
                    a = parseInt(hex.slice(6, 8), 16) / 255
                }
                return {type: 'Color', value: [r / 255, g / 255, b / 255, a]}
            }
            case 'FUNC':
                advance()
                return {type: 'Func', src: token.lexeme}
            case 'TRUE':
                advance()
                return {type: 'Boolean', value: true}
            case 'FALSE':
                advance()
                return {type: 'Boolean', value: false}
            case 'IDENT': {
                if (token.lexeme === 'Math' && tokens[current + 1]?.type === 'DOT' && tokens[current + 2]?.type === 'IDENT' && tokens[current + 2].lexeme === 'PI') {
                    advance()
                    advance()
                    advance()
                    return {type: 'Number', value: Math.PI}
                }
                if (tokens[current + 1]?.type === 'LPAREN' || hasCallAfterDot(current)) {
                    const chain = parseChain('expression')
                    return chain.length === 1 ? chain[0] : {type: 'Chain', chain}
                }
                // handle dotted enum paths like foo.bar.baz. Enum segments may
                // include tokens that would otherwise be treated as keywords or
                // source/output references (e.g. `sparky.loop.tri`,
                // `disp.source.o1`). Allow a broader set of token types in
                // member chains and only terminate when the segment is followed
                // by a call expression.
                advance()
                const path = [token.lexeme]
                while (peek().type === 'DOT') {
                    const next = tokens[current + 1]
                    if (!next) break
                    if (tokens[current + 2]?.type === 'LPAREN') break
                    if (!memberTokenTypes.has(next.type)) {
                        throw new SyntaxError(`Expected identifier after '.' at line ${next.line} col ${next.col}`)
                    }
                    advance() // consume '.'
                    advance() // consume segment token stored in next
                    path.push(next.lexeme)
                }
                if (path.length > 1) {
                    return {type: 'Member', path}
                }
                return {type: 'Ident', name: path[0]}
            }
            case 'OUTPUT_REF':
                advance()
                return {type: 'OutputRef', name: token.lexeme}
            case 'SOURCE_REF':
                advance()
                return {type: 'SourceRef', name: token.lexeme}
            case 'LPAREN': {
                advance()
                const expr = parseAdditive()
                expect('RPAREN', "Expect ')'")
                return expr
            }
            default:
                throw new SyntaxError(`Unexpected token ${token.type} at line ${token.line} col ${token.col}`)
        }
    }

    function toNumber(node) {
        if (node.type !== 'Number') {
            throw new SyntaxError('Expected number')
        }
        return node.value
    }

    function parseKwarg(obj) {
        const key = expect('IDENT', 'Expected identifier').lexeme
        expect('COLON', "Expect ':'")
        if (!exprStartTokens.has(peek().type)) {
            const t = peek()
            throw new SyntaxError(`Expected expression after '=' at line ${t.line} col ${t.col}`)
        }
        obj[key] = parseArg()
    }

    return parseProgram()
}
