import diagnostics from './diagnostics.js'
import enums from './enums.js'
import { ops } from './ops.js'
import { normalizeMemberPath, pathStartsWith, applyEnumPrefix } from './enumPaths.js'
import { resolveCallTarget } from './namespaceRuntime.js'

const stateSurfaces = new Set(['time','frame','mouse','resolution','seed','a'])
const stateValues = new Set(['time','frame','mouse','resolution','seed','a','u1','u2','u3','u4','s1','s2','b1','b2','a1','a2','deltaTime'])
const STARTER_OPS = new Set([
    'cell','fractal','n','n3','pattern','shapes','noisemaker',
    'gradient','noise','osc','solid'
])

const SURFACE_PASSTHROUGH_CALLS = new Set(['src'])
const validatorHooks = {}

export function registerValidatorHook(name, hook) {
    if (typeof name === 'string' && typeof hook === 'function') {
        validatorHooks[name] = hook
    }
}

export function registerStarterOps(names = []) {
    if (!Array.isArray(names)) { return }
    names.forEach((name) => {
        if (typeof name === 'string' && name) {
            STARTER_OPS.add(name)
        }
    })
}

export function isStarterOp(name) {
    if (typeof name !== 'string') { return false }
    // Check exact name first
    if (STARTER_OPS.has(name)) { return true }
    // For namespaced names like nm.voronoi
    const parts = name.split('.')
    if (parts.length > 1) {
        const canonical = parts[parts.length - 1]
        // If the bare canonical is a starter, check if any namespaced version exists
        if (STARTER_OPS.has(canonical)) {
            // Look for any "X.canonical" in STARTER_OPS
            for (const op of STARTER_OPS) {
                if (op.endsWith('.' + canonical)) {
                    // A namespaced starter exists (e.g., basics.voronoi)
                    // Since our exact name (nm.voronoi) wasn't found, we're not a starter
                    return false
                }
            }
            // No namespaced version - bare name applies
            return true
        }
    }
    return false
}

export function clamp(value, min, max) {
    if (typeof min === 'number' && value < min) return min
    if (typeof max === 'number' && value > max) return max
    return value
}

function toBoolean(value) {
    return typeof value === 'number' ? value !== 0 : !!value
}

function toSurface(arg) {
    if (!arg) return null
    if (arg.type === 'OutputRef') return {kind:'output', name:arg.name}
    if (arg.type === 'FeedbackRef') return {kind:'feedback', name:arg.name}
    if (arg.type === 'SourceRef') return {kind:'source', name:arg.name}
    if (arg.type === 'Ident' && stateSurfaces.has(arg.name)) return {kind:'state', name:arg.name}
    return null
}

function callToSurface(node) {
    if (!node || typeof node !== 'object') { return null }
    if (node.type === 'Chain' && Array.isArray(node.chain) && node.chain.length === 1) {
        return callToSurface(node.chain[0])
    }
    if (node.type !== 'Call' || !SURFACE_PASSTHROUGH_CALLS.has(node.name)) { return null }
    let target = null
    if (Array.isArray(node.args) && node.args.length) {
        target = node.args[0]
    }
    if (!target && node.kwargs && typeof node.kwargs === 'object') {
        target = node.kwargs.tex
    }
    if (!target) { return null }
    return toSurface(target)
}

/**
 * Semantic validator producing a flattened chain with temporary surfaces
 * @param {object} ast
 * @returns {object} PlannedChain {chain, out, final, diagnostics}
 */
