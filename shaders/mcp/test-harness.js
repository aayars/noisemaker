#!/usr/bin/env node
/**
 * Test script for the browser harness
 * 
 * ╔══════════════════════════════════════════════════════════════════════════════╗
 * ║  CRITICAL: DO NOT WEAKEN THESE TESTS                                         ║
 * ║                                                                              ║
 * ║  It is STRICTLY PROHIBITED to:                                               ║
 * ║    - Return 'ok' or count as 'passed' when ANY problem exists                ║
 * ║    - Change ❌ to ⚠ (warnings are for informational messages ONLY)           ║
 * ║    - Skip failure checks to make numbers look better                         ║
 * ║    - Add exceptions that mask real problems                                  ║
 * ║    - Disable or hobble tests                                                 ║
 * ║                                                                              ║
 * ║  A test PASSES if and ONLY if it is PRISTINE - zero issues of any kind.      ║
 * ║  Monochrome output, console errors, naming issues, unused files - ALL FAIL.  ║
 * ║                                                                              ║
 * ║  If a shader doesn't work, FIX THE SHADER, not the test.                     ║
 * ║  Always fix forward. Never mask problems.                                    ║
 * ╚══════════════════════════════════════════════════════════════════════════════╝
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
 *   --no-vision           # skip AI vision validation (vision is ON by default if .openai key exists)
 *   --uniforms            # test that uniform controls affect output
 *   --structure           # test for unused files, compute passes, naming conventions, and leaked internal uniforms
 *   --alg-equiv           # test algorithmic equivalence between GLSL and WGSL shaders (requires .openai key)
 *   --verbose             # show additional diagnostic info
 *   --webgpu, --wgsl      # use WebGPU/WGSL backend instead of WebGL2/GLSL
 * 
 * Vision Validation (ENABLED BY DEFAULT):
 *   Every rendered frame is analyzed by AI to detect:
 *   - Blank/empty output
 *   - Solid color (no pattern)
 *   - Broken/corrupted rendering
 *   - Invalid shader output
 *   Requires .openai file with API key. Use --no-vision to skip.
 * 
 * Structure test validates:
 *   - No inline shaders (all shaders must be in glsl/wgsl subdirectories)
 *   - camelCase naming conventions for:
 *     - Effect name in metadata (not StudlyCaps/PascalCase)
 *     - func property (not snake_case or kebab-case)
 *     - Uniform names (not snake_case)
 *     - Global keys (not snake_case)
 *     - Pass input/output keys (not snake_case)
 *     - Pass names (not snake_case)
 *     - Program/shader file names (not snake_case or kebab-case)
 *     - Texture names (allows global_ and _ prefixes for internal textures)
 *   - No unused shader files
 *   - No leaked internal uniforms (channels, time exposed as UI controls)
 *   - Split shader consistency (GLSL .vert/.frag pairs)
 *   - Multi-pass effects have compute passes (with exemptions)
 * 
 * Examples:
 *   node test-harness.js basics/noise              # compile + render + vision
 *   node test-harness.js "basics/*" --benchmark    # all basics with FPS
 *   node test-harness.js basics/noise --no-vision  # skip vision check
 *   node test-harness.js nm/worms --uniforms       # test uniform responsiveness
 *   node test-harness.js nm/worms --structure      # test shader organization
 *   node test-harness.js nm/normalize --benchmark --webgpu  # test WGSL with FPS
 *   node test-harness.js "nm/*" --alg-equiv        # test GLSL/WGSL algorithmic equivalence
 */

import { createBrowserHarness } from './browser-harness.js';
import { getOpenAIApiKey, checkEffectStructure, checkShaderParity } from './core-operations.js';

/**
 * Effects exempt from monochrome output check.
 * These effects are DESIGNED to output a single color by their nature.
 * 
 * STRICT: Adding new exemptions requires explicit permission.
 */
const MONOCHROME_EXEMPT_EFFECTS = new Set([
    'basics/alpha',       // Extracts alpha channel as grayscale - input noise has alpha=1.0
    'basics/solid',       // Outputs a solid fill color by design
]);

/**
 * Effects exempt from transparent output check.
 * These effects require external input that isn't available in automated testing.
 * 
 * STRICT: Adding new exemptions requires explicit permission.
 */
