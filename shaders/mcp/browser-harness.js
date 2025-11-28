/**
 * Browser Harness for Shader Effect Testing
 * 
 * Manages a persistent Playwright browser session for executing shader
 * operations in a real WebGL2/WebGPU context. This harness:
 * 
 * - Launches a Chromium browser with WebGPU support
 * - Starts a local HTTP server for the demo page
 * - Provides methods that map to the core operations
 * - Handles browser lifecycle management
 */

import { chromium } from '@playwright/test';
import { spawn } from 'child_process';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';
import {
    compileEffect,
    renderEffectFrame,
    benchmarkEffectFps,
    describeEffectFrame,
    checkEffectStructure,
    checkShaderParity,
    testNoPassthrough,
    isFilterEffect,
    STATUS_TIMEOUT
} from './core-operations.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const PROJECT_ROOT = path.resolve(__dirname, '../..');

/**
 * Browser harness for shader testing
 */
export class BrowserHarness {
    constructor(options = {}) {
        this.options = {
            host: options.host || '127.0.0.1',
            port: options.port || 4173,
            headless: options.headless !== false,
            ...options
        };
        
        this.browser = null;
        this.context = null;
        this.page = null;
        this.serverProcess = null;
        this.baseUrl = `http://${this.options.host}:${this.options.port}`;
        
        // Track shader file changes for smart reload
        this.shadersDirty = false;
        this.fileWatchers = [];  // Track all watchers for proper cleanup
        this.lastReloadTime = 0;
    }
    
    /**
     * Initialize the browser harness
     */
    async init() {
        // Start the HTTP server
        await this.startServer();
        
        // Launch browser with WebGPU support
        const launchOptions = {
            headless: this.options.headless,
            args: [
                '--enable-unsafe-webgpu',
                '--enable-features=Vulkan',
                '--enable-webgpu-developer-features',
                '--disable-gpu-sandbox',
                process.platform === 'darwin' ? '--use-angle=metal' : '--use-angle=vulkan',
            ]
        };
        
        this.browser = await chromium.launch(launchOptions);
        this.context = await this.browser.newContext({
            viewport: { width: 1280, height: 720 },
            ignoreHTTPSErrors: true
        });
        
        this.page = await this.context.newPage();
        this.page.setDefaultTimeout(STATUS_TIMEOUT);
        this.page.setDefaultNavigationTimeout(STATUS_TIMEOUT);
        
        // Capture console messages
        this.consoleMessages = [];
        this.page.on('console', msg => {
            const text = msg.text();
            // Capture relevant messages for debugging
            if (text.includes('Error') || text.includes('error') || text.includes('warning') || 
                text.includes('Storage') || text.includes('getOutput') ||
                text.includes('[bindTextures]') || text.includes('DSL') ||
                text.includes('[WebGPU') || text.includes('GPGPU') ||
                text.includes('[passthrough]') || text.includes('[DEBUG]') ||
                msg.type() === 'error' || msg.type() === 'warning') {
                this.consoleMessages.push({ type: msg.type(), text });
            }
        });
        
        this.page.on('pageerror', error => {
            this.consoleMessages.push({ type: 'pageerror', text: error.message });
        });
        
        // Navigate to the demo page
        await this.page.goto(`${this.baseUrl}/demo/shaders/`);
        
        // Wait for the app to be ready
        await this.page.waitForFunction(() => {
            const app = document.getElementById('app-container');
            return !!app && window.getComputedStyle(app).display !== 'none';
        }, { timeout: STATUS_TIMEOUT });
        
        // Wait for effects to load
        await this.page.waitForFunction(
            () => document.querySelectorAll('#effect-select option').length > 0,
            { timeout: STATUS_TIMEOUT }
        );
        
        // Start watching shader files for changes
        this.startFileWatcher();
        this.lastReloadTime = Date.now();
    }
    
