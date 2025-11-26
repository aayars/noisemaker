#!/usr/bin/env node
/**
 * Test script for the browser harness
 * 
 * Usage:
 *   node test-harness.js <pattern> [flags]
 * 
 * Pattern formats:
 *   basics/noise          # exact effect ID
 *   "basics/*"            # glob pattern (quote for shell)
 *   "/^basics\\//"        # regex (starts with /)
 * 
 * Flags:
 *   --benchmark           # run FPS test (~500ms per effect)
 *   --vision              # run AI vision analysis (requires .openai key)
 *   --uniforms            # test that uniform controls affect output
 *   --structure           # test for unused files, compute passes, and leaked internal uniforms
 *   --alg-equiv           # test algorithmic equivalence between GLSL and WGSL shaders (requires .openai key)
 *   --verbose             # show additional diagnostic info
 *   --webgpu, --wgsl      # use WebGPU/WGSL backend instead of WebGL2/GLSL
 * 
 * Examples:
 *   node test-harness.js basics/noise              # compile + render only
 *   node test-harness.js "basics/*" --benchmark    # all basics with FPS
 *   node test-harness.js basics/noise --vision     # with AI description
 *   node test-harness.js nm/worms --uniforms       # test uniform responsiveness
 *   node test-harness.js nm/worms --structure      # test shader organization
 *   node test-harness.js nm/normalize --benchmark --webgpu  # test WGSL with FPS
 *   node test-harness.js "nm/*" --alg-equiv        # test GLSL/WGSL algorithmic equivalence
 */

import { createBrowserHarness } from './browser-harness.js';
import { getOpenAIApiKey, checkEffectStructure, checkShaderParity } from './core-operations.js';

/**
 * Match effect IDs against a pattern
 * @param {string[]} effects - All available effect IDs
 * @param {string} pattern - Glob or regex pattern
 * @returns {string[]} Matching effect IDs
 */
function matchEffects(effects, pattern) {
    // Regex pattern (starts with /)
    if (pattern.startsWith('/')) {
        const regexStr = pattern.slice(1, pattern.lastIndexOf('/'));
        const flags = pattern.slice(pattern.lastIndexOf('/') + 1);
        const regex = new RegExp(regexStr, flags);
        return effects.filter(e => regex.test(e));
    }
    
    // Glob pattern (contains * or ?)
    if (pattern.includes('*') || pattern.includes('?')) {
        const regexStr = pattern
            .replace(/[.+^${}()|[\]\\]/g, '\\$&')  // escape regex chars
            .replace(/\*/g, '.*')                    // * -> .*
            .replace(/\?/g, '.');                    // ? -> .
        const regex = new RegExp(`^${regexStr}$`);
        return effects.filter(e => regex.test(e));
    }
    
    // Exact match
    return effects.filter(e => e === pattern);
}

