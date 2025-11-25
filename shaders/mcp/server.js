#!/usr/bin/env node
/**
 * MCP Server for Shader Effect Testing
 * 
 * This MCP server exposes shader testing capabilities as tools that can be
 * used by VS Code Copilot coding agent. It provides:
 * 
 * - compile_effect: Compile a shader and verify it compiles cleanly
 * - render_effect_frame: Render a frame and check for monochrome/blank output
 * - describe_effect_frame: Use AI vision to describe rendered output
 * - benchmark_effect_fps: Verify shader can sustain target framerate
 * 
 * The server uses a persistent browser session via Playwright to execute
 * shader operations in a real WebGL2/WebGPU context.
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
    CallToolRequestSchema,
    ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';

// Import the browser harness (we'll create this next)
import { BrowserHarness } from './browser-harness.js';

const server = new Server(
    {
        name: 'noisemaker-shader-tools',
        version: '1.0.0',
    },
    {
        capabilities: {
            tools: {},
        },
    }
);

// Browser harness singleton
let browserHarness = null;

/**
 * Get or create the browser harness
 */
async function getHarness() {
    if (!browserHarness) {
        browserHarness = new BrowserHarness();
        await browserHarness.init();
    }
    return browserHarness;
}

/**
 * Tool definitions
 */
const TOOLS = [
    {
        name: 'compile_effect',
        description: 'Compile a shader effect and verify it compiles cleanly. Returns detailed pass-level diagnostics.',
        inputSchema: {
            type: 'object',
            properties: {
                effect_id: {
                    type: 'string',
                    description: 'Effect identifier (e.g., "basics/noise", "nd/physarum")'
                },
                backend: {
                    type: 'string',
                    enum: ['webgl2', 'webgpu'],
                    default: 'webgl2',
                    description: 'Rendering backend to use'
                }
            },
            required: ['effect_id']
        }
    },
    {
        name: 'render_effect_frame',
        description: 'Render a single frame of a shader effect and analyze if the output is monochrome/blank. Returns image metrics and a captured frame.',
        inputSchema: {
            type: 'object',
            properties: {
                effect_id: {
                    type: 'string',
                    description: 'Effect identifier (e.g., "basics/noise")'
                },
                test_case: {
                    type: 'object',
                    description: 'Optional test configuration',
                    properties: {
                        time: {
                            type: 'number',
                            description: 'Time value to render at'
                        },
                        resolution: {
                            type: 'array',
                            items: { type: 'number' },
                            minItems: 2,
                            maxItems: 2,
                            description: 'Resolution [width, height]'
                        },
                        seed: {
                            type: 'number',
                            description: 'Random seed for reproducibility'
                        },
                        uniforms: {
                            type: 'object',
                            additionalProperties: true,
                            description: 'Uniform overrides'
                        }
                    }
                }
            },
            required: ['effect_id']
        }
    },
    {
        name: 'describe_effect_frame',
        description: 'Render a frame and get an AI vision description. Uses OpenAI GPT-4 Vision to analyze the rendered output.',
        inputSchema: {
            type: 'object',
            properties: {
                effect_id: {
                    type: 'string',
                    description: 'Effect identifier (e.g., "basics/noise")'
                },
                prompt: {
                    type: 'string',
                    description: 'Vision prompt - what to analyze or look for in the image'
                },
                test_case: {
                    type: 'object',
                    description: 'Optional test configuration',
                    properties: {
                        time: {
                            type: 'number',
                            description: 'Time value to render at'
                        },
                        resolution: {
                            type: 'array',
                            items: { type: 'number' },
                            minItems: 2,
                            maxItems: 2,
                            description: 'Resolution [width, height]'
                        },
                        seed: {
                            type: 'number',
                            description: 'Random seed'
                        },
                        uniforms: {
                            type: 'object',
                            additionalProperties: true,
                            description: 'Uniform overrides'
                        }
                    }
                }
            },
            required: ['effect_id', 'prompt']
        }
    },
    {
        name: 'benchmark_effect_fps',
        description: 'Benchmark a shader effect to verify it can sustain a target framerate. Runs the effect for a specified duration and measures frame times.',
        inputSchema: {
            type: 'object',
            properties: {
                effect_id: {
                    type: 'string',
                    description: 'Effect identifier (e.g., "basics/noise")'
                },
                target_fps: {
                    type: 'number',
                    default: 60,
                    description: 'Target FPS to achieve'
                },
                duration_seconds: {
                    type: 'number',
                    default: 5,
                    description: 'Duration of benchmark in seconds'
                },
                resolution: {
                    type: 'array',
                    items: { type: 'number' },
                    minItems: 2,
                    maxItems: 2,
                    description: 'Resolution [width, height]'
                },
                backend: {
                    type: 'string',
                    enum: ['webgl2', 'webgpu'],
                    default: 'webgl2',
                    description: 'Rendering backend'
                }
            },
            required: ['effect_id', 'target_fps']
        }
    }
];

