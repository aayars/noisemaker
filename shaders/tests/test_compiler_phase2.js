import { lex } from '../src/lang/lexer.js';
import { parse } from '../src/lang/parser.js';
import { validate, registerStarterOps } from '../src/lang/validator.js';
import { registerOp } from '../src/lang/ops.js';

// Setup
registerOp('osc', {
    name: 'osc',
    args: [
        { name: 'freq', type: 'float', default: 60 },
        { name: 'sync', type: 'float', default: 0.1 },
        { name: 'offset', type: 'float', default: 0 }
    ]
});
registerOp('rotate', {
    name: 'rotate',
    args: [
        { name: 'angle', type: 'float', default: 0 },
        { name: 'speed', type: 'float', default: 0 }
    ]
});
registerStarterOps(['osc']);

function compile(code) {
    const tokens = lex(code);
    const ast = parse(tokens);
    return validate(ast);
}

function test(name, code, check) {
    try {
        console.log(`Running test: ${name}`);
        const result = compile(code);
        check(result);
        console.log(`PASS: ${name}`);
    } catch (e) {
        console.error(`FAIL: ${name}`);
        console.error(e);
    }
}

test('Variable Alias (Function)', 'let x = osc; x(10).out(o0)', (result) => {
    const plan = result.plans[0];
    const step = plan.chain[0];
    if (step.op !== 'osc') throw new Error(`Expected osc, got ${step.op}`);
    if (step.args.freq !== 10) throw new Error(`Expected freq 10, got ${step.args.freq}`);
});

test('Variable Alias (Partial)', 'let x = osc(10); x().out(o0)', (result) => {
    const plan = result.plans[0];
    const step = plan.chain[0];
    if (step.op !== 'osc') throw new Error(`Expected osc, got ${step.op}`);
    if (step.args.freq !== 10) throw new Error(`Expected freq 10, got ${step.args.freq}`);
});

test('Variable Merge', 'let x = osc(10); x(20).out(o0)', (result) => {
    const plan = result.plans[0];
    const step = plan.chain[0];
    if (step.op !== 'osc') throw new Error(`Expected osc, got ${step.op}`);
    // Positional arg 20 is appended.
    // osc(freq, sync, offset)
    // x = osc(10) -> freq=10
    // x(20) -> freq=10, sync=20
    if (step.args.freq !== 10) throw new Error(`Expected freq 10, got ${step.args.freq}`);
    if (step.args.sync !== 20) throw new Error(`Expected sync 20, got ${step.args.sync}`);
});

test('Variable Merge (Named)', 'let x = osc(freq: 10); x(sync: 0.5).out(o0)', (result) => {
    const plan = result.plans[0];
    const step = plan.chain[0];
    if (step.args.freq !== 10) throw new Error(`Expected freq 10, got ${step.args.freq}`);
    if (step.args.sync !== 0.5) throw new Error(`Expected sync 0.5, got ${step.args.sync}`);
});

test('Chained Variables', `
let gen = osc(10)
let eff = rotate(1, 0.1)
gen().eff().out(o0)
`, (result) => {
    const plan = result.plans[0];
    if (plan.chain.length !== 2) throw new Error(`Expected 2 steps, got ${plan.chain.length}`);
    if (plan.chain[0].op !== 'osc') throw new Error('Expected osc first');
    if (plan.chain[1].op !== 'rotate') throw new Error('Expected rotate second');
});
