/**
 * Core Operations Library for Shader Effect Testing
 * 
 * This module provides the fundamental operations for testing shader effects:
 * - compileEffect: Compile a shader and report structured diagnostics
 * - renderEffectFrame: Render a single frame and compute numerical image metrics
 * - benchmarkEffectFps: Run a timed render loop and produce frame-time statistics
 * - describeEffectFrame: Render and hand the image to a vision model
 * 
 * These operations are used by both the MCP server (for coding agents) and
 * the test suite (for CI). The MCP layer returns raw results; tests apply thresholds.
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const PROJECT_ROOT = path.resolve(__dirname, '../..');

/**
 * Get OpenAI API key from .openai file or environment variable
 * @returns {string|null} API key or null if not found
 */
export function getOpenAIApiKey() {
    // Read from .openai file in project root
    const keyFile = path.join(PROJECT_ROOT, '.openai');
    try {
        const key = fs.readFileSync(keyFile, 'utf-8').trim();
        if (key) return key;
    } catch {
        // File doesn't exist or can't be read
    }
    return null;
}

/**
 * Status timeout for compilation operations (ms)
 */
export const STATUS_TIMEOUT = 1_000;

/**
 * Wait for shader compilation status in the demo page
 * @param {import('@playwright/test').Page} page - Playwright page
 * @returns {Promise<{state: 'ok'|'error', message: string}>}
 */
export async function waitForCompileStatus(page) {
    const handle = await page.waitForFunction(() => {
        const status = document.getElementById('status');
        if (!status) return null;
        const text = (status.textContent || '').toLowerCase();
        if (!text.trim()) return null;
        if (text.includes('compilation failed')) {
            return { state: 'error', message: status.textContent || '' };
        }
        if (text.includes('compiled')) {
            return { state: 'ok', message: status.textContent || '' };
        }
        return null;
    }, { timeout: STATUS_TIMEOUT, polling: 10 });

    return handle.jsonValue();
}

/**
 * Compile a shader effect and return structured diagnostics
 * 
 * @param {import('@playwright/test').Page} page - Playwright page with demo loaded
 * @param {string} effectId - Effect identifier (e.g., "basics/noise")
 * @param {object} options
 * @param {'webgl2'|'webgpu'} [options.backend='webgl2'] - Rendering backend
 * @returns {Promise<{status: 'ok'|'error', backend: string, passes: Array<{id: string, status: 'ok'|'error', errors?: Array}>}>}
 */
export async function compileEffect(page, effectId, options = {}) {
    const backend = options.backend || 'webgl2';
    const targetBackend = backend === 'webgpu' ? 'wgsl' : 'glsl';
    
    // Do everything in a single browser round-trip
    const result = await page.evaluate(async ({ effectId, targetBackend, timeout }) => {
        // Set backend if needed
        const currentBackend = typeof window.__noisemakerCurrentBackend === 'function'
            ? window.__noisemakerCurrentBackend()
            : 'glsl';
        
        if (currentBackend !== targetBackend) {
            const radio = document.querySelector(`input[name="backend"][value="${targetBackend}"]`);
            if (radio) radio.click();
        }
        
        // Select the effect
        const select = document.getElementById('effect-select');
        if (select) {
            select.value = effectId;
            select.dispatchEvent(new Event('change', { bubbles: true }));
        }
        
        // Poll for compilation status (inline, no round-trips)
        const startTime = Date.now();
        while (Date.now() - startTime < timeout) {
            const status = document.getElementById('status');
            if (status) {
                const text = (status.textContent || '').toLowerCase();
                if (text.includes('compilation failed')) {
                    return { state: 'error', message: status.textContent || '' };
                }
                if (text.includes('compiled')) {
                    // Get pass info while we're here
                    const pipeline = window.__noisemakerRenderingPipeline;
                    const passes = (pipeline?.graph?.passes || []).map(pass => ({
                        id: pass.id || pass.program,
                        status: 'ok'
                    }));
                    return { state: 'ok', message: status.textContent || '', passes };
                }
            }
            await new Promise(r => setTimeout(r, 5));  // 5ms poll interval
        }
        return { state: 'error', message: 'Compilation timeout' };
    }, { effectId, targetBackend, timeout: STATUS_TIMEOUT });
    
    return {
        status: result.state,
        backend: backend,
        passes: result.passes?.length > 0 ? result.passes : [{ id: effectId, status: result.state }],
        message: result.message
    };
}

/**
 * Compute image metrics from pixel data
 * 
 * @param {Uint8Array|Float32Array} data - RGBA pixel data
 * @param {number} width - Image width
 * @param {number} height - Image height
 * @returns {{mean_rgb: [number,number,number], std_rgb: [number,number,number], luma_variance: number, unique_sampled_colors: number, is_all_zero: boolean, is_monochrome: boolean}}
 */