    /**
     * Start watching shader files for changes
     */
    startFileWatcher() {
        const _shadersDir = path.join(PROJECT_ROOT, 'shaders');
        const srcDir = path.join(PROJECT_ROOT, 'shaders/src');
        const effectsDir = path.join(PROJECT_ROOT, 'shaders/effects');
        
        // Watch for changes in shader directories
        const watchDirs = [srcDir, effectsDir];
        
        for (const dir of watchDirs) {
            if (fs.existsSync(dir)) {
                const watcher = fs.watch(dir, { recursive: true }, (eventType, filename) => {
                    if (filename && (filename.endsWith('.js') || filename.endsWith('.glsl') || 
                        filename.endsWith('.wgsl') || filename.endsWith('.json'))) {
                        this.shadersDirty = true;
                    }
                });
                // Track all watchers for proper cleanup
                this.fileWatchers.push(watcher);
            }
        }
    }
    
    /**
     * Reload the page if shader files have changed
     * @returns {Promise<boolean>} True if page was reloaded
     */
    async reloadIfDirty() {
        if (!this.shadersDirty) return false;
        
        this.shadersDirty = false;
        this.consoleMessages = [];
        
        // Clear browser cache to ensure fresh module imports
        // This is crucial for ES module hot reloading
        const client = await this.context.newCDPSession(this.page);
        await client.send('Network.clearBrowserCache');
        await client.detach();
        
        // Use goto with cache bypass instead of reload
        // This forces a fresh fetch of all resources including ES modules
        await this.page.goto(`${this.baseUrl}/demo/shaders/`, { 
            waitUntil: 'networkidle' 
        });
        
        // Wait for the app to be ready again
        await this.page.waitForFunction(() => {
            const app = document.getElementById('app-container');
            return !!app && window.getComputedStyle(app).display !== 'none';
        }, { timeout: STATUS_TIMEOUT });
        
        // Wait for effects to load
        await this.page.waitForFunction(
            () => document.querySelectorAll('#effect-select option').length > 0,
            { timeout: STATUS_TIMEOUT }
        );
        
        this.lastReloadTime = Date.now();
        return true;
    }
    
    /**
     * Start the HTTP server
     */
    async startServer() {
        return new Promise((resolve, reject) => {
            const serverScript = path.join(PROJECT_ROOT, 'shaders/scripts/serve.js');
            
            this.serverProcess = spawn('node', [serverScript], {
                cwd: PROJECT_ROOT,
                env: {
                    ...process.env,
                    HOST: this.options.host,
                    PORT: String(this.options.port)
                },
                stdio: ['ignore', 'pipe', 'pipe']
            });
            
            let started = false;
            
            this.serverProcess.stdout.on('data', (data) => {
                const output = data.toString();
                if (output.includes('listening') || !started) {
                    started = true;
                }
            });
            
            this.serverProcess.stderr.on('data', (_data) => {
                // Server logs to stderr
            });
            
            this.serverProcess.on('error', (err) => {
                reject(new Error(`Failed to start server: ${err.message}`));
            });
            
            // Give server time to start
            setTimeout(() => {
                if (!started) {
                    // Try to connect anyway
                }
                resolve();
            }, 1000);
        });
    }
    
    /**
     * Clear console messages
     */
    clearConsoleMessages() {
        this.consoleMessages = [];
    }
    
    /**
     * Get console messages
     */
    getConsoleMessages() {
        return this.consoleMessages || [];
    }
    
    /**
     * Compile an effect
     */
    async compileEffect(effectId, options = {}) {
        await this.reloadIfDirty();
        this.consoleMessages = [];
        const result = await compileEffect(this.page, effectId, options);
        
        // Include any console errors in the result
        if (this.consoleMessages.length > 0) {
            result.console_errors = this.consoleMessages.map(m => m.text);
        }
        
        return result;
    }
    
    /**
     * Render an effect frame and compute metrics
     */
    async renderEffectFrame(effectId, options = {}) {
        await this.reloadIfDirty();
        this.consoleMessages = [];
        const result = await renderEffectFrame(this.page, effectId, options);
        
        if (this.consoleMessages.length > 0) {
            result.console_errors = this.consoleMessages.map(m => m.text);
        }
        
        return result;
    }
    
    /**
     * Benchmark effect FPS
     */
    async benchmarkEffectFps(effectId, options = {}) {
        await this.reloadIfDirty();
        this.consoleMessages = [];
        const result = await benchmarkEffectFps(this.page, effectId, options);
        
        if (this.consoleMessages.length > 0) {
            result.console_errors = this.consoleMessages.map(m => m.text);
        }
        
        return result;
    }
    
