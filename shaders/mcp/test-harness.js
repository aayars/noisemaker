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
 * 
 * Examples:
 *   node test-harness.js basics/noise              # compile + render only
 *   node test-harness.js "basics/*" --benchmark    # all basics with FPS
 *   node test-harness.js basics/noise --vision     # with AI description
 */

import { createBrowserHarness } from './browser-harness.js';
import { getOpenAIApiKey } from './core-operations.js';

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
    const results = { effectId, compile: null, render: null, benchmark: null, vision: null };
    const timings = [];
    let t0 = Date.now();
    
    // Compile
    const compileResult = await harness.compileEffect(effectId);
    timings.push(`compile:${Date.now() - t0}ms`);
    t0 = Date.now();
    results.compile = compileResult.status;
    
    if (compileResult.status === 'error') {
        console.log(`  ❌ compile: ${compileResult.message}`);
        return results;
    }
    console.log(`  ✓ compile`);
    
    // Render (skip compile since already loaded)
    const renderResult = await harness.renderEffectFrame(effectId, { skipCompile: true });
    timings.push(`render:${Date.now() - t0}ms`);
    t0 = Date.now();
    results.render = renderResult.status;
    
    if (renderResult.status === 'error') {
        console.log(`  ❌ render: ${renderResult.error}`);
    } else if (renderResult.metrics?.is_monochrome) {
        console.log(`  ⚠ render: monochrome output (${renderResult.metrics.unique_sampled_colors} colors)`);
    } else {
        console.log(`  ✓ render (${renderResult.metrics?.unique_sampled_colors} colors)`);
    }
    
    // Benchmark (skip compile)
    if (options.benchmark) {
        const benchResult = await harness.benchmarkEffectFps(effectId, {
            targetFps: 30,
            durationSeconds: 0.5,  // 500ms - enough to catch ~30 frames
            skipCompile: true
        });
        results.benchmark = benchResult.achieved_fps;
        console.log(`  ✓ benchmark: ${benchResult.achieved_fps} fps`);
    }
    
    // Vision (skip compile)
    if (options.vision && getOpenAIApiKey()) {
        const visionResult = await harness.describeEffectFrame(
            effectId,
            'Is this a valid shader output? Describe briefly.',
            { skipCompile: true }
        );
        results.vision = visionResult.status;
        if (visionResult.vision) {
            console.log(`  ✓ vision: ${visionResult.vision.tags?.slice(0, 3).join(', ')}`);
        }
    }
    
    console.log(`  [${timings.join(', ')}]`);
    return results;
}

async function main() {
    const pattern = process.argv[2] || 'basics/noise';
    const runBenchmark = process.argv.includes('--benchmark');  // off by default for speed
    const runVision = process.argv.includes('--vision');
    
    console.log('Starting browser harness...');
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
                vision: runVision 
            });
            results.push(result);
        }
        
        const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
        const passed = results.filter(r => r.compile === 'ok' && r.render === 'ok').length;
        
        console.log(`\n=== Summary ===`);
        console.log(`${passed}/${results.length} passed in ${elapsed}s`);
        console.log(`${(elapsed / results.length).toFixed(2)}s per effect (excluding browser startup)`);
        
    } catch (error) {
        console.error('Test failed:', error);
    } finally {
        await harness.close();
    }
}

main().catch(console.error);