export function computeImageMetrics(data, width, height) {
    const pixelCount = width * height;
    const stride = Math.max(1, Math.floor(pixelCount / 1000)); // Sample ~1000 pixels
    
    let sumR = 0, sumG = 0, sumB = 0;
    let sumR2 = 0, sumG2 = 0, sumB2 = 0;
    let sumLuma = 0, sumLuma2 = 0;
    const sampledColors = new Set();
    let sampleCount = 0;
    let isAllZero = true;
    
    // Determine if data is normalized (0-1) or byte (0-255)
    const isFloat = data instanceof Float32Array;
    const scale = isFloat ? 255 : 1;
    
    for (let i = 0; i < data.length; i += stride * 4) {
        const r = data[i] * scale;
        const g = data[i + 1] * scale;
        const b = data[i + 2] * scale;
        
        if (r !== 0 || g !== 0 || b !== 0) {
            isAllZero = false;
        }
        
        sumR += r;
        sumG += g;
        sumB += b;
        sumR2 += r * r;
        sumG2 += g * g;
        sumB2 += b * b;
        
        const luma = 0.299 * r + 0.587 * g + 0.114 * b;
        sumLuma += luma;
        sumLuma2 += luma * luma;
        
        // Quantize color to 6-bit per channel for counting unique colors
        const colorKey = (Math.floor(r / 4) << 12) | (Math.floor(g / 4) << 6) | Math.floor(b / 4);
        sampledColors.add(colorKey);
        sampleCount++;
    }
    
    const meanR = sumR / sampleCount;
    const meanG = sumG / sampleCount;
    const meanB = sumB / sampleCount;
    const meanLuma = sumLuma / sampleCount;
    
    const stdR = Math.sqrt(sumR2 / sampleCount - meanR * meanR);
    const stdG = Math.sqrt(sumG2 / sampleCount - meanG * meanG);
    const stdB = Math.sqrt(sumB2 / sampleCount - meanB * meanB);
    const lumaVariance = sumLuma2 / sampleCount - meanLuma * meanLuma;
    
    const isMonochrome = sampledColors.size <= 1;
    
    return {
        mean_rgb: [meanR / 255, meanG / 255, meanB / 255],
        std_rgb: [stdR / 255, stdG / 255, stdB / 255],
        luma_variance: lumaVariance / (255 * 255),
        unique_sampled_colors: sampledColors.size,
        is_all_zero: isAllZero,
        is_monochrome: isMonochrome
    };
}

/**
 * Render an effect frame and compute metrics
 * 
 * @param {import('@playwright/test').Page} page - Playwright page with demo loaded
 * @param {string} effectId - Effect identifier
 * @param {object} options
 * @param {number} [options.time] - Time to render at (ignored - uses page's natural render loop)
 * @param {[number,number]} [options.resolution] - Resolution [width, height]
 * @param {number} [options.seed] - Random seed
 * @param {Record<string,any>} [options.uniforms] - Uniform overrides
 * @param {number} [options.warmupFrames=10] - Frames to wait before capture (default 10 for stability)
 * @returns {Promise<{status: 'ok'|'error', frame: {image_uri: string, width: number, height: number}, metrics: object}>}
 */
