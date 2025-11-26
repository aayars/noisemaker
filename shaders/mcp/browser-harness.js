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
import { fileURLToPath } from 'url';
import {
    compileEffect,
    renderEffectFrame,
    benchmarkEffectFps,
    describeEffectFrame,
    checkEffectStructure,
    checkShaderParity,
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
            // Capture all messages for debugging
            if (text.includes('Error') || text.includes('error') || text.includes('warning') || 
                text.includes('Storage') || text.includes('getOutput') ||
                text.includes('[bindTextures]') || text.includes('DSL') ||
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
     * @returns {Promise<{status: 'ok'|'error'|'skipped', tested_uniforms: string[], details: string}>}
     */
    async testUniformResponsiveness(effectId, options = {}) {
        const backend = options.backend || 'webgl2';
        
        // Compile the effect first
        const compileResult = await this.compileEffect(effectId, { backend });
        if (compileResult.status === 'error') {
            return { status: 'error', tested_uniforms: [], details: compileResult.message };
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
            // Pick a value far from default
            const defaultVal = spec.default ?? spec.min;
            const testVal = defaultVal === spec.min ? spec.max : spec.min;
            
            // Apply the uniform change via page evaluation
            await this.page.evaluate(({ uniformName, testVal }) => {
                const pipeline = window.__noisemakerRenderingPipeline;
                if (pipeline && pipeline.globalUniforms) {
                    pipeline.globalUniforms[uniformName] = testVal;
                }
            }, { uniformName, testVal });
            
            // Render again
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
            
            // Reset uniform to default
            await this.page.evaluate(({ uniformName, defaultVal }) => {
                const pipeline = window.__noisemakerRenderingPipeline;
                if (pipeline && pipeline.globalUniforms) {
                    pipeline.globalUniforms[uniformName] = defaultVal;
                }
            }, { uniformName, defaultVal });
        }
        
        return {
            status: anyResponded ? 'ok' : 'error',
            tested_uniforms: testedUniforms,
            details: anyResponded ? 'Uniforms affect output' : 'No uniforms affected output'
        };
    }
    
    /**
     * Close the browser harness
     */
    async close() {
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
            this.serverProcess.kill();
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