    /**
     * Describe effect frame with AI vision
     */
    async describeEffectFrame(effectId, prompt, options = {}) {
        await this.reloadIfDirty();
        this.consoleMessages = [];
        const result = await describeEffectFrame(this.page, effectId, prompt, options);
        
        if (this.consoleMessages.length > 0) {
            result.console_errors = this.consoleMessages.map(m => m.text);
        }
        
        return result;
    }
    
    /**
     * Check effect structure for unused files and compute pass requirements
     * @param {string} effectId - Effect identifier
     * @param {object} options
     * @returns {Promise<{unusedFiles: string[], multiPass: boolean, hasComputePass: boolean, passCount: number, passTypes: string[]}>}
     */
    async checkEffectStructure(effectId, options = {}) {
        return await checkEffectStructure(effectId, options);
    }
    
    /**
     * Check algorithmic parity between GLSL and WGSL shader implementations
     * @param {string} effectId - Effect identifier
     * @param {object} options
     * @returns {Promise<{status: 'ok'|'error'|'divergent', pairs: Array, summary: string}>}
     */
    async checkShaderParity(effectId, options = {}) {
        return await checkShaderParity(effectId, options);
    }
    
    /**
     * Check if an effect is a filter-type effect (takes texture input)
     * @param {string} effectId - Effect identifier
     * @returns {Promise<boolean>}
     */
    async isFilterEffect(effectId) {
        return await isFilterEffect(effectId);
    }
    
    /**
     * Test that a filter effect does NOT pass through its input unchanged.
     * Passthrough/no-op/placeholder shaders are STRICTLY FORBIDDEN.
     * @param {string} effectId - Effect identifier
     * @param {object} options
     * @param {'webgl2'|'webgpu'} [options.backend='webgl2'] - Rendering backend
     * @param {boolean} [options.skipCompile] - Skip initial compilation (effect already loaded)
     * @returns {Promise<{status: 'ok'|'error'|'skipped'|'passthrough', isFilterEffect: boolean, similarity: number, details: string}>}
     */
    async testNoPassthrough(effectId, options = {}) {
        await this.reloadIfDirty();
        this.consoleMessages = [];
        const result = await testNoPassthrough(this.page, effectId, options);
        
        if (this.consoleMessages.length > 0) {
            result.console_errors = this.consoleMessages.map(m => m.text);
        }
        
        return result;
    }
    
    /**
     * Get list of available effects
     */
    async listEffects() {
        const effects = await this.page.$$eval(
            '#effect-select option',
            options => options.map(opt => opt.value).filter(v => v)
        );
        return effects;
    }
    
    /**
     * Get effect globals (parameters) for the currently loaded effect
     * @returns {Promise<Object>} Map of parameter names to their specs
     */
    async getEffectGlobals() {
        return await this.page.evaluate(() => {
            const effect = window.__noisemakerCurrentEffect;
            if (!effect || !effect.instance || !effect.instance.globals) {
                return {};
            }
            return effect.instance.globals;
        });
    }
    