export async function renderEffectFrame(page, effectId, options = {}) {
    const warmupFrames = options.warmupFrames ?? 10;
    const skipCompile = options.skipCompile ?? false;
    
    // Compile the effect (unless already done)
    if (!skipCompile) {
        const compileResult = await compileEffect(page, effectId, { backend: options.backend });
        if (compileResult.status === 'error') {
            return {
                status: 'error',
                frame: null,
                metrics: null,
                error: compileResult.message
            };
        }
    }
    
    // Wait for the page's natural render loop to run warmup frames
    // Use a longer timeout since we're waiting for actual frame renders
    const FRAME_WAIT_TIMEOUT = 5000;  // 5 seconds should be plenty for 10 frames
    try {
        await page.waitForFunction(({ warmupFrames }) => {
            const pipeline = window.__noisemakerRenderingPipeline;
            if (!pipeline) return false;
            const frameCount = window.__noisemakerFrameCount || 0;
            // Store baseline if not set
            if (window.__noisemakerTestBaselineFrame === undefined) {
                window.__noisemakerTestBaselineFrame = frameCount;
            }
            return frameCount >= window.__noisemakerTestBaselineFrame + warmupFrames;
        }, { warmupFrames }, { timeout: FRAME_WAIT_TIMEOUT });
    } catch (err) {
        // Check frame count for debugging
        const debugInfo = await page.evaluate(() => ({
            frameCount: window.__noisemakerFrameCount,
            baseline: window.__noisemakerTestBaselineFrame,
            hasPipeline: !!window.__noisemakerRenderingPipeline
        }));
        return {
            status: 'error',
            frame: null,
            metrics: null,
            error: `Frame wait timeout: ${JSON.stringify(debugInfo)}`
        };
    }
    
    // Clear baseline for next test
    await page.evaluate(() => {
        delete window.__noisemakerTestBaselineFrame;
    });
    
    // Single round-trip: apply uniforms, read pixels, compute metrics in browser
    const result = await page.evaluate(async ({ uniforms }) => {
        const pipeline = window.__noisemakerRenderingPipeline;
        if (!pipeline) {
            return { error: 'Pipeline not available' };
        }
        
        // Apply uniform overrides (will take effect on next frame, but we've already rendered warmup)
        if (uniforms && pipeline.globalUniforms) {
            Object.assign(pipeline.globalUniforms, uniforms);
        }
        
        const backend = pipeline.backend;
        const backendName = backend?.getName?.() || 'WebGL2';
        const surface = pipeline.surfaces?.get('o0');
        
        if (!surface) {
            return { error: 'Surface o0 not found' };
        }
        
        let data, width, height;
        
        if (backendName === 'WebGPU') {
            try {
                const result = await backend.readPixels(surface.read);
                if (!result || !result.data) {
                    return { error: 'Failed to read pixels from WebGPU' };
                }
                data = result.data;
                width = result.width;
                height = result.height;
            } catch (err) {
                return { error: `WebGPU readPixels failed: ${err.message}` };
            }
        } else {
            // WebGL2 path
            const gl = backend?.gl;
            if (!gl) {
                return { error: 'GL context not available' };
            }
            
            const textureInfo = backend.textures?.get(surface.read);
            if (!textureInfo) {
                return { error: `Texture info missing for ${surface.read}` };
            }
            
            width = textureInfo.width;
            height = textureInfo.height;
            
            const fbo = gl.createFramebuffer();
            gl.bindFramebuffer(gl.FRAMEBUFFER, fbo);
            gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, textureInfo.handle, 0);
            
            // Check for float buffer extension (required for rgba16f textures)
            const hasFloatExt = !!gl.getExtension('EXT_color_buffer_float');
            let isFloat = false;
            
            if (hasFloatExt) {
                // Try reading as float first (for rgba16f textures)
                data = new Float32Array(width * height * 4);
                gl.readPixels(0, 0, width, height, gl.RGBA, gl.FLOAT, data);
                if (gl.getError() === gl.NO_ERROR) {
                    isFloat = true;
                } else {
                    // Fall back to UNSIGNED_BYTE
                    data = new Uint8Array(width * height * 4);
                    gl.readPixels(0, 0, width, height, gl.RGBA, gl.UNSIGNED_BYTE, data);
                }
            } else {
                data = new Uint8Array(width * height * 4);
                gl.readPixels(0, 0, width, height, gl.RGBA, gl.UNSIGNED_BYTE, data);
            }
            
            gl.bindFramebuffer(gl.FRAMEBUFFER, null);
            gl.deleteFramebuffer(fbo);
            
            // Convert float data to 0-255 range for consistent metrics
            if (isFloat) {
                const converted = new Uint8Array(data.length);
                for (let i = 0; i < data.length; i++) {
                    converted[i] = Math.max(0, Math.min(255, Math.round(data[i] * 255)));
                }
                data = converted;
            }
        }
        
        // Compute metrics in browser to avoid transferring megabytes of pixel data
        const pixelCount = width * height;
        const stride = Math.max(1, Math.floor(pixelCount / 1000));
        
        let sumR = 0, sumG = 0, sumB = 0;
        let sumR2 = 0, sumG2 = 0, sumB2 = 0;
        let sumLuma = 0, sumLuma2 = 0;
        const sampledColors = new Set();
        let sampleCount = 0;
        let isAllZero = true;
        
        for (let i = 0; i < data.length; i += stride * 4) {
            const r = data[i];
            const g = data[i + 1];
            const b = data[i + 2];
            
            if (r !== 0 || g !== 0 || b !== 0) isAllZero = false;
            
            sumR += r; sumG += g; sumB += b;
            sumR2 += r * r; sumG2 += g * g; sumB2 += b * b;
            
            const luma = 0.299 * r + 0.587 * g + 0.114 * b;
            sumLuma += luma;
            sumLuma2 += luma * luma;
            
            const colorKey = (Math.floor(r / 4) << 12) | (Math.floor(g / 4) << 6) | Math.floor(b / 4);
            sampledColors.add(colorKey);
            sampleCount++;
        }
        
        const meanR = sumR / sampleCount;
        const meanG = sumG / sampleCount;
        const meanB = sumB / sampleCount;
        const meanLuma = sumLuma / sampleCount;
        
        const metrics = {
            mean_rgb: [meanR / 255, meanG / 255, meanB / 255],
            std_rgb: [
                Math.sqrt(sumR2 / sampleCount - meanR * meanR) / 255,
                Math.sqrt(sumG2 / sampleCount - meanG * meanG) / 255,
                Math.sqrt(sumB2 / sampleCount - meanB * meanB) / 255
            ],
            luma_variance: (sumLuma2 / sampleCount - meanLuma * meanLuma) / (255 * 255),
            unique_sampled_colors: sampledColors.size,
            is_all_zero: isAllZero,
            is_monochrome: sampledColors.size <= 1
        };
        
        return { width, height, metrics };
    }, { uniforms: options.uniforms });
    
    if (result.error) {
        return {
            status: 'error',
            frame: null,
            metrics: null,
            error: result.error
        };
    }
    
    // Capture image if requested (for vision API)
    let imageUri = null;
    if (options.captureImage) {
        try {
            const canvas = await page.$('canvas');
            if (canvas) {
                const screenshot = await canvas.screenshot({ type: 'png' });
                imageUri = `data:image/png;base64,${screenshot.toString('base64')}`;
            }
        } catch (err) {
            // Image capture failed, but metrics are still valid
        }
    }
    
    return {
        status: 'ok',
        frame: {
            image_uri: imageUri,
            width: result.width,
            height: result.height
        },
        metrics: result.metrics
    };
}