export function validate(ast) {
    const diagnosticsList = []
    function pushDiag(code, node, message = diagnostics[code].message) {
        // Enrich message with identifier/location context when available
        let enrichedMessage = message
        const identName = extractIdentifierName(node)
        // Only append identifier if not already in message
        if (identName && !message.includes(identName) && !message.includes("'")) {
            enrichedMessage = `${message}: '${identName}'`
        }
        // Add source location if available
        let location = null
        if (node?.loc) {
            location = { line: node.loc.line, column: node.loc.column }
        }
        diagnosticsList.push({
            code,
            message: enrichedMessage,
            severity: diagnostics[code].severity,
            nodeId: node?.id,
            ...(location && { location }),
            ...(identName && { identifier: identName })
        })
    }

    function extractIdentifierName(node) {
        if (!node) return null
        if (node.type === 'Ident') return node.name
        if (node.type === 'Member' && Array.isArray(node.path)) return node.path.join('.')
        if (node.type === 'Call') return node.name
        if (node.type === 'Func' && node.src) return `{${node.src.slice(0, 30)}${node.src.length > 30 ? '...' : ''}}`
        // Fallback: try to extract any name-like property
        if (node.name) return node.name
        if (node.value) return String(node.value)
        // Debug: show what we got
        return `[${node.type || 'unknown'}]`
    }
    const plans = []
    const render = ast.render ? parseInt(ast.render.name.slice(1), 10) : null
    let tempIndex = 0

    const programSearchOrder = ast.namespace?.searchOrder
    if (!programSearchOrder || programSearchOrder.length === 0) {
        throw new Error("Missing required 'search' directive. Every program must start with 'search <namespace>, ...' to specify namespace search order.")
    }

    const symbols = new Map()

    function resolveEnum(path) {
        if (!Array.isArray(path) || path.length === 0) return undefined
        let [head, ...rest] = path
        let cur
        if (symbols.has(head)) {
            cur = symbols.get(head)
            if (cur && (cur.type === 'Number' || cur.type === 'Boolean')) cur = cur.value
        } else if (Object.prototype.hasOwnProperty.call(enums, head)) {
            cur = enums[head]
        } else {
            return undefined
        }
        for (const part of rest) {
            if (cur && Object.prototype.hasOwnProperty.call(cur, part)) {
                cur = cur[part]
            } else {
                return undefined
            }
        }
        if (cur && (cur.type === 'Number' || cur.type === 'Boolean')) return cur.value
        return cur
    }

    function clone(node) {
        return node && typeof node === 'object' ? JSON.parse(JSON.stringify(node)) : node
    }

    function canResolveOpName(name) {
        // Check if a bare op name can resolve via the search order
        for (const ns of programSearchOrder) {
            if (ops[`${ns}.${name}`]) return true
        }
        return false
    }

    function resolveCall(call) {
        // console.log('Resolving call:', call.name, symbols.has(call.name));
        if (symbols.has(call.name)) {
            const val = symbols.get(call.name)
            // console.log('Found symbol:', val);
            if (val.type === 'Ident') {
                return {...call, name: val.name}
            }
            if (val.type === 'Call') {
                const mergedArgs = val.args ? val.args.slice() : []
                // Merge positional args: call-site args override stored args by index?
                // Actually, partial application usually appends?
                // "Positional Arguments: Appended to the stored arguments." (LANGUAGE.md)
                // My previous logic was: mergedArgs[i] = call.args[i] (Override/Overlay)
                
                // Let's fix this to APPEND.
                const callArgs = call.args || []
                for (let i = 0; i < callArgs.length; i++) {
                    mergedArgs.push(callArgs[i])
                }

                let mergedKw = val.kwargs ? {...val.kwargs} : undefined
                if (call.kwargs) {
                    mergedKw = mergedKw || {}
                    for (const [k, v] of Object.entries(call.kwargs)) mergedKw[k] = v
                }
                const merged = {type:'Call', name: val.name, args: mergedArgs}
                if (mergedKw) merged.kwargs = mergedKw
                if (call.namespace) {
                    merged.namespace = {...call.namespace}
                } else if (val.namespace) {
                    merged.namespace = {...val.namespace}
                }
                return merged
            }
        }
        return call
    }

    function firstChainCall(node) {
        if (!node || typeof node !== 'object') return null
        if (node.type === 'Call') return node
        if (node.type === 'Chain') {
            const head = node.chain && node.chain[0]
            return head && head.type === 'Call' ? head : null
        }
        return null
    }

    function getStarterInfo(node) {
        if (!node || typeof node !== 'object') return null
        if (node.type === 'Call') {
            // Build namespaced name if namespace exists
            let name = node.name
            if (node.namespace && node.namespace.resolved) {
                name = `${node.namespace.resolved}.${node.name}`
            }
            return isStarterOp(name) ? {call: node, index: 0} : null
        }
        if (node.type === 'Chain' && Array.isArray(node.chain)) {
            for (let i = 0; i < node.chain.length; i++) {
                const entry = node.chain[i]
                if (entry && entry.type === 'Call') {
                    let name = entry.name
                    if (entry.namespace && entry.namespace.resolved) {
                        name = `${entry.namespace.resolved}.${entry.name}`
                    }
                    if (isStarterOp(name)) {
                        return {call: entry, index: i}
                    }
                }
            }
        }
        return null
    }

    function isStarterChain(node) {
        if (!node || node.type !== 'Chain') return false
        const starter = getStarterInfo(node)
        return !!(starter && starter.index === 0)
    }

    function substitute(node) {
        if (!node) return node
        if (node.type === 'Ident' && symbols.has(node.name)) {
            return substitute(clone(symbols.get(node.name)))
        }
        if (node.type === 'Chain') {
            const mapped = node.chain.map(c => {
                const mappedArgs = c.args.map(a => substitute(a))
                let mappedCall = {type:'Call', name:c.name, args:mappedArgs}
                if (c.kwargs) {
                    const kw = {}
                    for (const [k,v] of Object.entries(c.kwargs)) kw[k] = substitute(v)
                    mappedCall.kwargs = kw
                }
                return resolveCall(mappedCall)
            })
            return {type:'Chain', chain:mapped}
        }
        if (node.type === 'Call') {
            const mappedArgs = node.args.map(a => substitute(a))
            let mappedCall = {type:'Call', name:node.name, args:mappedArgs}
            if (node.kwargs) {
                const kw = {}
                for (const [k,v] of Object.entries(node.kwargs)) kw[k] = substitute(v)
                mappedCall.kwargs = kw
            }
            return resolveCall(mappedCall)
        }
        return node
    }

    if (Array.isArray(ast.vars)) {
        for (const v of ast.vars) {
            const expr = substitute(clone(v.expr))
            if (expr && isStarterChain(expr)) {
                const head = firstChainCall(expr)
                if (head) pushDiag('S006', head)
            }
            if (expr == null || (expr.type === 'Ident' && (expr.name === 'null' || expr.name === 'undefined'))) {
                pushDiag('S004', v)
                continue
            }
            if (expr.type === 'Ident' && !symbols.has(expr.name) && !stateValues.has(expr.name) && !ops[expr.name] && !canResolveOpName(expr.name)) {
                pushDiag('S003', expr)
                continue
            }
            if (expr.type === 'Chain' && expr.chain.length === 1) {
                symbols.set(v.name, expr.chain[0])
            } else if (expr.type === 'Member') {
                const resolved = resolveEnum(expr.path)
                if (typeof resolved === 'number') {
                    symbols.set(v.name, {type:'Number', value: resolved})
                } else if (resolved !== undefined) {
                    symbols.set(v.name, resolved)
                } else {
                    symbols.set(v.name, expr)
                }
            } else {
                symbols.set(v.name, expr)
            }
        }
    }

    function evalExpr(node) {
        const expr = substitute(clone(node))
        if (expr && isStarterChain(expr)) {
            const head = firstChainCall(expr)
            if (head) pushDiag('S006', head)
        }
        if (expr && expr.type === 'Member') {
            const resolved = resolveEnum(expr.path)
            if (typeof resolved === 'number') return {type:'Number', value: resolved}
            if (resolved !== undefined) return resolved
        }
        return expr
    }

    function evalCondition(node) {
        const expr = evalExpr(node)
        if (!expr) return false
        if (expr.type === 'Number') return toBoolean(expr.value)
        if (expr.type === 'Boolean') return !!expr.value
        if (expr.type === 'Func') {
            try {
                const fn = new Function('state', `with(state){ return ${expr.src}; }`)
                return {fn: (state) => toBoolean(fn(state))}
            } catch {
                pushDiag('S001', expr)
                return false
            }
        }
        if (expr.type === 'Ident') {
            if (symbols.has(expr.name)) return evalCondition(symbols.get(expr.name))
            if (stateValues.has(expr.name)) {
                const key = expr.name
                return {fn:(state)=>toBoolean(state[key])}
            }
            pushDiag('S003', expr)
            return false
        }
        if (expr.type === 'Member') {
            const cur = resolveEnum(expr.path)
            if (typeof cur === 'number') return toBoolean(cur)
            if (cur !== undefined) return toBoolean(cur)
            pushDiag('S001', expr)
            return false
        }
        return false
    }

        function buildNamespaceSnapshot(callNamespace, resolution = null) {
            const snapshot = {}
            const record = resolution?.namespaceRecord || resolution?.metadata || null
            if (record) {
                snapshot.namespace = record.namespace || null
                snapshot.canonicalName = record.canonicalName || null
                snapshot.exportName = record.exportName || null
                snapshot.namespacedName = record.namespacedName || null
                snapshot.featureFlag = record.featureFlag || null
                snapshot.exportsEnabled = record.exportsEnabled === true
                snapshot.module = record.module || null
                if (Array.isArray(record.legacyNames)) {
                    snapshot.legacyNames = record.legacyNames.slice()
                }
            }
            if (callNamespace && typeof callNamespace === 'object') {
                snapshot.call = {
                    name: typeof callNamespace.name === 'string' ? callNamespace.name : null,
                    resolved: typeof callNamespace.resolved === 'string' ? callNamespace.resolved : null,
                    explicit: !!callNamespace.explicit,
                    source: typeof callNamespace.source === 'string' ? callNamespace.source : null
                }
                if (Array.isArray(callNamespace.searchOrder)) {
                    snapshot.call.searchOrder = Object.freeze(callNamespace.searchOrder.slice())
                }
                if (callNamespace.fromOverride) {
                    snapshot.call.fromOverride = true
                }
            }
            if (Object.keys(snapshot).length === 0) { return null }
            if (Array.isArray(snapshot.legacyNames)) {
                snapshot.legacyNames = Object.freeze(snapshot.legacyNames)
            }
            return Object.freeze(snapshot)
        }

    function compileChainStatement(stmt) {
        const chain = []
        
        // Check for S006: Starter chain missing out()
        const chainNode = { type: 'Chain', chain: stmt.chain }
        if (!stmt.out && isStarterChain(chainNode)) {
             pushDiag('S006', stmt.chain[0])
        }

        const outName = stmt.out ? stmt.out.name : 'o0'
        const states = []

        function processChain(calls, input, options = {}) {
            const allowStarterless = options.allowStarterless === true
            let current = input
            for (const original of calls) {
                const call = resolveCall({...original})
                const effectiveNamespace = call.namespace || { searchOrder: programSearchOrder }
                const resolution = resolveCallTarget(call.name, effectiveNamespace)
                let opName = null
                let spec = null

                const candidateNames = []
                if (resolution.namespacedName) {
                    candidateNames.push(resolution.namespacedName)
                }
                if (call.namespace && call.namespace.resolved) {
                    candidateNames.push(`${call.namespace.resolved}.${call.name}`)
                }
                const searchOrder = effectiveNamespace.searchOrder
                if (Array.isArray(searchOrder)) {
                    for (const ns of searchOrder) {
                        candidateNames.push(`${ns}.${call.name}`)
                    }
                }

                for (const candidate of candidateNames) {
                    if (candidate && ops[candidate]) {
                        opName = candidate
                        spec = ops[candidate]
                        break
                    }
                }
                if (!spec) {
                    pushDiag('S001', original)
                    continue
                }
                if (opName === 'prev') {
                    const idx = tempIndex++
                    const args = {tex:{kind:'output', name: outName}}
                    const namespaceSnapshot = buildNamespaceSnapshot(call.namespace, resolution)
                    const step = {op: opName, args, from: current, temp: idx}
                    if (namespaceSnapshot) { step.namespace = namespaceSnapshot }
                    chain.push(step)
                    current = idx
                    continue
                }
                const isStarter = isStarterOp(opName)
                const starterlessRoot = current === null
                const allowPassthroughRoot = allowStarterless && SURFACE_PASSTHROUGH_CALLS.has(opName)
                if (starterlessRoot && !isStarter && !allowPassthroughRoot) {
                    pushDiag('S005', original)
                    continue
                }
                // Use the already-resolved isStarter, not getStarterInfo which uses the bare name
                const starterHasInput = !!(isStarter && current !== null)
                const fromInput = starterHasInput ? null : current
                if (starterHasInput) {
                    pushDiag('S005', original)
                }
                const args = {}
                const kw = call.kwargs
                const seen = new Set()
                const specArgs = spec.args || []
                for (let i = 0; i < specArgs.length; i++) {
                    const def = specArgs[i]
                    let node = kw && kw[def.name] !== undefined ? kw[def.name] : call.args[i]
                    node = substitute(node)
                    const argKey = def.uniform || def.name
                    if (!kw && node && node.type === 'Color' && def.type !== 'color' && def.name === 'r' && specArgs[i + 1]?.name === 'g' && specArgs[i + 2]?.name === 'b') {
                        const [r, g, b] = node.value
                        args[argKey] = r
                        const defG = specArgs[i + 1]
                        args[defG.uniform || defG.name] = g
                        const defB = specArgs[i + 2]
                        args[defB.uniform || defB.name] = b
                        i += 2
                        continue
                    }
                    if (kw && kw[def.name] !== undefined) seen.add(def.name)
                    if (def.type === 'surface') {
                        let surf = null
                        let invalidStarterChain = false
                        const starter = node ? getStarterInfo(node) : null
                    const inlineSurface = callToSurface(node)
                    if (inlineSurface) {
                        surf = inlineSurface
                    } else if (node && node.type === 'Chain') {
                        const idx = processChain(node.chain, null, {allowStarterless: true})
                        if (idx !== null && idx !== undefined) {
                            surf = {kind:'temp', index: idx}
                        }
                    } else if (node && node.type === 'Call') {
                        const idx = processChain([node], null, {allowStarterless: true})
                        if (idx !== null && idx !== undefined) {
                            surf = {kind:'temp', index: idx}
                        }
                    } else if (starter) {
                        pushDiag('S005', starter.call)
                        invalidStarterChain = true
                    } else {
                        surf = toSurface(node)
                    }
                        if (!surf) {
                            if (invalidStarterChain) {
                                args[argKey] = surf
                                continue
                            }
                            const code = node && node.type === 'Ident' && !symbols.has(node.name) ? 'S003' : 'S001'
                            pushDiag(code, node)
                        }
                        args[argKey] = surf
                    } else if (def.type === 'string') {
                        let value
                        if (node && node.type === 'String') {
                            value = node.value
                        } else {
                            if (node && node.type && node.type !== 'Ident') {
                                pushDiag('S002', node)
                            }
                            value = def.default
                        }
                        args[argKey] = value
                    } else if (def.type === 'color') {
                        let value
                        if (node && node.type === 'Color') {
                            value = node.value.slice()
                            if (def.channels === 4) value.push(1)
                        } else {
                            if (node && node.type && node.type !== 'Ident') {
                                pushDiag('S002', node)
                            }
                            value = def.default ? def.default.slice() : [0,0,0]
                        }
                        args[argKey] = value
                    } else if (def.type === 'vec3') {
                        let value
                        if (node && node.type === 'Call' && node.name === 'vec3' && node.args && node.args.length === 3) {
                            value = []
                            for (const arg of node.args) {
                                if (arg.type === 'Number') {
                                    value.push(arg.value)
                                } else {
                                    pushDiag('S002', arg)
                                    value.push(0)
                                }
                            }
                        } else if (node && node.type === 'Color') {
                            value = node.value.slice(0, 3)
                        } else {
                            if (node && node.type && node.type !== 'Ident') {
                                pushDiag('S002', node)
                            }
                            value = def.default ? def.default.slice() : [0,0,0]
                        }
                        args[argKey] = value
                    } else if (def.type === 'boolean') {
                        let value
                        if (node && node.type === 'Boolean') {
                            value = !!node.value
                        } else if (node && node.type === 'Number') {
                            value = node.value !== 0
                        } else if (node && node.type === 'Func') {
                            try {
                                const fn = new Function('state', `with(state){ return ${node.src}; }`)
                                value = {fn: (state) => !!fn(state)}
                            } catch {
                                pushDiag('S001', node)
                                value = def.default !== undefined ? !!def.default : false
                            }
                        } else if (node && node.type === 'Ident' && stateValues.has(node.name)) {
                            const key = node.name
                            value = {fn: (state) => !!state[key]}
                        } else {
                            if (node && node.type === 'Ident' && !stateValues.has(node.name)) {
                                pushDiag('S003', node)
                            } else if (node && node.type && node.type !== 'Ident') {
                                pushDiag('S002', node)
                            }
                            value = def.default !== undefined ? !!def.default : false
                        }
                        args[argKey] = value
                    } else if (def.type === 'member') {
                        const prefix = normalizeMemberPath(def.enumPath || def.enum)
                        let path = null
                        if (node && node.type === 'Member') {
                            path = normalizeMemberPath(node.path)
                        } else if (node && node.type === 'String') {
                            path = normalizeMemberPath(node.value)
                        } else if (node && (node.type === 'Number' || node.type === 'Boolean')) {
                            args[argKey] = node.type === 'Boolean' ? (node.value ? 1 : 0) : node.value
                            continue
                        } else if (node && node.type === 'Ident' && stateValues.has(node.name)) {
                            const key = node.name
                            args[argKey] = {fn: (state) => state[key]}
                            continue
                        } else if (node && node.type === 'Ident') {
                            path = [node.name]
                        }
                        if (!path) {
                            path = normalizeMemberPath(def.default)
                        }
                        let resolved = path ? resolveEnum(path) : undefined
                        if (resolved && resolved.type === 'Number') { resolved = resolved.value }
                        if (resolved && resolved.type === 'Boolean') { resolved = resolved.value ? 1 : 0 }
                        if (typeof resolved !== 'number') {
                            path = applyEnumPrefix(path || [], prefix)
                            if (prefix && path && !pathStartsWith(path, prefix)) {
                                pushDiag('S001', node || call)
                                path = prefix.slice()
                            }
                            resolved = path ? resolveEnum(path) : undefined
                            if (resolved && resolved.type === 'Number') { resolved = resolved.value }
                            if (resolved && resolved.type === 'Boolean') { resolved = resolved.value ? 1 : 0 }
                        }
                        if (typeof resolved !== 'number') {
                            const fallback = normalizeMemberPath(def.default)
                            let fallbackValue = fallback ? resolveEnum(fallback) : undefined
                            if (fallbackValue && fallbackValue.type === 'Number') {
                                fallbackValue = fallbackValue.value
                            }
                            if (fallbackValue && fallbackValue.type === 'Boolean') {
                                fallbackValue = fallbackValue.value ? 1 : 0
                            }
                            if (typeof fallbackValue === 'number') {
                                resolved = fallbackValue
                            } else {
                                resolved = 0
                            }
                        }
                        args[argKey] = resolved
                        if (node && node.type === 'Member' && path) {
                            node.path = path.slice()
                        }
                    } else {
                        let value
                        if (node && (node.type === 'Number' || node.type === 'Boolean')) {
                            value = node.type === 'Boolean' ? (node.value ? 1 : 0) : node.value
                            const clamped = clamp(value, def.min, def.max)
                            if (clamped !== value) {
                                pushDiag('S002', node)
                            }
                            value = clamped
                        } else if (node && node.type === 'Func') {
                            try {
                                const fn = new Function('state', `with(state){ return ${node.src}; }`)
                                value = {fn, min:def.min, max:def.max}
                            } catch {
                                pushDiag('S001', node)
                                value = def.default
                            }
                        } else if (node && node.type === 'Member') {
                            const cur = resolveEnum(node.path)
                            if (typeof cur === 'number') {
                                value = clamp(cur, def.min, def.max)
                                if (value !== cur) {
                                    pushDiag('S002', node)
                                }
                            } else if (typeof cur === 'boolean') {
                                const num = cur ? 1 : 0
                                value = clamp(num, def.min, def.max)
                                if (value !== num) {
                                    pushDiag('S002', node)
                                }
                            } else {
                                pushDiag('S001', node)
                                value = def.default
                            }
                        } else if (node && node.type === 'Ident' && stateValues.has(node.name)) {
                            const key = node.name
                            value = {fn: (state) => state[key], min:def.min, max:def.max}
                        } else if (node && node.type === 'Ident' && def.enum) {
                            // Try to resolve bare identifier as enum value within the param's enum path
                            const prefix = normalizeMemberPath(def.enum)
                            const path = prefix ? prefix.concat([node.name]) : [node.name]
                            const resolved = resolveEnum(path)
                            if (typeof resolved === 'number') {
                                value = clamp(resolved, def.min, def.max)
                            } else if (resolved && resolved.type === 'Number') {
                                value = clamp(resolved.value, def.min, def.max)
                            } else {
                                pushDiag('S003', node)
                                value = def.default
                            }
                        } else {
                            if (node && node.type === 'Ident' && !stateValues.has(node.name)) {
                                pushDiag('S003', node)
                            } else if (node && node.type && node.type !== 'Ident') {
                                pushDiag('S002', node)
                            }
                            if (def.defaultFrom) {
                                const ref = spec.args.find(d => d.name === def.defaultFrom)
                                const refKey = ref && (ref.uniform || ref.name) || def.defaultFrom
                                if (args[refKey] !== undefined) {
                                    value = args[refKey]
                                } else {
                                    value = def.default
                                }
                            } else {
                                value = def.default
                            }
                        }
                        args[argKey] = value
                    }
                }
                if (kw) {
                    for (const key of Object.keys(kw)) {
                        if (!seen.has(key)) {
                            pushDiag('S001', kw[key], `Unknown argument '${key}' for ${call.name}()`)
                        }
                    }
                }
                const hook = typeof call.name === 'string' ? validatorHooks[call.name] : null
                if (typeof hook === 'function') {
                    const starterInfo = getStarterInfo(original)
                    const hookResult = hook({
                        call,
                        originalCall: original,
                        args,
                        outName,
                        from: fromInput,
                        allocateTemp: () => tempIndex++,
                        addStep: (step) => {
                            if (step && typeof step === 'object') {
                                chain.push(step)
                            }
                        },
                        addState: (state) => {
                            if (state && typeof state === 'object') {
                                states.push(state)
                            }
                        },
                        pushDiagnostic: pushDiag,
                        states,
                        starter: starterInfo
                    })
                    if (hookResult && hookResult.handled) {
                        if (hookResult.current !== undefined && hookResult.current !== null) {
                            current = hookResult.current
                        }
                        continue
                    }
                }
                const idx = tempIndex++
                const namespaceSnapshot = buildNamespaceSnapshot(call.namespace, resolution)
                const step = {op: opName, args, from: fromInput, temp: idx}
                if (namespaceSnapshot) { step.namespace = namespaceSnapshot }
                chain.push(step)
                current = idx
            }
            return current
        }

        const finalIndex = processChain(stmt.chain, null)
        let outSurf = null
        if (stmt.out) {
            if (stmt.out.type === 'FeedbackRef') {
                outSurf = {kind:'feedback', name: stmt.out.name}
            } else {
                outSurf = {kind:'output', name: stmt.out.name}
            }
        }
        return {chain, out: outSurf, final: finalIndex, states}
    }

    function compileBlock(body) {
        const result = []
        for (const s of body || []) {
            const compiled = compileStmt(s)
            if (compiled) result.push(compiled)
        }
        return result
    }

    let loopDepth = 0

    function compileStmt(stmt) {
        if (stmt.type === 'IfStmt') {
            const cond = evalCondition(stmt.condition)
            const thenBranch = compileBlock(stmt.then)
            const elif = []
            for (const e of stmt.elif || []) {
                elif.push({cond: evalCondition(e.condition), then: compileBlock(e.then)})
            }
            const elseBranch = compileBlock(stmt.else)
            return {type:'Branch', cond, then: thenBranch, elif, else: elseBranch}
        }
        if (stmt.type === 'LoopStmt') {
            loopDepth++
            const body = compileBlock(stmt.body)
            loopDepth--
            const node = {type:'Loop', body}
            if (stmt.condition) node.cond = evalCondition(stmt.condition)
            return node
        }
        if (stmt.type === 'Break') {
            if (loopDepth === 0) {
                pushDiag('S001', stmt, "'break' outside loop")
            }
            return {type:'Break'}
        }
        if (stmt.type === 'Continue') {
            if (loopDepth === 0) {
                pushDiag('S001', stmt, "'continue' outside loop")
            }
            return {type:'Continue'}
        }
        if (stmt.type === 'Return') {
            const node = {type:'Return'}
            if (stmt.value) node.value = evalExpr(stmt.value)
            return node
        }
        return compileChainStatement(stmt)
    }

    for (const stmt of ast.plans || []) {
        const compiled = compileStmt(stmt)
        if (compiled) plans.push(compiled)
    }

    return {plans, diagnostics: diagnosticsList, render}
}
