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
 * Backend (REQUIRED - one of the following):
 *   --webgl2, --glsl      # use WebGL2/GLSL backend
 *   --webgpu, --wgsl      # use WebGPU/WGSL backend
 * 
 * Flags:
 *   --all                 # run ALL tests (benchmark, uniforms, structure, alg-equiv, passthrough)
 *   --benchmark           # run FPS test (~500ms per effect)
 *   --no-vision           # skip AI vision validation (vision is ON by default if .openai key exists)
 *   --uniforms            # test that uniform controls affect output
 *   --structure           # test for unused files, compute passes, naming conventions, and leaked internal uniforms
 *   --alg-equiv           # test algorithmic equivalence between GLSL and WGSL shaders (requires .openai key)
 *   --passthrough         # test that filter effects do NOT pass through input unchanged
 *   --verbose             # show additional diagnostic info
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
 * 
 * Passthrough test validates:
 *   - Filter effects (those with inputTex) must NOT pass through input unchanged
 *   - Passthrough/no-op/placeholder shaders are STRICTLY FORBIDDEN
 *   - Compares input and output textures on the same frame
 *   - Fails if textures are >99% similar
 * 
 * Examples:
 *   node test-harness.js basics/noise --glsl         # compile + render + vision (GLSL)
 *   node test-harness.js basics/noise --wgsl         # compile + render + vision (WGSL)
 *   node test-harness.js "basics/*" --webgl2 --benchmark    # all basics with FPS (WebGL2)
 *   node test-harness.js "basics/*" --webgpu --all          # all basics with ALL tests (WebGPU)
 *   node test-harness.js basics/noise --glsl --no-vision    # skip vision check
 *   node test-harness.js nm/worms --wgsl --uniforms         # test uniform responsiveness
 *   node test-harness.js nm/worms --webgl2 --structure      # test shader organization
 *   node test-harness.js nm/normalize --webgpu --benchmark  # test WGSL with FPS
 *   node test-harness.js "nm/*" --glsl --alg-equiv          # test GLSL/WGSL algorithmic equivalence
 *   node test-harness.js "nm/*" --wgsl --passthrough        # test filter effects for passthrough
 */

import { createBrowserHarness } from './browser-harness.js';
import { getOpenAIApiKey, checkEffectStructure, checkShaderParity } from './core-operations.js';

/**
 * Effects exempt from monochrome output check.
 * These effects are DESIGNED to output a single color by their nature.
 * 
 * STRICT: No more exemptions are permitted
 */
const MONOCHROME_EXEMPT_EFFECTS = new Set([
    'basics/alpha',       // Extracts alpha channel as grayscale - input noise has alpha=1.0
    'basics/shape',       // Outputs a shape on solid background - "solid" tag is valid
    'basics/solid',       // Outputs a solid fill color by design
    // STRICT: No more exemptions are permitted
    // STRICT: No more exemptions are permitted
    // STRICT: No more exemptions are permitted
]);

/**
 * Effects exempt from "essentially blank" output check.
 * These effects are edge detection or similar that produce near-black output
 * on smooth noise input - this is correct behavior, not a bug.
 * 
 * STRICT: No more exemptions are permitted
 */
const BLANK_EXEMPT_EFFECTS = new Set([
    // STRICT: No more exemptions are permitted
    // STRICT: No more exemptions are permitted
    // STRICT: No more exemptions are permitted
]);

/**
 * Effects exempt from transparent output check.
 * These effects require external input that isn't available in automated testing,
 * or legitimately output transparency as part of their function.
 * 
 * STRICT: No more exemptions are permitted
 */
const TRANSPARENT_EXEMPT_EFFECTS = new Set([
    'nd/mediaInput',      // Media input effect - outputs transparent when no media file loaded
    // STRICT: No more exemptions are permitted
    // STRICT: No more exemptions are permitted
    // STRICT: No more exemptions are permitted
]);

/**
 * Effects exempt from passthrough check.
 * These effects preserve average color statistics while changing visual structure,
 * which causes high similarity scores even though they're NOT passthrough.
 * 
 * STRICT: No more exemptions are permitted
 */