/**
 * Benchmark effect FPS over a duration
 * 
 * @param {import('@playwright/test').Page} page - Playwright page with demo loaded
 * @param {string} effectId - Effect identifier
 * @param {object} options
 * @param {number} [options.targetFps=60] - Target FPS to compare against
 * @param {number} [options.durationSeconds=5] - Benchmark duration in seconds
 * @param {[number,number]} [options.resolution] - Resolution [width, height]
 * @param {'webgl2'|'webgpu'} [options.backend='webgl2'] - Rendering backend
 * @param {boolean} [options.skipCompile=false] - Skip compilation if effect already loaded
 * @returns {Promise<{status: 'ok'|'error', backend: string, achieved_fps: number, meets_target: boolean, stats: object}>}
 */
export async function benchmarkEffectFps(page, effectId, options = {}) {
    const targetFps = options.targetFps ?? 60;
    const durationSeconds = options.durationSeconds ?? 5;
    const backend = options.backend || 'webgl2';
    const skipCompile = options.skipCompile ?? false;
    
    // Compile the effect (unless already done)
    if (!skipCompile) {
        const compileResult = await compileEffect(page, effectId, { backend });
        if (compileResult.status === 'error') {
            return {
                status: 'error',
                backend,
                achieved_fps: 0,
                meets_target: false,
                stats: null,
                error: compileResult.message
            };
        }
    }
    
    // Run the benchmark - sample the frame counter from the render loop
    const stats = await page.evaluate(async (durationMs) => {
        const startFrame = window.__noisemakerFrameCount || 0;
        const startTime = performance.now();
        
        // Wait for the duration
        await new Promise(r => setTimeout(r, durationMs));
        
        const endFrame = window.__noisemakerFrameCount || 0;
        const endTime = performance.now();
        
        const frameCount = endFrame - startFrame;
        const totalTime = endTime - startTime;
        
        return {
            frame_count: frameCount,
            total_time_ms: totalTime,
            avg_frame_time_ms: frameCount > 0 ? totalTime / frameCount : 0
        };
    }, durationSeconds * 1000);
    
    if (stats.error) {
        return {
            status: 'error',
            backend,
            achieved_fps: 0,
            meets_target: false,
            stats: null,
            error: stats.error
        };
    }
    
    const achievedFps = stats.frame_count / (stats.total_time_ms / 1000);
    
    return {
        status: 'ok',
        backend,
        achieved_fps: Math.round(achievedFps * 100) / 100,
        meets_target: achievedFps >= targetFps,
        stats: {
            frame_count: stats.frame_count,
            avg_frame_time_ms: Math.round(stats.avg_frame_time_ms * 100) / 100
        }
    };
}

/**
 * Describe an effect frame using AI vision
 * 
 * @param {import('@playwright/test').Page} page - Playwright page with demo loaded
 * @param {string} effectId - Effect identifier
 * @param {string} prompt - Vision prompt
 * @param {object} options
 * @param {number} [options.time] - Time to render at
 * @param {[number,number]} [options.resolution] - Resolution [width, height]
 * @param {number} [options.seed] - Random seed
 * @param {Record<string,any>} [options.uniforms] - Uniform overrides
 * @param {string} [options.apiKey] - OpenAI API key (falls back to .openai file in project root)
 * @param {string} [options.model='gpt-4o'] - Vision model to use
 * @returns {Promise<{status: 'ok'|'error', frame: {image_uri: string}, vision: {description: string, tags: string[], notes?: string}}>}
 */
