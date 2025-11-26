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