const TRANSPARENT_EXEMPT_EFFECTS = new Set([
    'nd/feedbackSynth',   // Feedback effect - outputs transparent when no prior frame exists
    'nd/mediaInput',      // Media input effect - outputs transparent when no media file loaded
]);

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
    const results = { 
        effectId, 
        compile: null, 
        render: null, 
        isMonochrome: false,
        uniforms: null, 
        uniformsFailed: false,
        structure: null, 
        algEquiv: null, 
        algEquivDivergent: false,
        benchmark: null, 
        benchmarkFailed: false,
        vision: null, 
        visionFailed: false,
        consoleErrors: [] 
    };
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
        
        // CRITICAL: Check for inline shaders - this is a HARD FAIL
        if (structureResult.hasInlineShaders) {
            console.log(`  ❌ INLINE SHADERS DETECTED - FORBIDDEN`);
            for (const loc of structureResult.inlineShaderLocations) {
                console.log(`     Line ${loc.line}: ${loc.type}`);
                console.log(`       ${loc.snippet}...`);
            }
            console.log(`  All shaders MUST be in separate files under glsl/ or wgsl/ directories.`);
            results.compile = 'error';
            return results;  // Hard fail - do not continue
        } else {
            console.log(`  ✓ no inline shaders`);
        }
        
        // Report naming convention issues (camelCase validation)
        if (structureResult.namingIssues?.length > 0) {
            console.log(`  ❌ naming issues (${structureResult.namingIssues.length}):`);
            for (const issue of structureResult.namingIssues) {
                if (issue.expected) {
                    console.log(`     ${issue.type}: "${issue.name}" → expected "${issue.expected}"`);
                } else {
                    console.log(`     ${issue.type}: "${issue.name}" - ${issue.reason}`);
                }
            }
        } else {
            console.log(`  ✓ naming conventions (camelCase)`);
        }
        
        // Report unused files
        if (structureResult.unusedFiles?.length > 0) {
            console.log(`  ❌ unused files: ${structureResult.unusedFiles.join(', ')}`);
        } else if (structureResult.unusedFiles) {
            console.log(`  ✓ no unused shader files`);
        }
        
        // Report leaked internal uniforms
        if (structureResult.leakedInternalUniforms?.length > 0) {
            console.log(`  ❌ leaked internal uniforms: ${structureResult.leakedInternalUniforms.join(', ')}`);
        } else {
            console.log(`  ✓ no leaked internal uniforms`);
        }
        
        // Report split shader issues (GLSL only)
        if (structureResult.splitShaderIssues?.length > 0) {
            console.log(`  ❌ split shader issues:`);
            for (const issue of structureResult.splitShaderIssues) {
                console.log(`     ${issue.message}`);
            }
        } else if (backend === 'webgl2') {
            console.log(`  ✓ split shaders consistent`);
        }
        
        // Report compute pass check for multi-pass effects
        if (structureResult.multiPass) {
            if (structureResult.hasComputePass) {
                console.log(`  ✓ multi-pass: has compute/gpgpu pass`);
            } else if (structureResult.computePassExempt) {
                console.log(`  ⊘ multi-pass: exempt (${structureResult.computePassExemptReason})`);
            } else {
                console.log(`  ❌ multi-pass: NO compute pass (${structureResult.passCount} passes, types: ${structureResult.passTypes?.join(', ')})`);
                results.structure.multiPassNoCompute = true;
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
            results.algEquivDivergent = true;
            console.log(`  ❌ ALG-EQUIV DIVERGENT`);
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
    const isMonochromeExempt = MONOCHROME_EXEMPT_EFFECTS.has(effectId);
    const isTransparentExempt = TRANSPARENT_EXEMPT_EFFECTS.has(effectId);
    // Transparent-exempt effects also get exempted from monochrome/blank checks since transparent = black = monochrome
    results.isMonochrome = (renderResult.metrics?.is_monochrome || false) && !isMonochromeExempt && !isTransparentExempt;
    results.isMonochromeExempt = isMonochromeExempt && (renderResult.metrics?.is_monochrome || false);
    results.isEssentiallyBlank = (renderResult.metrics?.is_essentially_blank || false) && !isTransparentExempt;
    results.isAllTransparent = (renderResult.metrics?.is_all_transparent || false) && !isTransparentExempt;
    results.isTransparentExempt = isTransparentExempt && (renderResult.metrics?.is_all_transparent || false);
    
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
    } else if (renderResult.metrics?.is_all_transparent && !isTransparentExempt) {
        console.log(`  ❌ render: FULLY TRANSPARENT (alpha=0 everywhere, mean_alpha=${renderResult.metrics.mean_alpha?.toFixed(4)})`);
        // Show console output for debugging
        const consoleOutput = harness.getConsoleMessages?.() || [];
        if (consoleOutput.length > 0) {
            console.log(`  Console output:`);
            for (const msg of consoleOutput.slice(0, 10)) {
                console.log(`    ${msg.type}: ${msg.text.slice(0, 500)}`);
            }
        }
    } else if (isTransparentExempt && renderResult.metrics?.is_all_transparent) {
        console.log(`  ⊘ render: transparent (exempt - expected for ${effectId})`);
    } else if (renderResult.metrics?.is_essentially_blank) {
        const m = renderResult.metrics;
        console.log(`  ❌ render: ESSENTIALLY BLANK (mean_rgb=[${m.mean_rgb.map(v => v.toFixed(4)).join(', ')}], ${m.unique_sampled_colors} colors)`);
        // Show console output for debugging
        const consoleOutput = harness.getConsoleMessages?.() || [];
        if (consoleOutput.length > 0) {
            console.log(`  Console output:`);
            for (const msg of consoleOutput.slice(0, 10)) {
                console.log(`    ${msg.type}: ${msg.text.slice(0, 500)}`);
            }
        }
    } else if (renderResult.metrics?.is_monochrome && !isMonochromeExempt) {
        console.log(`  ❌ render: monochrome output (${renderResult.metrics.unique_sampled_colors} colors)`);
        // Show console output for debugging monochrome issues
        const consoleOutput = harness.getConsoleMessages?.() || [];
        if (consoleOutput.length > 0) {
            console.log(`  Console output:`);
            for (const msg of consoleOutput.slice(0, 10)) {
                console.log(`    ${msg.type}: ${msg.text.slice(0, 500)}`);
            }
        }
    } else if (results.isMonochromeExempt) {
        console.log(`  ⊘ render: monochrome (exempt - expected for ${effectId})`);
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
        const uniformResult = await harness.testUniformResponsiveness(effectId, { backend, skipCompile: true });
        timings.push(`uniforms:${Date.now() - t0}ms`);
        results.uniforms = uniformResult.status;
        
        if (uniformResult.status === 'skipped') {
            console.log(`  ⊘ uniforms: ${uniformResult.details}`);
        } else if (uniformResult.status === 'ok') {
            console.log(`  ✓ uniforms: ${uniformResult.tested_uniforms.join(', ')}`);
        } else {
            results.uniformsFailed = true;
            console.log(`  ❌ uniforms: ${uniformResult.details} [${uniformResult.tested_uniforms.join(', ')}]`);
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
        if (benchResult.achieved_fps < 30) {
            results.benchmarkFailed = true;
            console.log(`  ❌ benchmark: ${benchResult.achieved_fps} fps (below 30 fps target)`);
        } else {
            console.log(`  ✓ benchmark: ${benchResult.achieved_fps} fps`);
        }
    }
    
    // Vision validation - ALWAYS run if API key available (unless --no-vision)
    // This catches blank/broken output that monochrome detection misses
    const hasApiKey = !!getOpenAIApiKey();
    if (hasApiKey && !options.skipVision) {
        const prompt = `Is this shader output valid?
Valid = shows actual visual content (patterns, colors, textures, effects)
Invalid = completely blank, solid color only, random noise with no structure, or obviously broken/corrupted

CRITICAL: If you see a CHECKERED PATTERN (alternating squares like a checkerboard), this indicates the shader output is TRANSPARENT and you're seeing the transparency background. This is INVALID output - tag it as "checkered" and "transparent".

Include "blank", "solid", "broken", "invalid", "checkered", or "transparent" in tags if the output has problems.`;
        
        const visionResult = await harness.describeEffectFrame(
            effectId,
            prompt,
            { skipCompile: true, backend, captureImage: true }
        );
        results.vision = visionResult.status;
        
        if (visionResult.error) {
            results.visionFailed = true;
            console.log(`  ❌ vision: ${visionResult.error}`);
        } else if (visionResult.vision) {
            const desc = (visionResult.vision.description || '').toLowerCase();
            const tags = (visionResult.vision.tags || []).map(t => t.toLowerCase());
            const notes = (visionResult.vision.notes || '').toLowerCase();
            const allText = `${desc} ${tags.join(' ')} ${notes}`;
            
            // Check for explicit failure indicators in tags or description
            // CRITICAL: "checkered" indicates transparent output showing the background
            // EXCEPTION: Effects in MONOCHROME_EXEMPT_EFFECTS are allowed to be "solid", "blank", or appear "invalid" (since solid color is by design)
            // EXCEPTION: Effects in TRANSPARENT_EXEMPT_EFFECTS are allowed to be "checkered", "transparent" (since no input = transparent is by design)
            const isMonoExempt = MONOCHROME_EXEMPT_EFFECTS.has(effectId);
            const isTransExempt = TRANSPARENT_EXEMPT_EFFECTS.has(effectId);
            let baseFailureIndicators = ['blank', 'solid color', 'broken', 'invalid', 'corrupted', 'empty', 'nothing', 'checkered', 'checkerboard', 'transparent'];
            if (isMonoExempt) {
                baseFailureIndicators = baseFailureIndicators.filter(i => i !== 'solid color' && i !== 'blank' && i !== 'empty' && i !== 'nothing' && i !== 'invalid');
            }
            if (isTransExempt) {
                baseFailureIndicators = baseFailureIndicators.filter(i => i !== 'checkered' && i !== 'checkerboard' && i !== 'transparent' && i !== 'blank' && i !== 'empty' && i !== 'nothing' && i !== 'invalid');
            }
            const failureIndicators = baseFailureIndicators;
            const hasFailureIndicator = failureIndicators.some(indicator => allText.includes(indicator));
            
            // Also check for tags that explicitly indicate problems
            // CRITICAL: "checkered" = transparency background visible = shader output is transparent/blank
            // EXCEPTION: Effects in MONOCHROME_EXEMPT_EFFECTS are allowed to be "solid" or "blank"
            // EXCEPTION: Effects in TRANSPARENT_EXEMPT_EFFECTS are allowed to be "checkered" or "transparent"
            const problemTags = tags.filter(t => {
                // Always fail on these regardless of exemption
                if (t === 'broken' || t === 'corrupted' || t === 'artifact') {
                    return true;
                }
                // Checkered/transparent failures - unless transparent-exempt
                if ((t === 'checkered' || t === 'checkerboard' || t === 'transparent') && !isTransExempt) {
                    return true;
                }
                // For monochrome or transparent exempt effects, allow solid/blank/empty/invalid tags
                if (isMonoExempt || isTransExempt) {
                    return false;
                }
                // For non-exempt effects, fail on solid/blank/empty/invalid
                return t === 'blank' || t === 'solid' || t === 'empty' || t === 'invalid';
            });
            
            if (hasFailureIndicator || problemTags.length > 0) {
                results.visionFailed = true;
                const reason = problemTags.length > 0 ? problemTags.join(', ') : desc.slice(0, 100);
                console.log(`  ❌ vision: INVALID OUTPUT - ${reason}`);
            } else {
                console.log(`  ✓ vision: ${visionResult.vision.tags?.slice(0, 3).join(', ') || desc.slice(0, 50)}`);
            }
        }
    }
    
    // Capture console errors/warnings - these MUST be checked for pass/fail
    const allConsoleMessages = harness.getConsoleMessages?.() || [];
    results.consoleErrors = allConsoleMessages.filter(m => 
        m.type === 'error' || m.type === 'warning' || m.type === 'pageerror'
    );
    
    // Log console errors if any
    if (results.consoleErrors.length > 0) {
        console.log(`  ❌ console errors: ${results.consoleErrors.length} error(s)/warning(s)`);
        if (options.verbose) {
            for (const msg of results.consoleErrors.slice(0, 5)) {
                console.log(`    ${msg.type}: ${msg.text.slice(0, 200)}`);
            }
        }
    }
    
    console.log(`  [${timings.join(', ')}]`);
    return results;
}

async function main() {
    console.log("⚠️ This is a long-running, expensive test suite. Don't run it multiple times unless you really need to. Capture the results in a log and review the log.");

    const pattern = process.argv[2] || 'basics/noise';
    const runBenchmark = process.argv.includes('--benchmark');  // off by default for speed
    const runUniforms = process.argv.includes('--uniforms');
    const runStructure = process.argv.includes('--structure');
    const runAlgEquiv = process.argv.includes('--alg-equiv');
    const skipVision = process.argv.includes('--no-vision');  // Vision is ON by default if API key exists
    const verbose = process.argv.includes('--verbose');
    
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
                uniforms: runUniforms,
                structure: runStructure,
                algEquiv: runAlgEquiv,
                skipVision,
                verbose,
                backend
            });
            results.push(result);
        }
        
        const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
        
        /**
         * STRICT PASS/FAIL DETERMINATION
         * 
         * ┌─────────────────────────────────────────────────────────────────────┐
         * │  DO NOT WEAKEN THIS FILTER. DO NOT ADD EXCEPTIONS.                  │
         * │  DO NOT REMOVE ANY CHECK. DO NOT CHANGE 'return false' TO ANYTHING. │
         * │                                                                      │
         * │  An effect PASSES if and ONLY if ALL of the following are true:     │
         * │    - Compilation succeeded                                           │
         * │    - Rendering succeeded                                             │
         * │    - Output is NOT monochrome (actually produces visible output)     │
         * │    - Zero console errors or warnings                                 │
         * │    - Uniforms are responsive (if tested)                             │
         * │    - Benchmark meets target FPS (if tested)                          │
         * │    - Vision analysis succeeded (if tested)                           │
         * │    - GLSL/WGSL are algorithmically equivalent (if tested)            │
         * │    - No naming convention violations (if structure tested)           │
         * │    - No unused shader files (if structure tested)                    │
         * │    - No leaked internal uniforms (if structure tested)               │
         * │    - No split shader issues (if structure tested)                    │
         * │    - Multi-pass effects have compute passes (if structure tested)    │
         * │                                                                      │
         * │  If ANY check fails, the effect FAILS. Period.                       │
         * └─────────────────────────────────────────────────────────────────────┘
         */
        const passed = results.filter(r => {
            if (r.compile !== 'ok') return false;
            if (r.render !== 'ok') return false;
            if (r.isMonochrome) return false;  // Monochrome output = FAIL
            if (r.isEssentiallyBlank) return false;  // Essentially blank output = FAIL
            if (r.isAllTransparent) return false;  // Fully transparent output = FAIL
            if (r.consoleErrors?.length > 0) return false;  // ANY console error = FAIL
            if (r.uniformsFailed) return false;  // Uniform responsiveness failed = FAIL
            if (r.benchmarkFailed) return false;  // Benchmark below target = FAIL  
            if (r.visionFailed) return false;  // Vision analysis failed = FAIL
            if (r.algEquivDivergent) return false;  // Algorithmic divergence = FAIL
            if (runStructure && r.structure?.namingIssues?.length > 0) return false;
            if (runStructure && r.structure?.unusedFiles?.length > 0) return false;  // Unused files = FAIL
            if (runStructure && r.structure?.leakedInternalUniforms?.length > 0) return false;  // Leaked internals = FAIL
            if (runStructure && r.structure?.splitShaderIssues?.length > 0) return false;  // Split shader issues = FAIL
            if (runStructure && r.structure?.multiPassNoCompute) return false;  // Multi-pass without compute = FAIL
            return true;
        }).length;
        
        // Collect effects with console errors for summary
        const withConsoleErrors = results.filter(r => r.consoleErrors?.length > 0);
        
        console.log(`\n=== Summary ===`);
        console.log(`${passed}/${results.length} passed in ${elapsed}s`);
        console.log(`${(elapsed / results.length).toFixed(2)}s per effect (excluding browser startup)`);
        
        // Structure summary if run
        if (runStructure) {
            const withNamingIssues = results.filter(r => r.structure?.namingIssues?.length > 0);
            const withUnused = results.filter(r => r.structure?.unusedFiles?.length > 0);
            const multiPassNoCompute = results.filter(r => 
                r.structure?.multiPass && !r.structure?.hasComputePass && !r.structure?.computePassExempt
            );
            
            // Naming issues summary (by type)
            if (withNamingIssues.length > 0) {
                console.log(`\n✗ Effects with naming convention issues: ${withNamingIssues.length}`);
                
                // Group issues by type across all effects
                const issuesByType = {};
                for (const r of withNamingIssues) {
                    for (const issue of r.structure.namingIssues) {
                        if (!issuesByType[issue.type]) {
                            issuesByType[issue.type] = [];
                        }
                        issuesByType[issue.type].push({ effectId: r.effectId, ...issue });
                    }
                }
                
                for (const [type, issues] of Object.entries(issuesByType)) {
                    console.log(`  ${type}: ${issues.length} issues`);
                    for (const issue of issues.slice(0, 5)) {  // Show first 5 of each type
                        console.log(`    ${issue.effectId}: "${issue.name}" - ${issue.reason}`);
                    }
                    if (issues.length > 5) {
                        console.log(`    ... and ${issues.length - 5} more`);
                    }
                }
            }
            
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
        
        // Console errors summary (ALWAYS show if any)
        if (withConsoleErrors.length > 0) {
            console.log(`\n❌ EFFECTS WITH CONSOLE ERRORS: ${withConsoleErrors.length}`);
            for (const r of withConsoleErrors) {
                console.log(`  ${r.effectId}: ${r.consoleErrors.length} error(s)`);
                for (const err of r.consoleErrors.slice(0, 3)) {
                    console.log(`    ${err.type}: ${err.text.slice(0, 150)}`);
                }
                if (r.consoleErrors.length > 3) {
                    console.log(`    ... and ${r.consoleErrors.length - 3} more errors`);
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