export async function describeEffectFrame(page, effectId, prompt, options = {}) {
    // First render the frame with image capture enabled
    const renderResult = await renderEffectFrame(page, effectId, { ...options, captureImage: true });
    if (renderResult.status === 'error') {
        return {
            status: 'error',
            frame: null,
            vision: null,
            error: renderResult.error
        };
    }
    
    const imageUri = renderResult.frame.image_uri;
    if (!imageUri) {
        return {
            status: 'error',
            frame: null,
            vision: null,
            error: 'Failed to capture frame image'
        };
    }
    
    // Call OpenAI Vision API
    const apiKey = options.apiKey || getOpenAIApiKey();
    if (!apiKey) {
        return {
            status: 'error',
            frame: { image_uri: imageUri },
            vision: null,
            error: 'No OpenAI API key found. Create .openai file in project root.'
        };
    }
    
    const model = options.model || 'gpt-4o';
    
    const systemPrompt = `You are an expert at analyzing procedural graphics and shader effects.
Analyze the provided image and respond with a JSON object containing:
- description: A detailed description of what you see (2-3 sentences)
- tags: An array of relevant tags (e.g., "noise", "colorful", "abstract", "pattern", "gradient", etc.)
- notes: Any additional observations about the quality, artifacts, or issues (optional)

User prompt: ${prompt}`;
    
    try {
        const response = await fetch('https://api.openai.com/v1/chat/completions', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${apiKey}`
            },
            body: JSON.stringify({
                model,
                messages: [
                    {
                        role: 'user',
                        content: [
                            { type: 'text', text: systemPrompt },
                            {
                                type: 'image_url',
                                image_url: { url: imageUri }
                            }
                        ]
                    }
                ],
                max_tokens: 500,
                response_format: { type: 'json_object' }
            })
        });
        
        if (!response.ok) {
            const errorText = await response.text();
            return {
                status: 'error',
                frame: { image_uri: imageUri },
                vision: null,
                error: `OpenAI API error: ${response.status} - ${errorText}`
            };
        }
        
        const data = await response.json();
        const content = data.choices?.[0]?.message?.content;
        
        if (!content) {
            return {
                status: 'error',
                frame: { image_uri: imageUri },
                vision: null,
                error: 'No response from vision model'
            };
        }
        
        const visionResult = JSON.parse(content);
        
        return {
            status: 'ok',
            frame: { image_uri: imageUri },
            vision: {
                description: visionResult.description || '',
                tags: visionResult.tags || [],
                notes: visionResult.notes
            }
        };
    } catch (err) {
        return {
            status: 'error',
            frame: { image_uri: imageUri },
            vision: null,
            error: `Vision API call failed: ${err.message}`
        };
    }
}

/**
 * Effects that are exempt from compute pass requirements for multi-pass pipelines.
 * These are typically simple filter chains or effects where GPGPU provides no benefit.
 */
const COMPUTE_PASS_EXEMPT_EFFECTS = new Set([
    // Simple filter chains
    'basics/blend', 'basics/layer', 'basics/mask', 'basics/modulate',
    // Effects with legitimate multi-pass render pipelines (blur, bloom, etc.)
    'nm/blur',  // Multi-pass gaussian blur is fine as render passes
    'nm/bloom', // Blur + composite is fine
    // Add more as needed with justification
]);

/**
 * Internal uniforms that should NOT be exposed as UI controls.
 * These are system-managed uniforms set by the runtime.
 * Note: 'speed' is allowed as a user-exposed uniform.
 */
const INTERNAL_UNIFORMS = new Set(['channels', 'time']);

/**
 * Check effect structure for unused files and compute pass requirements
 * 
 * @param {string} effectId - Effect identifier (e.g., "nm/worms")
 * @param {object} options
 * @param {'webgl2'|'webgpu'} [options.backend='webgpu'] - Backend to check (affects which shader dir to scan)
 * @returns {Promise<{unusedFiles: string[], multiPass: boolean, hasComputePass: boolean, passCount: number, passTypes: string[], computePassExempt: boolean, computePassExemptReason?: string, leakedInternalUniforms: string[]}>}
 */
export async function checkEffectStructure(effectId, options = {}) {
    const backend = options.backend || 'webgpu';
    const shaderDir = backend === 'webgpu' ? 'wgsl' : 'glsl';
    const shaderExt = backend === 'webgpu' ? '.wgsl' : '.glsl';
    
    // Parse effect ID to get directory path
    const [namespace, effectName] = effectId.split('/');
    const effectDir = path.join(PROJECT_ROOT, 'shaders', 'effects', namespace, effectName);
    
    const result = {
        unusedFiles: [],
        multiPass: false,
        hasComputePass: false,
        passCount: 0,
        passTypes: [],
        computePassExempt: false,
        computePassExemptReason: null,
        leakedInternalUniforms: [],
        hasInlineShaders: false,
        inlineShaderLocations: []
    };
    
    try {
        // Read definition.js to get passes
        const definitionPath = path.join(effectDir, 'definition.js');
        const definitionSource = fs.readFileSync(definitionPath, 'utf-8');
        
        // CRITICAL: Check for inline shader code in the definition
        // Inline shaders are FORBIDDEN - all shaders must be in separate files
        const inlineShaderPatterns = [
            // Direct shader source strings (multiline template literals or strings with shader keywords)
            { pattern: /\bglsl\s*:\s*`[\s\S]*?`/g, type: 'glsl template literal' },
            { pattern: /\bwgsl\s*:\s*`[\s\S]*?`/g, type: 'wgsl template literal' },
            { pattern: /\bsource\s*:\s*`[\s\S]*?`/g, type: 'source template literal' },
            { pattern: /\bfragment\s*:\s*`[\s\S]*?`/g, type: 'fragment template literal' },
            { pattern: /\bvertex\s*:\s*`[\s\S]*?`/g, type: 'vertex template literal' },
            // Shader code indicators within strings (GLSL)
            { pattern: /["'`][^"'`]*#version\s+\d+[^"'`]*["'`]/g, type: 'GLSL #version directive' },
            { pattern: /["'`][^"'`]*\bprecision\s+(highp|mediump|lowp)\b[^"'`]*["'`]/g, type: 'GLSL precision qualifier' },
            { pattern: /["'`][^"'`]*\bgl_FragColor\b[^"'`]*["'`]/g, type: 'GLSL gl_FragColor' },
            { pattern: /["'`][^"'`]*\buniform\s+\w+\s+\w+\s*;[^"'`]*["'`]/g, type: 'GLSL uniform declaration' },
            // Shader code indicators within strings (WGSL)
            { pattern: /["'`][^"'`]*@fragment[^"'`]*["'`]/g, type: 'WGSL @fragment' },
            { pattern: /["'`][^"'`]*@vertex[^"'`]*["'`]/g, type: 'WGSL @vertex' },
            { pattern: /["'`][^"'`]*@compute[^"'`]*["'`]/g, type: 'WGSL @compute' },
            { pattern: /["'`][^"'`]*@binding\s*\(\s*\d+\s*\)[^"'`]*["'`]/g, type: 'WGSL @binding' },
        ];
        
        for (const { pattern, type } of inlineShaderPatterns) {
            const matches = [...definitionSource.matchAll(pattern)];
            for (const match of matches) {
                // Find line number
                const beforeMatch = definitionSource.substring(0, match.index);
                const lineNumber = (beforeMatch.match(/\n/g) || []).length + 1;
                result.hasInlineShaders = true;
                result.inlineShaderLocations.push({ type, line: lineNumber, snippet: match[0].substring(0, 80) });
            }
        }
        
        // Extract passes section from definition
        // Look for passes = [ ... ] or passes: [ ... ]
        const passesMatch = definitionSource.match(/passes\s*[=:]\s*\[([\s\S]*?)\];/);
        const passesSection = passesMatch ? passesMatch[1] : '';
        
        // Extract pass programs and types from passes section only
        const referencedPrograms = new Set();
        const passTypes = [];
        
        // Parse passes array - look for program: "name" patterns within passes section
        const programMatches = passesSection.matchAll(/program:\s*["']([^"']+)["']/g);
        for (const match of programMatches) {
            referencedPrograms.add(match[1]);
        }
        
        // Parse pass types - look for type: "compute" or type: "render" patterns within passes section
        // Only match render|compute|gpgpu - valid pass types
        const typeMatches = passesSection.matchAll(/type:\s*["'](render|compute|gpgpu)["']/g);
        for (const match of typeMatches) {
            passTypes.push(match[1]);
        }
        
        result.passCount = referencedPrograms.size;
        result.passTypes = passTypes;
        result.multiPass = referencedPrograms.size > 1;
        result.hasComputePass = passTypes.includes('compute') || passTypes.includes('gpgpu');
        
        // Check if exempt from compute pass requirement
        if (COMPUTE_PASS_EXEMPT_EFFECTS.has(effectId)) {
            result.computePassExempt = true;
            result.computePassExemptReason = 'explicitly exempt';
        } else if (!result.multiPass) {
            result.computePassExempt = true;
            result.computePassExemptReason = 'single-pass effect';
        }
        
        // Check for leaked internal uniforms exposed as UI controls
        // Extract globals section from definition
        const globalsMatch = definitionSource.match(/globals\s*[=:]\s*\{([\s\S]*?)\n\s{2}\};/);
        const globalsSection = globalsMatch ? globalsMatch[1] : '';
        
        // Look for global entries that expose internal uniforms as controls
        // An internal uniform is leaked if:
        // 1. It has a uniform property matching an internal name, AND
        // 2. It doesn't have ui.control set to false
        for (const internalName of INTERNAL_UNIFORMS) {
            // Check if there's a global with uniform: "internalName" or uniform: 'internalName'
            // and it doesn't have control: false in its ui section
            const uniformPattern = new RegExp(
                `(\\w+):\\s*\\{[^}]*uniform:\\s*["']${internalName}["'][^}]*\\}`,
                'g'
            );
            const matches = [...globalsSection.matchAll(uniformPattern)];
            
            for (const match of matches) {
                const globalBlock = match[0];
                // Check if ui.control is explicitly set to false
                const hasControlFalse = /ui:\s*\{[^}]*control:\s*false[^}]*\}/.test(globalBlock);
                if (!hasControlFalse) {
                    result.leakedInternalUniforms.push(internalName);
                }
            }
        }
        
        // List shader files in the appropriate directory
        const shaderDirPath = path.join(effectDir, shaderDir);
        let shaderFiles = [];
        
        try {
            shaderFiles = fs.readdirSync(shaderDirPath)
                .filter(f => f.endsWith(shaderExt))
                .map(f => f.replace(shaderExt, ''));
        } catch (err) {
            // Shader directory doesn't exist - that's a bigger problem, but not what we're testing here
            return result;
        }
        
        // Find unused files
        for (const file of shaderFiles) {
            if (!referencedPrograms.has(file)) {
                result.unusedFiles.push(file + shaderExt);
            }
        }
        
    } catch (err) {
        // Can't read definition - skip structure check
        result.error = err.message;
    }
    
    return result;
}