    /**
     * Test if an effect responds to uniform control changes
     * Renders with default values, then with modified values, and checks if output differs
     * @param {string} effectId - Effect to test
     * @param {object} options
     * @param {boolean} [options.skipCompile] - Skip initial compilation (effect already loaded)
     * @returns {Promise<{status: 'ok'|'error'|'skipped', tested_uniforms: string[], details: string}>}
     */
    async testUniformResponsiveness(effectId, options = {}) {
        const backend = options.backend || 'webgl2';
        
        // Only compile if not already loaded
        if (!options.skipCompile) {
            const compileResult = await this.compileEffect(effectId, { backend });
            if (compileResult.status === 'error') {
                return { status: 'error', tested_uniforms: [], details: compileResult.message };
            }
        }
        
        // Get globals
        const globals = await this.getEffectGlobals();
        
        // Find testable numeric uniforms (with min/max range or numeric type with default)
        const testableUniforms = [];
        for (const [name, spec] of Object.entries(globals)) {
            if (!spec.uniform) continue;
            
            // Skip non-numeric types
            if (spec.type === 'boolean' || spec.type === 'button' || spec.type === 'member') continue;
            
            // Has explicit range
            if (typeof spec.min === 'number' && typeof spec.max === 'number' && spec.min !== spec.max) {
                testableUniforms.push({ name, uniformName: spec.uniform, spec });
            }
            // Has default and is float/int type - use synthetic range
            else if (typeof spec.default === 'number' && (spec.type === 'float' || spec.type === 'int')) {
                const syntheticSpec = {
                    ...spec,
                    min: spec.default * 0.1,
                    max: spec.default * 2 + 1
                };
                testableUniforms.push({ name, uniformName: spec.uniform, spec: syntheticSpec });
            }
        }
        
        if (testableUniforms.length === 0) {
            return { status: 'skipped', tested_uniforms: [], details: 'No testable numeric uniforms' };
        }
        
        // Render with default values and capture a hash
        const baseRender = await this.renderEffectFrame(effectId, { 
            skipCompile: true, 
            backend,
            warmupFrames: 5
        });
        if (baseRender.status === 'error') {
            return { status: 'error', tested_uniforms: [], details: baseRender.error };
        }
        const baseHash = baseRender.metrics?.unique_sampled_colors || 0;
        const baseMeanLuma = baseRender.metrics?.mean_rgb ? 
            (baseRender.metrics.mean_rgb[0] + baseRender.metrics.mean_rgb[1] + baseRender.metrics.mean_rgb[2]) / 3 : 0;
        
        // Test each uniform
        const testedUniforms = [];
        let anyResponded = false;
        
        for (const { name, uniformName, spec } of testableUniforms.slice(0, 3)) { // Test up to 3 uniforms
            // Pick a value that will produce visible change
            // Avoid values exactly 1.0 apart (which wrap identically with fract())
            const defaultVal = spec.default ?? spec.min;
            const range = spec.max - spec.min;
            let testVal;
            
            if (range <= 0) {
                testVal = defaultVal; // Can't test - no range
            } else if (defaultVal === spec.min) {
                // Default is at min, use 75% of range (avoids 1.0 wrap)
                testVal = spec.min + range * 0.75;
            } else if (defaultVal === spec.max) {
                // Default is at max, use 25% of range
                testVal = spec.min + range * 0.25;
            } else {
                // Default is in middle - move 50% toward whichever extreme is farther
                const distToMin = defaultVal - spec.min;
                const distToMax = spec.max - defaultVal;
                if (distToMax > distToMin) {
                    testVal = defaultVal + distToMax * 0.5;
                } else {
                    testVal = defaultVal - distToMin * 0.5;
                }
            }
            
            // For int types, round
            if (spec.type === 'int') {
                testVal = Math.round(testVal);
            }
            
            // Apply the uniform change only to passes belonging to this effect
            // (not to upstream generator passes that may have same-named uniforms)
            await this.page.evaluate(({ uniformName, testVal, effectId }) => {
                const pipeline = window.__noisemakerRenderingPipeline;
                if (!pipeline || !pipeline.graph || !pipeline.graph.passes) return;
                
                // Parse effectId to get namespace/func
                const parts = effectId.split('/');
                const effectNamespace = parts.length > 1 ? parts[0] : null;
                const effectFunc = parts[parts.length - 1];
                
                // Only set on passes that belong to this effect (not upstream generators)
                for (const pass of pipeline.graph.passes) {
                    if (!pass.uniforms || !(uniformName in pass.uniforms)) continue;
                    
                    // Check if this pass belongs to the effect we're testing
                    const matchesNamespace = effectNamespace && pass.effectNamespace === effectNamespace;
                    const matchesFunc = pass.effectFunc === effectFunc;
                    
                    if (matchesNamespace || matchesFunc) {
                        pass.uniforms[uniformName] = testVal;
                    }
                }
            }, { uniformName, testVal, effectId });
            
            // Render with the new uniform value - need enough frames for change to take effect
            const testRender = await this.renderEffectFrame(effectId, {
                skipCompile: true,
                backend,
                warmupFrames: 5
            });
            
            if (testRender.status === 'ok') {
                const testHash = testRender.metrics?.unique_sampled_colors || 0;
                const testMeanLuma = testRender.metrics?.mean_rgb ?
                    (testRender.metrics.mean_rgb[0] + testRender.metrics.mean_rgb[1] + testRender.metrics.mean_rgb[2]) / 3 : 0;
                
                // Check if output changed meaningfully
                const colorDiff = Math.abs(testHash - baseHash);
                const lumaDiff = Math.abs(testMeanLuma - baseMeanLuma);
                
                if (colorDiff > 5 || lumaDiff > 0.01) {
                    anyResponded = true;
                    testedUniforms.push(`${name}:✓`);
                } else {
                    testedUniforms.push(`${name}:✗`);
                }
            }
            
            // Reset uniform to default only on effect-specific passes
            await this.page.evaluate(({ uniformName, defaultVal, effectId }) => {
                const pipeline = window.__noisemakerRenderingPipeline;
                if (!pipeline || !pipeline.graph || !pipeline.graph.passes) return;
                
                // Parse effectId to get namespace/func
                const parts = effectId.split('/');
                const effectNamespace = parts.length > 1 ? parts[0] : null;
                const effectFunc = parts[parts.length - 1];
                
                // Only reset on passes that belong to this effect
                for (const pass of pipeline.graph.passes) {
                    if (!pass.uniforms || !(uniformName in pass.uniforms)) continue;
                    
                    const matchesNamespace = effectNamespace && pass.effectNamespace === effectNamespace;
                    const matchesFunc = pass.effectFunc === effectFunc;
                    
                    if (matchesNamespace || matchesFunc) {
                        pass.uniforms[uniformName] = defaultVal;
                    }
                }
            }, { uniformName, defaultVal, effectId });
        }
        
        // Always reset all uniforms to defaults at the end of the test
        await this.resetUniformsToDefaults();
        
        return {
            status: anyResponded ? 'ok' : 'error',
            tested_uniforms: testedUniforms,
            details: anyResponded ? 'Uniforms affect output' : 'No uniforms affected output'
        };
    }
    