async function testEffect(harness, effectId, options = {}) {
    const results = { effectId, compile: null, render: null, uniforms: null, structure: null, algEquiv: null, benchmark: null, vision: null };
    const timings = [];
    const backend = options.backend || 'webgl2';
    let t0 = Date.now();
    
    // Clear console messages
    harness.clearConsoleMessages?.();
    
    // Structure test (runs before compilation, uses filesystem)
    if (options.structure) {
        t0 = Date.now();
        const structureResult = await checkEffectStructure(effectId, { backend });
        timings.push(`structure:${Date.now() - t0}ms`);
        results.structure = structureResult;
        
        // Report unused files
        if (structureResult.unusedFiles?.length > 0) {
            console.log(`  ⚠ unused files: ${structureResult.unusedFiles.join(', ')}`);
        } else if (structureResult.unusedFiles) {
            console.log(`  ✓ no unused shader files`);
        }
        
        // Report leaked internal uniforms
        if (structureResult.leakedInternalUniforms?.length > 0) {
            console.log(`  ⚠ leaked internal uniforms: ${structureResult.leakedInternalUniforms.join(', ')}`);
        } else {
            console.log(`  ✓ no leaked internal uniforms`);
        }
        
        // Report compute pass check for multi-pass effects
        if (structureResult.multiPass) {
            if (structureResult.hasComputePass) {
                console.log(`  ✓ multi-pass: has compute/gpgpu pass`);
            } else if (structureResult.computePassExempt) {
                console.log(`  ⊘ multi-pass: exempt (${structureResult.computePassExemptReason})`);
            } else {
                console.log(`  ⚠ multi-pass: NO compute pass (${structureResult.passCount} passes, types: ${structureResult.passTypes?.join(', ')})`);
            }
        }
        
        t0 = Date.now();
    }
    
    // Algorithmic equivalence test (runs before compilation, uses filesystem + AI)
    if (options.algEquiv && getOpenAIApiKey()) {
        t0 = Date.now();
        const algEquivResult = await checkShaderParity(effectId);
        timings.push(`alg-equiv:${Date.now() - t0}ms`);
        results.algEquiv = algEquivResult;
        
        if (algEquivResult.status === 'divergent') {
            console.log(`  ⚠ ALG-EQUIV DIVERGENT`);
            for (const pair of algEquivResult.pairs.filter(p => p.parity === 'divergent')) {
                console.log(`    ${pair.program}: ${pair.notes}`);
                if (pair.concerns?.length > 0) {
                    for (const concern of pair.concerns) {
                        console.log(`      - ${concern}`);
                    }
                }
            }
        } else if (algEquivResult.status === 'ok' && algEquivResult.pairs.length > 0) {
            console.log(`  ✓ alg-equiv: ${algEquivResult.pairs.length} pairs equivalent`);
        } else if (algEquivResult.pairs.length === 0) {
            console.log(`  ⊘ alg-equiv: ${algEquivResult.summary}`);
        } else {
            console.log(`  ✗ alg-equiv: ${algEquivResult.summary}`);
        }
        
        t0 = Date.now();
    }
    
    // Compile
    const compileResult = await harness.compileEffect(effectId, { backend });
    timings.push(`compile:${Date.now() - t0}ms`);
    t0 = Date.now();
    results.compile = compileResult.status;
    
    if (compileResult.status === 'error') {
        console.log(`  ❌ compile: ${compileResult.message}`);
        return results;
    }
    console.log(`  ✓ compile`);
    
    // Render (skip compile since already loaded)
    const renderResult = await harness.renderEffectFrame(effectId, { skipCompile: true, backend });
    timings.push(`render:${Date.now() - t0}ms`);
    t0 = Date.now();
    results.render = renderResult.status;
    
    if (renderResult.status === 'error') {
        console.log(`  ❌ render: ${renderResult.error}`);
        // Show console errors
        const consoleErrors = harness.getConsoleMessages?.() || [];
        if (consoleErrors.length > 0) {
            console.log(`  Console errors:`);
            for (const msg of consoleErrors.slice(0, 10)) {
                console.log(`    ${msg.type}: ${msg.text.slice(0, 500)}`);
            }
        }
    } else if (renderResult.metrics?.is_monochrome) {
        console.log(`  ⚠ render: monochrome output (${renderResult.metrics.unique_sampled_colors} colors)`);
        // Show console output for debugging monochrome issues
        const consoleOutput = harness.getConsoleMessages?.() || [];
        if (consoleOutput.length > 0) {
            console.log(`  Console output:`);
            for (const msg of consoleOutput.slice(0, 10)) {
                console.log(`    ${msg.type}: ${msg.text.slice(0, 500)}`);
            }
        }
    } else {
        console.log(`  ✓ render (${renderResult.metrics?.unique_sampled_colors} colors)`);
    }
    
    // Show DSL from compile result
    if (compileResult.console_errors) {
        const dslMsg = compileResult.console_errors.find(m => m.includes('DSL'));
        if (dslMsg) {
            console.log(`  ${dslMsg}`);
        }
    }
    
    // Uniform responsiveness test
    if (options.uniforms) {
        t0 = Date.now();
        const uniformResult = await harness.testUniformResponsiveness(effectId, { backend });
        timings.push(`uniforms:${Date.now() - t0}ms`);
        results.uniforms = uniformResult.status;
        
        if (uniformResult.status === 'skipped') {
            console.log(`  ⊘ uniforms: ${uniformResult.details}`);
        } else if (uniformResult.status === 'ok') {
            console.log(`  ✓ uniforms: ${uniformResult.tested_uniforms.join(', ')}`);
        } else {
            console.log(`  ✗ uniforms: ${uniformResult.details} [${uniformResult.tested_uniforms.join(', ')}]`);
        }
    }
    
    // Benchmark (skip compile)
    if (options.benchmark) {
        const benchResult = await harness.benchmarkEffectFps(effectId, {
            targetFps: 30,
            durationSeconds: 0.5,  // 500ms - enough to catch ~30 frames
            skipCompile: true,
            backend
        });
        results.benchmark = benchResult.achieved_fps;
        console.log(`  ✓ benchmark: ${benchResult.achieved_fps} fps`);
    }
    
    // Vision (skip compile)
    if (options.vision && getOpenAIApiKey()) {
        const prompt = options.visionPrompt || 'Is this a valid shader output? Describe briefly.';
        const visionResult = await harness.describeEffectFrame(
            effectId,
            prompt,
            { skipCompile: true, backend }
        );
        results.vision = visionResult.status;
        if (visionResult.vision) {
            console.log(`  ✓ vision: ${visionResult.vision.tags?.slice(0, 3).join(', ')}`);
            if (visionResult.vision.description) {
                console.log(`    ${visionResult.vision.description}`);
            }
            if (visionResult.vision.notes) {
                console.log(`    Notes: ${visionResult.vision.notes}`);
            }
        } else if (visionResult.error) {
            console.log(`  ⚠ vision: ${visionResult.error}`);
        }
    }
    
    console.log(`  [${timings.join(', ')}]`);
    return results;
}

