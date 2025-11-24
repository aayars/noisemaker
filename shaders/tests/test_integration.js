/**
 * Integration Test - Full Pipeline Compilation
 * Tests the complete compilation flow from DSL to executable graph
 */

import { compileGraph } from '../src/runtime/compiler.js'
import { registerEffect } from '../src/runtime/registry.js'
import { registerOp } from '../src/lang/ops.js'
import { registerStarterOps } from '../src/lang/validator.js'

function test(name, fn) {
    try {
        console.log(`Running test: ${name}`)
        fn()
        console.log(`PASS: ${name}`)
    } catch (e) {
        console.error(`FAIL: ${name}`)
        console.error(e)
    }
}

// Register a simple test effect
const SolidEffect = {
    name: "Solid",
    namespace: "basics",
    func: "solid",
    globals: {
        r: { type: "float", default: 0, min: 0, max: 1 },
        g: { type: "float", default: 0, min: 0, max: 1 },
        b: { type: "float", default: 0, min: 0, max: 1 }
    },
    passes: [
        {
            name: "main",
            type: "render",
            program: "solid",
            inputs: {},
            outputs: { color: "outputColor" }
        }
    ]
}

const OscEffect = {
    name: "Osc",
    namespace: "basics",
    func: "osc",
    globals: {
        freq: { type: "float", default: 10, min: 0, max: 100 }
    },
    passes: [
        {
            name: "main",
            type: "render",
            program: "osc",
            inputs: {},
            outputs: { color: "outputColor" }
        }
    ]
}

const BlendEffect = {
    name: "Blend",
    namespace: "basics",
    func: "blend",
    globals: {
        amount: { type: "float", default: 0.5, min: 0, max: 1 }
    },
    passes: [
        {
            name: "main",
            type: "render",
            program: "blend",
            inputs: {
                tex0: "inputColor",
                tex1: "tex"
            },
            outputs: { color: "outputColor" }
        }
    ]
}

// Register ops for validator
registerOp('solid', {
    name: 'solid',
    args: [
        { name: 'r', type: 'float', default: 0 },
        { name: 'g', type: 'float', default: 0 },
        { name: 'b', type: 'float', default: 0 }
    ]
})
registerOp('osc', {
    name: 'osc',
    args: [{ name: 'freq', type: 'float', default: 10 }]
})
registerOp('blend', {
    name: 'blend',
    args: [{ name: 'tex', type: 'surface' }]
})
registerStarterOps(['solid', 'osc'])

// Register effects
registerEffect('solid', SolidEffect)
registerEffect('osc', OscEffect)
registerEffect('blend', BlendEffect)

test('Integration - Simple Generator', () => {
    const source = 'solid(1, 0, 0).out(o0)'
    const graph = compileGraph(source)
    
    if (!graph) {
        throw new Error('Graph compilation failed')
    }
    
    if (!graph.passes || graph.passes.length === 0) {
        throw new Error('No passes generated')
    }
    
    console.log(`  Generated ${graph.passes.length} passes`)
})

test('Integration - Chain with Parameters', () => {
    const source = 'osc(20).out(o0)'
    const graph = compileGraph(source)
    
    if (!graph || !graph.passes) {
        throw new Error('Graph compilation failed')
    }
    
    const pass = graph.passes[0]
    if (!pass) {
        throw new Error('No pass generated')
    }
    
    console.log(`  Pass program: ${pass.program}`)
})

test('Integration - Texture Allocation', () => {
    const source = 'solid(1, 0.5, 0).out(o0)'
    const graph = compileGraph(source)
    
    if (!graph.textures) {
        throw new Error('No textures in graph')
    }
    
    console.log(`  Allocated ${graph.textures.size} textures`)
})

test('Integration - Resource Allocation', () => {
    const source = 'solid(1, 0, 0).out(o0)'
    const graph = compileGraph(source)
    
    if (!graph.allocations) {
        throw new Error('No resource allocations')
    }
    
    console.log(`  Resource allocations: ${graph.allocations.size} virtual -> physical mappings`)
})

test('Integration - Multiple Outputs', () => {
    const sources = [
        'solid(1, 0, 0).out(o0)',
        'solid(0, 1, 0).out(o1)',
        'solid(0, 0, 1).out(o2)'
    ]
    
    for (const source of sources) {
        const graph = compileGraph(source)
        if (!graph || !graph.passes) {
            throw new Error(`Failed to compile: ${source}`)
        }
    }
    
    console.log(`  Compiled ${sources.length} different outputs`)
})

test('Integration - Graph Metadata', () => {
    const source = 'solid(1, 1, 1).out(o0)'
    const graph = compileGraph(source)
    
    if (!graph.id) {
        throw new Error('Graph missing ID')
    }
    
    if (!graph.compiledAt) {
        throw new Error('Graph missing compiledAt timestamp')
    }
    
    if (graph.source !== source) {
        throw new Error('Graph source mismatch')
    }
    
    console.log(`  Graph ID: ${graph.id}`)
})

test('Integration - Hash Consistency', () => {
    const source = 'solid(1, 0, 0).out(o0)'
    
    const graph1 = compileGraph(source)
    const graph2 = compileGraph(source)
    
    if (graph1.id !== graph2.id) {
        throw new Error('Graph IDs should be identical for same source')
    }
    
    const differentSource = 'solid(0, 1, 0).out(o0)'
    const graph3 = compileGraph(differentSource)
    
    if (graph1.id === graph3.id) {
        throw new Error('Graph IDs should differ for different source')
    }
})

console.log('\n=== Running Integration Tests ===\n')