    /**
     * Reset all uniforms to their default values, including time and seed.
     * This ensures a clean state between tests.
     */
    async resetUniformsToDefaults() {
        await this.page.evaluate(() => {
            const pipeline = window.__noisemakerRenderingPipeline;
            const effect = window.__noisemakerCurrentEffect;
            
            if (!pipeline || !effect?.instance?.globals) return;
            
            const globals = effect.instance.globals;
            
            // Reset all uniforms to their default values
            for (const [_key, spec] of Object.entries(globals)) {
                if (!spec.uniform) continue;
                
                const defaultVal = spec.default ?? spec.min ?? 0;
                
                // Apply to pipeline.globalUniforms (source of truth)
                if (pipeline.globalUniforms) {
                    pipeline.globalUniforms[spec.uniform] = defaultVal;
                }
                
                // Also apply to all passes
                for (const pass of pipeline.graph?.passes || []) {
                    if (pass.uniforms && spec.uniform in pass.uniforms) {
                        pass.uniforms[spec.uniform] = defaultVal;
                    }
                }
            }
            
            // Also reset built-in time to known values
            // NOTE: Do NOT reset seed here - it's an effect-specific parameter set by DSL
            if (pipeline.globalUniforms) {
                if ('time' in pipeline.globalUniforms) {
                    pipeline.globalUniforms.time = 0;
                }
                if ('u_time' in pipeline.globalUniforms) {
                    pipeline.globalUniforms.u_time = 0;
                }
            }
            for (const pass of pipeline.graph?.passes || []) {
                if (pass.uniforms) {
                    // Reset time to 0
                    if ('time' in pass.uniforms) {
                        pass.uniforms.time = 0;
                    }
                    if ('u_time' in pass.uniforms) {
                        pass.uniforms.u_time = 0;
                    }
                }
            }
        });
    }
    
    /**
     * Close the browser harness
     */
    async close() {
        // Close all file watchers
        for (const watcher of this.fileWatchers) {
            watcher.close();
        }
        this.fileWatchers = [];
        
        if (this.page) {
            await this.page.close();
            this.page = null;
        }
        
        if (this.context) {
            await this.context.close();
            this.context = null;
        }
        
        if (this.browser) {
            await this.browser.close();
            this.browser = null;
        }
        
        if (this.serverProcess) {
            this.serverProcess.kill('SIGTERM');
            // Unref to allow process exit even if kill is slow
            this.serverProcess.unref();
            this.serverProcess = null;
        }
    }
}

/**
 * Create a browser harness with default options
 */
export async function createBrowserHarness(options = {}) {
    const harness = new BrowserHarness(options);
    await harness.init();
    return harness;
}
