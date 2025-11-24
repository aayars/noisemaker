import { lex } from '../src/lang/lexer.js';
import { parse } from '../src/lang/parser.js';
import { validate, registerStarterOps } from '../src/lang/validator.js';
import { registerOp } from '../src/lang/ops.js';

// Register some dummy ops for testing
registerOp('osc', {
    name: 'osc',
    args: [
        { name: 'freq', type: 'float', default: 60 },
        { name: 'sync', type: 'float', default: 0.1 },
        { name: 'offset', type: 'float', default: 0 }
    ]
});

registerOp('kaleid', {
    name: 'kaleid',
    args: [
        { name: 'nSides', type: 'float', default: 4 }
    ]
});

registerOp('bloom', {
    name: 'bloom',
    args: [
        { name: 'intensity', type: 'float', default: 0.5 }
    ]
});

registerStarterOps(['osc']);

function test(name, code, check) {
    try {
        console.log(`Running test: ${name}`);
        const tokens = lex(code);
        const ast = parse(tokens);
        const result = validate(ast);
        check(result);
        console.log(`PASS: ${name}`);
    } catch (e) {
        console.error(`FAIL: ${name}`);
        console.error(e);
    }
}

test('Valid Chain', 'osc(10).out(o0)', (result) => {
    if (result.diagnostics.length > 0) {
        throw new Error(`Expected no diagnostics, got ${JSON.stringify(result.diagnostics)}`);
    }
    if (result.plans.length !== 1) throw new Error('Expected 1 plan');
});

test('Unknown Function', 'unknown(10).out(o0)', (result) => {
    const diag = result.diagnostics.find(d => d.code === 'S001');
    if (!diag) throw new Error('Expected S001 (Unknown identifier)');
});

test('Missing Out', 'osc(10)', (result) => {
    const diag = result.diagnostics.find(d => d.code === 'S006');
    if (!diag) throw new Error('Expected S006 (Starter chain missing out)');
});

test('Argument Type Mismatch', 'osc("string").out(o0)', (result) => {
    const diag = result.diagnostics.find(d => d.code === 'S002'); // Or ERR_ARG_TYPE
    if (!diag) throw new Error('Expected S002 (Argument out of range/type mismatch)');
});

test('Illegal Chain Structure', 'bloom(0.5).out(o0)', (result) => {
    const diag = result.diagnostics.find(d => d.code === 'S005');
    if (!diag) throw new Error('Expected S005 (Illegal chain structure)');
});
