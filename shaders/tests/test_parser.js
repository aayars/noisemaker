import { lex } from '../src/lang/lexer.js';
import { parse } from '../src/lang/parser.js';

function test(name, code, check) {
    try {
        console.log(`Running test: ${name}`);
        const tokens = lex(code);
        const ast = parse(tokens);
        check(ast);
        console.log(`PASS: ${name}`);
    } catch (e) {
        console.error(`FAIL: ${name}`);
        console.error(e);
        try {
            const tokens = lex(code);
            const ast = parse(tokens);
            console.log("AST:", JSON.stringify(ast, null, 2));
        } catch {
            console.log("Could not print AST due to parse error");
        }
    }
}

test('Simple Chain', 'osc(10).out(o0)', (ast) => {
    if (ast.plans.length !== 1) throw new Error('Expected 1 plan');
    const plan = ast.plans[0];
    if (plan.chain.length !== 1) throw new Error('Expected 1 call in chain');
    if (plan.chain[0].name !== 'osc') throw new Error('Expected osc');
    if (plan.out.name !== 'o0') throw new Error('Expected output o0');
});

test('Loop', 'loop 5 { osc(10).out(o0) }', (ast) => {
    if (ast.plans.length !== 1) throw new Error('Expected 1 plan (LoopStmt)');
    const loop = ast.plans[0];
    if (loop.type !== 'LoopStmt') throw new Error('Expected LoopStmt');
    if (loop.condition.value !== 5) throw new Error('Expected condition 5');
    if (loop.body.length !== 1) throw new Error('Expected 1 statement in body');
});

test('Variable Assignment', 'let x = osc(10)', (ast) => {
    if (ast.vars.length !== 1) throw new Error('Expected 1 var');
    const v = ast.vars[0];
    if (v.name !== 'x') throw new Error('Expected var x');
    // Single call chain is unwrapped to Call node
    if (v.expr.type !== 'Call') throw new Error('Expected Call type');
    if (v.expr.name !== 'osc') throw new Error('Expected osc');
});

test('Arrow Function', 'let f = () => osc(10)', (ast) => {
    const v = ast.vars[0];
    if (v.expr.type !== 'Func') throw new Error('Expected Func type');
    if (v.expr.src !== 'osc(10)') throw new Error('Expected src osc(10)');
});

test('Arrow Function in Loop', `
loop 5 {
  let f = () => osc(10)
  f().out(o0)
}
`, (ast) => {
    const loop = ast.plans[0];
    // The loop body should have 2 statements: VarAssign and ChainStmt
    // But wait, VarAssigns are hoisted to 'vars' in the root AST?
    // No, VarAssign inside a block stays in the block?
    // Let's check the parser logic for Block.
    if (loop.body.length !== 2) throw new Error(`Expected 2 statements in loop body, got ${loop.body.length}`);
    const assign = loop.body[0];
    if (assign.type !== 'VarAssign') throw new Error('Expected VarAssign first');
    const call = loop.body[1];
    if (call.chain[0].name !== 'f') throw new Error('Expected call to f second');
});
