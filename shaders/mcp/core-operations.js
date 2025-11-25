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
    // First check for .openai file in project root
    const keyFile = path.join(PROJECT_ROOT, '.openai');
    try {
        const key = fs.readFileSync(keyFile, 'utf-8').trim();
        if (key) return key;
    } catch {
        // File doesn't exist or can't be read
    }
    // Fall back to environment variable
    return process.env.OPENAI_API_KEY || null;
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
 * @param {number} [options.time] - Time to render at
 * @param {[number,number]} [options.resolution] - Resolution [width, height]
 * @param {number} [options.seed] - Random seed
 * @param {Record<string,any>} [options.uniforms] - Uniform overrides
 * @param {number} [options.warmupFrames=1] - Frames to render before capture
 * @returns {Promise<{status: 'ok'|'error', frame: {image_uri: string, width: number, height: number}, metrics: object}>}
 */
export async function renderEffectFrame(page, effectId, options = {}) {
    const warmupFrames = options.warmupFrames ?? 1;
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
    
    // Single round-trip: apply uniforms, render warmup, read pixels, compute metrics in browser
    const result = await page.evaluate(async ({ uniforms, warmupFrames }) => {
        const pipeline = window.__noisemakerRenderingPipeline;
        if (!pipeline) {
            return { error: 'Pipeline not available' };
        }
        
        // Apply uniform overrides
        if (uniforms && pipeline.globalUniforms) {
            Object.assign(pipeline.globalUniforms, uniforms);
        }
        
        // Render warmup frames
        const t = performance.now() / 1000;
        for (let i = 0; i < warmupFrames; i++) {
            pipeline.render(t + i * 0.016);
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
            
            data = new Uint8Array(width * height * 4);
            gl.readPixels(0, 0, width, height, gl.RGBA, gl.UNSIGNED_BYTE, data);
            
            gl.bindFramebuffer(gl.FRAMEBUFFER, null);
            gl.deleteFramebuffer(fbo);
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
    }, { uniforms: options.uniforms, warmupFrames });
    
    if (result.error) {
        return {
            status: 'error',
            frame: null,
            metrics: null,
            error: result.error
        };
    }
    
    return {
        status: 'ok',
        frame: {
            image_uri: null,  // Not computed for speed
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
 * @param {string} [options.apiKey] - OpenAI API key (falls back to OPENAI_API_KEY env var)
 * @param {string} [options.model='gpt-4o'] - Vision model to use
 * @returns {Promise<{status: 'ok'|'error', frame: {image_uri: string}, vision: {description: string, tags: string[], notes?: string}}>}
 */
export async function describeEffectFrame(page, effectId, prompt, options = {}) {
    // First render the frame
    const renderResult = await renderEffectFrame(page, effectId, options);
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
            error: 'No OpenAI API key found. Create .openai file in project root or set OPENAI_API_KEY environment variable.'
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