/**
 * Handle list tools request
 */
server.setRequestHandler(ListToolsRequestSchema, async () => {
    return { tools: TOOLS };
});

/**
 * Handle tool call request
 */
server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const { name, arguments: args } = request.params;
    
    try {
        const harness = await getHarness();
        
        switch (name) {
            case 'compile_effect': {
                const result = await harness.compileEffect(
                    args.effect_id,
                    { backend: args.backend }
                );
                return {
                    content: [{
                        type: 'text',
                        text: JSON.stringify(result, null, 2)
                    }]
                };
            }
            
            case 'render_effect_frame': {
                const testCase = args.test_case || {};
                const result = await harness.renderEffectFrame(
                    args.effect_id,
                    {
                        time: testCase.time,
                        resolution: testCase.resolution,
                        seed: testCase.seed,
                        uniforms: testCase.uniforms
                    }
                );
                return {
                    content: [{
                        type: 'text',
                        text: JSON.stringify(result, null, 2)
                    }]
                };
            }
            
            case 'describe_effect_frame': {
                const testCase = args.test_case || {};
                const result = await harness.describeEffectFrame(
                    args.effect_id,
                    args.prompt,
                    {
                        time: testCase.time,
                        resolution: testCase.resolution,
                        seed: testCase.seed,
                        uniforms: testCase.uniforms
                    }
                );
                return {
                    content: [{
                        type: 'text',
                        text: JSON.stringify(result, null, 2)
                    }]
                };
            }
            
            case 'benchmark_effect_fps': {
                const result = await harness.benchmarkEffectFps(
                    args.effect_id,
                    {
                        targetFps: args.target_fps,
                        durationSeconds: args.duration_seconds,
                        resolution: args.resolution,
                        backend: args.backend
                    }
                );
                return {
                    content: [{
                        type: 'text',
                        text: JSON.stringify(result, null, 2)
                    }]
                };
            }
            
            default:
                throw new Error(`Unknown tool: ${name}`);
        }
    } catch (error) {
        return {
            content: [{
                type: 'text',
                text: JSON.stringify({
                    status: 'error',
                    error: error.message || String(error)
                }, null, 2)
            }],
            isError: true
        };
    }
});

/**
 * Cleanup on exit
 */
async function cleanup() {
    if (browserHarness) {
        await browserHarness.close();
        browserHarness = null;
    }
}

process.on('SIGINT', async () => {
    await cleanup();
    process.exit(0);
});

process.on('SIGTERM', async () => {
    await cleanup();
    process.exit(0);
});

/**
 * Start the server
 */
async function main() {
    const transport = new StdioServerTransport();
    await server.connect(transport);
    console.error('Noisemaker Shader Tools MCP server running on stdio');
}

main().catch((error) => {
    console.error('Fatal error:', error);
    process.exit(1);
});