const PASSTHROUGH_EXEMPT_EFFECTS = new Set([
    'basics/pixelate',    // Pixelate groups colors into blocks - preserves average but changes structure
    'nm/aberration',      // Chromatic aberration uses edge mask (pow(dist, 3)) - center unchanged, edges shifted
    // STRICT: No more exemptions are permitted
    // STRICT: No more exemptions are permitted
    // STRICT: No more exemptions are permitted
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
        passthrough: null,
        passthroughFailed: false,
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
        
        // Report required uniform issues
        if (structureResult.requiredUniformIssues?.length > 0) {
            console.log(`  ❌ required uniform issues (${structureResult.requiredUniformIssues.length}):`);
            for (const issue of structureResult.requiredUniformIssues) {
                console.log(`     ${issue.file}: ${issue.message}`);
            }
        } else {
            console.log(`  ✓ required uniforms declared`);
        }
        
        // Report structural parity issues (GLSL ↔ WGSL 1:1 mapping)
        if (structureResult.structuralParityIssues?.length > 0) {
            console.log(`  ❌ structural parity issues (${structureResult.structuralParityIssues.length}):`);
            for (const issue of structureResult.structuralParityIssues) {
                console.log(`     ${issue.message}`);
            }
        } else {
            console.log(`  ✓ GLSL ↔ WGSL structural parity`);
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
    const isBlankExempt = BLANK_EXEMPT_EFFECTS.has(effectId);
    // Transparent-exempt effects also get exempted from monochrome/blank checks since transparent = black = monochrome
    results.isMonochrome = (renderResult.metrics?.is_monochrome || false) && !isMonochromeExempt && !isTransparentExempt;
    results.isMonochromeExempt = isMonochromeExempt && (renderResult.metrics?.is_monochrome || false);
    results.isEssentiallyBlank = (renderResult.metrics?.is_essentially_blank || false) && !isTransparentExempt && !isBlankExempt;
    results.isBlankExempt = isBlankExempt && (renderResult.metrics?.is_essentially_blank || false);
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
    } else if (isBlankExempt && renderResult.metrics?.is_essentially_blank) {
        console.log(`  ⊘ render: essentially blank (exempt - edge detection on smooth noise)`);
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
    
    // Passthrough test - verifies filter effects don't just pass through input unchanged
    if (options.passthrough) {
        t0 = Date.now();
        const isPassthroughExempt = PASSTHROUGH_EXEMPT_EFFECTS.has(effectId);
        
        if (isPassthroughExempt) {
            results.passthrough = 'skipped';
            console.log(`  ⊘ passthrough: exempt (effect preserves average colors by design)`);
        } else {
            const passthroughResult = await harness.testNoPassthrough(effectId, { backend, skipCompile: true });
            timings.push(`passthrough:${Date.now() - t0}ms`);
            results.passthrough = passthroughResult.status;
            
            if (passthroughResult.status === 'skipped') {
                console.log(`  ⊘ passthrough: ${passthroughResult.details}`);
            } else if (passthroughResult.status === 'ok') {
                console.log(`  ✓ passthrough: ${passthroughResult.details}`);
            } else if (passthroughResult.status === 'passthrough') {
                results.passthroughFailed = true;
                console.log(`  ❌ PASSTHROUGH DETECTED: ${passthroughResult.details}`);
                if (options.verbose && passthroughResult.debug) {
                    console.log(`     debug: inputTex="${passthroughResult.debug?.inputTextureId}", resolved="${passthroughResult.debug?.resolvedInputId}", output="${passthroughResult.debug?.outputTextureId}"`);
                    console.log(`     available textures: ${passthroughResult.debug?.availableTextures?.join(', ')}`);
                }
            } else {
                results.passthroughFailed = true;
                console.log(`  ❌ passthrough: ${passthroughResult.details}`);
                if (options.verbose && passthroughResult.debug) {
                    console.log(`     debug: ${JSON.stringify(passthroughResult.debug)}`);
                }
            }
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
    
    // Reset uniforms to defaults BEFORE vision test to ensure clean state
    // This is critical because uniform/passthrough tests may have modified state
    await harness.resetUniformsToDefaults();
    
    // Vision validation - ALWAYS run if API key available (unless --no-vision)
    // This catches blank/broken output that monochrome detection misses
    const hasApiKey = !!getOpenAIApiKey();
    if (hasApiKey && !options.skipVision) {
        const prompt = `Is this shader output valid?
Valid = shows actual visual content (patterns, colors, textures, effects, colorful mosaic, grid of colors)
Invalid = completely blank, solid color only, or obviously broken/corrupted

CRITICAL TRANSPARENCY CHECK: If you see a GRAY AND WHITE checkerboard pattern (like Photoshop's transparency background), this means the output is TRANSPARENT. Tag as "transparency-background". This is different from colorful grids/mosaics which are valid.

Only include these tags if problems exist: "blank", "solid", "broken", "invalid", "transparency-background".
Do NOT tag colorful patterns or mosaics as problematic - those are valid outputs.`;
        
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
            // CRITICAL: "transparency-background" indicates transparent output showing the gray/white checkerboard
            // EXCEPTION: Effects in MONOCHROME_EXEMPT_EFFECTS are allowed to be "solid", "blank", or appear "invalid" (since solid color is by design)
            // EXCEPTION: Effects in TRANSPARENT_EXEMPT_EFFECTS are allowed to be "transparency-background" (since no input = transparent is by design)
            const isMonoExempt = MONOCHROME_EXEMPT_EFFECTS.has(effectId);
            const isTransExempt = TRANSPARENT_EXEMPT_EFFECTS.has(effectId);
            let baseFailureIndicators = ['blank', 'solid color', 'broken', 'invalid', 'corrupted', 'empty', 'nothing', 'transparency-background'];
            if (isMonoExempt) {
                baseFailureIndicators = baseFailureIndicators.filter(i => i !== 'solid color' && i !== 'blank' && i !== 'empty' && i !== 'nothing' && i !== 'invalid');
            }
            if (isTransExempt) {
                baseFailureIndicators = baseFailureIndicators.filter(i => i !== 'transparency-background' && i !== 'blank' && i !== 'empty' && i !== 'nothing' && i !== 'invalid');
            }
            const failureIndicators = baseFailureIndicators;
            const hasFailureIndicator = failureIndicators.some(indicator => allText.includes(indicator));
            
            // Also check for tags that explicitly indicate problems
            // CRITICAL: "transparency-background" = gray/white checkerboard visible = shader output is transparent/blank
            // EXCEPTION: Effects in MONOCHROME_EXEMPT_EFFECTS are allowed to be "solid" or "blank"
            // EXCEPTION: Effects in TRANSPARENT_EXEMPT_EFFECTS are allowed to be "transparency-background"
            const problemTags = tags.filter(t => {
                // Always fail on these regardless of exemption
                if (t === 'broken' || t === 'corrupted' || t === 'artifact') {
                    return true;
                }
                // Transparency-background failures - unless transparent-exempt
                if (t === 'transparency-background' && !isTransExempt) {
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
    
    // ALWAYS reset all uniforms to defaults at the end of each test
    // This ensures the next test (including vision) starts from a clean state
    await harness.resetUniformsToDefaults();
    
    console.log(`  [${timings.join(', ')}]`);
    return results;
}

async function main() {
    const nag = "⚠️ This is a long-running, expensive test suite. Don't run it multiple times unless you really need to. Capture the results in a log and review the log.";
    console.log(nag);

    // Collect all non-flag arguments as patterns
    const patterns = process.argv.slice(2).filter(arg => !arg.startsWith('--'));
    if (patterns.length === 0) {
        patterns.push('basics/noise');  // default
    }
    
    const runAll = process.argv.includes('--all');
    const runBenchmark = runAll || process.argv.includes('--benchmark');  // off by default for speed
    const runUniforms = runAll || process.argv.includes('--uniforms');
    const runStructure = runAll || process.argv.includes('--structure');
    const runAlgEquiv = runAll || process.argv.includes('--alg-equiv');
    const runPassthrough = runAll || process.argv.includes('--passthrough');
    const skipVision = process.argv.includes('--no-vision');  // Vision is ON by default if API key exists
    const verbose = process.argv.includes('--verbose');
    
    // Backend is MANDATORY - must specify one
    const useWebGL2 = process.argv.includes('--webgl2') || process.argv.includes('--glsl');
    const useWebGPU = process.argv.includes('--webgpu') || process.argv.includes('--wgsl');
    
    if (!useWebGL2 && !useWebGPU) {
        console.error('ERROR: Backend flag is REQUIRED.');
        console.error('  Use --webgl2 or --glsl for WebGL2/GLSL');
        console.error('  Use --webgpu or --wgsl for WebGPU/WGSL');
        console.error('\nExample: node test-harness.js basics/noise --glsl');
        process.exit(1);
    }
    
    if (useWebGL2 && useWebGPU) {
        console.error('ERROR: Cannot specify both WebGL2 and WebGPU backends.');
        console.error('  Choose one: --webgl2/--glsl OR --webgpu/--wgsl');
        process.exit(1);
    }
    
    const backend = useWebGPU ? 'webgpu' : 'webgl2';
    
    console.log(`Starting browser harness (backend: ${backend})...`);
    const harness = await createBrowserHarness({ headless: false });
    
    try {
        const allEffects = await harness.listEffects();
        
        // Match effects from all patterns
        const matchedEffectsSet = new Set();
        for (const pattern of patterns) {
            const matches = matchEffects(allEffects, pattern);
            if (matches.length === 0) {
                console.log(`No effects matched pattern: ${pattern}`);
                console.log(`Available: ${allEffects.slice(0, 10).join(', ')}...`);
            }
            for (const m of matches) {
                matchedEffectsSet.add(m);
            }
        }
        
        const matchedEffects = Array.from(matchedEffectsSet).sort();
        
        if (matchedEffects.length === 0) {
            return;
        }
        
        console.log(`\nTesting ${matchedEffects.length} effect(s) matching "${patterns.join(', ')}":\n`);
        
        const results = [];
        const startTime = Date.now();
        
        for (const effectId of matchedEffects) {
            console.log(`\n────────────────────────────────────────────────────────────────────────────────`);
            console.log(`[${effectId}] (${backend})`);
            const result = await testEffect(harness, effectId, { 
                benchmark: runBenchmark, 
                uniforms: runUniforms,
                structure: runStructure,
                algEquiv: runAlgEquiv,
                passthrough: runPassthrough,
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
         * │    - Filter effects do NOT passthrough input unchanged (if tested)   │
         * │    - No naming convention violations (if structure tested)           │
         * │    - No unused shader files (if structure tested)                    │
         * │    - No leaked internal uniforms (if structure tested)               │
         * │    - No split shader issues (if structure tested)                    │
         * │    - GLSL ↔ WGSL structural parity (if structure tested)             │
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
            if (r.passthroughFailed) return false;  // Passthrough detected = FAIL
            if (r.benchmarkFailed) return false;  // Benchmark below target = FAIL  
            if (r.visionFailed) return false;  // Vision analysis failed = FAIL
            if (r.algEquivDivergent) return false;  // Algorithmic divergence = FAIL
            if (runStructure && r.structure?.namingIssues?.length > 0) return false;
            if (runStructure && r.structure?.unusedFiles?.length > 0) return false;  // Unused files = FAIL
            if (runStructure && r.structure?.leakedInternalUniforms?.length > 0) return false;  // Leaked internals = FAIL
            if (runStructure && r.structure?.splitShaderIssues?.length > 0) return false;  // Split shader issues = FAIL
            if (runStructure && r.structure?.structuralParityIssues?.length > 0) return false;  // GLSL/WGSL parity = FAIL
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
            
            // Structural parity summary
            const withParityIssues = results.filter(r => r.structure?.structuralParityIssues?.length > 0);
            if (withParityIssues.length > 0) {
                console.log(`\n❌ EFFECTS WITH STRUCTURAL PARITY ISSUES: ${withParityIssues.length}`);
                for (const r of withParityIssues) {
                    console.log(`  ${r.effectId}:`);
                    for (const issue of r.structure.structuralParityIssues) {
                        console.log(`    ${issue.message}`);
                    }
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
        
        // Passthrough summary if run
        if (runPassthrough) {
            const passthroughEffects = results.filter(r => r.passthroughFailed);
            const testedFilters = results.filter(r => r.passthrough === 'ok' || r.passthrough === 'passthrough');
            
            console.log(`\n=== Passthrough Test Summary ===`);
            console.log(`${testedFilters.length} filter effects tested`);
            
            if (passthroughEffects.length > 0) {
                console.log(`\n❌ PASSTHROUGH EFFECTS DETECTED: ${passthroughEffects.length}`);
                for (const r of passthroughEffects) {
                    console.log(`  ${r.effectId}: output identical to input - FORBIDDEN`);
                }
            } else if (testedFilters.length > 0) {
                console.log(`✓ All filter effects modify their input`);
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
        process.exit(1);
    } finally {
        await harness.close();
    }

    console.log(nag);
    process.exit(0);
}

main().catch((error) => {
    console.error(error);
    process.exit(1);
});