/**
 * Check algorithmic parity between GLSL and WGSL shader implementations.
 * 
 * Uses OpenAI API to compare shader pairs and determine if they implement
 * equivalent algorithms, accounting for language differences between GLSL and WGSL.
 * 
 * @param {string} effectId - Effect identifier (e.g., "basics/noise")
 * @param {object} options
 * @param {string} [options.apiKey] - OpenAI API key (falls back to .openai file)
 * @param {string} [options.model='gpt-4o'] - Model to use for comparison
 * @returns {Promise<{status: 'ok'|'error'|'divergent', pairs: Array<{program: string, glsl: string, wgsl: string, parity: 'equivalent'|'divergent'|'missing', notes?: string}>, summary: string}>}
 */
export async function checkShaderParity(effectId, options = {}) {
    const apiKey = options.apiKey || getOpenAIApiKey();
    if (!apiKey) {
        return {
            status: 'error',
            pairs: [],
            summary: 'No OpenAI API key found. Create .openai file in project root.'
        };
    }
    
    const model = options.model || 'gpt-4o';
    
    // Parse effect ID to get directory path
    const [namespace, effectName] = effectId.split('/');
    const effectDir = path.join(PROJECT_ROOT, 'shaders', 'effects', namespace, effectName);
    
    const glslDir = path.join(effectDir, 'glsl');
    const wgslDir = path.join(effectDir, 'wgsl');
    
    // Check if both directories exist
    let glslFiles = [];
    let wgslFiles = [];
    
    try {
        glslFiles = fs.readdirSync(glslDir).filter(f => f.endsWith('.glsl') || f.endsWith('.vert') || f.endsWith('.frag'));
    } catch {
        // GLSL directory doesn't exist
    }
    
    try {
        wgslFiles = fs.readdirSync(wgslDir).filter(f => f.endsWith('.wgsl'));
    } catch {
        // WGSL directory doesn't exist
    }
    
    if (glslFiles.length === 0 && wgslFiles.length === 0) {
        return {
            status: 'error',
            pairs: [],
            summary: `No shader files found for ${effectId}`
        };
    }
    
    if (glslFiles.length === 0) {
        return {
            status: 'ok',
            pairs: [],
            summary: `${effectId}: WGSL-only effect (${wgslFiles.length} files), no parity check needed`
        };
    }
    
    if (wgslFiles.length === 0) {
        return {
            status: 'ok',
            pairs: [],
            summary: `${effectId}: GLSL-only effect (${glslFiles.length} files), no parity check needed`
        };
    }
    
    // Find matching pairs by base name
    // GLSL can have .glsl, .vert, .frag extensions
    // WGSL always has .wgsl extension
    const pairs = [];
    const processedWgsl = new Set();
    
    for (const glslFile of glslFiles) {
        // Get base name (strip extension)
        const baseName = glslFile.replace(/\.(glsl|vert|frag)$/, '');
        const wgslFile = `${baseName}.wgsl`;
        
        if (wgslFiles.includes(wgslFile)) {
            processedWgsl.add(wgslFile);
            
            const glslPath = path.join(glslDir, glslFile);
            const wgslPath = path.join(wgslDir, wgslFile);
            
            const glslSource = fs.readFileSync(glslPath, 'utf-8');
            const wgslSource = fs.readFileSync(wgslPath, 'utf-8');
            
            pairs.push({
                program: baseName,
                glslFile,
                wgslFile,
                glsl: glslSource,
                wgsl: wgslSource
            });
        }
    }
    
    // Note any unmatched files
    const unmatchedGlsl = glslFiles.filter(f => {
        const baseName = f.replace(/\.(glsl|vert|frag)$/, '');
        return !wgslFiles.includes(`${baseName}.wgsl`);
    });
    
    const unmatchedWgsl = wgslFiles.filter(f => !processedWgsl.has(f));
    
    if (pairs.length === 0) {
        const summary = [];
        if (unmatchedGlsl.length > 0) summary.push(`GLSL-only: ${unmatchedGlsl.join(', ')}`);
        if (unmatchedWgsl.length > 0) summary.push(`WGSL-only: ${unmatchedWgsl.join(', ')}`);
        return {
            status: 'ok',
            pairs: [],
            summary: `${effectId}: No matching shader pairs found. ${summary.join('. ')}`
        };
    }
    
    // Read the effect definition for context
    let definitionSource = '';
    try {
        const definitionPath = path.join(effectDir, 'definition.js');
        definitionSource = fs.readFileSync(definitionPath, 'utf-8');
    } catch {
        // Definition file doesn't exist or can't be read
    }
    
    // Compare each pair using OpenAI API
    const results = [];
    let hasDivergent = false;
    
    for (const pair of pairs) {
        const systemPrompt = `You are an expert shader programmer analyzing algorithmic equivalence between GLSL (WebGL2) and WGSL (WebGPU) shader implementations.

IMPORTANT CONTEXT about our shader pipeline:
- We use "type: compute" semantically for passes that do GPGPU-style work (simulations, state updates, multi-output)
- On WebGPU: These run as native @compute shaders
- On WebGL2: These are AUTOMATICALLY converted to render passes (fragment shaders with MRT)
- Therefore, a GLSL fragment shader and a WGSL compute shader for the same pass ARE expected to be equivalent
- The conversion handles: workgroup concepts → pixel iteration, storage textures → render targets
- Do NOT flag as divergent just because one is a fragment shader and one is a compute shader

Your task is to determine if these two shaders implement the SAME algorithm, accounting for:
- Language syntax differences (vec3 vs vec3<f32>, etc.)
- Built-in function name differences (mix vs mix, texture vs textureSample, etc.)
- Binding/uniform declaration differences
- Fragment shader vs compute shader structural differences (these are expected cross-backend)
- Minor numerical precision variations that are acceptable

Flag as DIVERGENT only if:
- The core algorithm is fundamentally different
- One has features the other lacks entirely
- Mathematical operations differ in ways that would produce notably different output
- Control flow logic differs substantially

Respond with JSON containing:
- parity: "equivalent" or "divergent"
- confidence: "high", "medium", or "low"
- notes: Brief explanation of your assessment (1-2 sentences)
- concerns: Array of specific concerns if any (empty array if none)`;

        // Build context about this specific program from the definition
        let programContext = '';
        if (definitionSource) {
            // Extract the pass definition for this program
            const passPattern = new RegExp(`\\{[^}]*program:\\s*["']${pair.program}["'][^}]*\\}`, 's');
            const passMatch = definitionSource.match(passPattern);
            if (passMatch) {
                programContext = `\n\n=== Pass Definition for "${pair.program}" ===\n${passMatch[0]}`;
            }
        }

        const userPrompt = `Compare these shader implementations for algorithmic equivalence:
${definitionSource ? `\n=== Effect Definition (for context) ===\n${definitionSource.slice(0, 2000)}${definitionSource.length > 2000 ? '\n... (truncated)' : ''}` : ''}
${programContext}

=== GLSL (${pair.glslFile}) ===
${pair.glsl}

=== WGSL (${pair.wgslFile}) ===
${pair.wgsl}

Are these implementations algorithmically equivalent?`;

        try {
            const response = await fetch('https://api.openai.com/v1/chat/completions', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${apiKey}`
                },
                body: JSON.stringify({
                    model,
                    messages: [
                        { role: 'system', content: systemPrompt },
                        { role: 'user', content: userPrompt }
                    ],
                    max_tokens: 500,
                    response_format: { type: 'json_object' }
                })
            });
            
            if (!response.ok) {
                const errorText = await response.text();
                results.push({
                    program: pair.program,
                    parity: 'error',
                    notes: `API error: ${response.status} - ${errorText.slice(0, 100)}`
                });
                continue;
            }
            
            const data = await response.json();
            const content = data.choices?.[0]?.message?.content;
            
            if (!content) {
                results.push({
                    program: pair.program,
                    parity: 'error',
                    notes: 'No response from model'
                });
                continue;
            }
            
            const analysis = JSON.parse(content);
            const isDivergent = analysis.parity === 'divergent';
            if (isDivergent) hasDivergent = true;
            
            results.push({
                program: pair.program,
                parity: analysis.parity,
                confidence: analysis.confidence,
                notes: analysis.notes,
                concerns: analysis.concerns || []
            });
            
        } catch (err) {
            results.push({
                program: pair.program,
                parity: 'error',
                notes: `Analysis failed: ${err.message}`
            });
        }
    }
    
    // Build summary
    const equivalent = results.filter(r => r.parity === 'equivalent').length;
    const divergent = results.filter(r => r.parity === 'divergent').length;
    const errors = results.filter(r => r.parity === 'error').length;
    
    let summaryParts = [`${effectId}: ${pairs.length} shader pair(s) analyzed`];
    if (equivalent > 0) summaryParts.push(`${equivalent} equivalent`);
    if (divergent > 0) summaryParts.push(`${divergent} DIVERGENT`);
    if (errors > 0) summaryParts.push(`${errors} errors`);
    if (unmatchedGlsl.length > 0) summaryParts.push(`${unmatchedGlsl.length} GLSL-only`);
    if (unmatchedWgsl.length > 0) summaryParts.push(`${unmatchedWgsl.length} WGSL-only`);
    
    return {
        status: hasDivergent ? 'divergent' : 'ok',
        pairs: results,
        unmatchedGlsl,
        unmatchedWgsl,
        summary: summaryParts.join(', ')
    };
}