async function main() {
    const pattern = process.argv[2] || 'basics/noise';
    const runBenchmark = process.argv.includes('--benchmark');  // off by default for speed
    const runVision = process.argv.includes('--vision');
    const runUniforms = process.argv.includes('--uniforms');
    const runStructure = process.argv.includes('--structure');
    const runAlgEquiv = process.argv.includes('--alg-equiv');
    const verbose = process.argv.includes('--verbose');
    
    // Extract vision prompt from --prompt "..." argument
    let visionPrompt = null;
    const promptIdx = process.argv.indexOf('--prompt');
    if (promptIdx !== -1 && process.argv[promptIdx + 1]) {
        visionPrompt = process.argv[promptIdx + 1];
    }
    
    const useWebGPU = process.argv.includes('--webgpu') || process.argv.includes('--wgsl');
    const backend = useWebGPU ? 'webgpu' : 'webgl2';
    
    console.log(`Starting browser harness (backend: ${backend})...`);
    const harness = await createBrowserHarness({ headless: false });
    
    try {
        const allEffects = await harness.listEffects();
        const matchedEffects = matchEffects(allEffects, pattern);
        
        if (matchedEffects.length === 0) {
            console.log(`No effects matched pattern: ${pattern}`);
            console.log(`Available: ${allEffects.slice(0, 10).join(', ')}...`);
            return;
        }
        
        console.log(`\nTesting ${matchedEffects.length} effect(s) matching "${pattern}":\n`);
        
        const results = [];
        const startTime = Date.now();
        
        for (const effectId of matchedEffects) {
            console.log(`[${effectId}]`);
            const result = await testEffect(harness, effectId, { 
                benchmark: runBenchmark, 
                vision: runVision,
                uniforms: runUniforms,
                structure: runStructure,
                algEquiv: runAlgEquiv,
                verbose,
                visionPrompt,
                backend
            });
            results.push(result);
        }
        
        const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
        const passed = results.filter(r => r.compile === 'ok' && r.render === 'ok').length;
        
        console.log(`\n=== Summary ===`);
        console.log(`${passed}/${results.length} passed in ${elapsed}s`);
        console.log(`${(elapsed / results.length).toFixed(2)}s per effect (excluding browser startup)`);
        
        // Structure summary if run
        if (runStructure) {
            const withUnused = results.filter(r => r.structure?.unusedFiles?.length > 0);
            const multiPassNoCompute = results.filter(r => 
                r.structure?.multiPass && !r.structure?.hasComputePass && !r.structure?.computePassExempt
            );
            
            if (withUnused.length > 0) {
                console.log(`\n⚠ Effects with unused shader files: ${withUnused.length}`);
                for (const r of withUnused) {
                    console.log(`  ${r.effectId}: ${r.structure.unusedFiles.join(', ')}`);
                }
            }
            
            if (multiPassNoCompute.length > 0) {
                console.log(`\n⚠ Multi-pass effects missing compute passes: ${multiPassNoCompute.length}`);
                for (const r of multiPassNoCompute) {
                    console.log(`  ${r.effectId}: ${r.structure.passCount} passes (${r.structure.passTypes?.join(', ')})`);
                }
            }
        }
        
        // Algorithmic equivalence summary if run
        if (runAlgEquiv) {
            const divergent = results.filter(r => r.algEquiv?.status === 'divergent');
            const checked = results.filter(r => r.algEquiv?.pairs?.length > 0);
            
            console.log(`\n=== Algorithmic Equivalence Summary ===`);
            console.log(`${checked.length} effects with shader pairs checked`);
            
            if (divergent.length > 0) {
                console.log(`\n⚠ DIVERGENT implementations: ${divergent.length}`);
                for (const r of divergent) {
                    console.log(`  ${r.effectId}:`);
                    for (const pair of r.algEquiv.pairs.filter(p => p.parity === 'divergent')) {
                        console.log(`    ${pair.program}: ${pair.notes}`);
                    }
                }
            } else if (checked.length > 0) {
                console.log(`✓ All shader pairs are algorithmically equivalent`);
            }
        }
        
    } catch (error) {
        console.error('Test failed:', error);
    } finally {
        await harness.close();
    }
}

main().catch(console.error);
