import { getEffect } from './registry.js';
import { stdEnums } from '../lang/std_enums.js';

/**
 * Expands the Logical Graph (plans) into a Render Graph (passes).
 * @param {object} compilationResult { plans, diagnostics }
 * @returns {object} { passes, errors, programs, textureSpecs }
 */
export function expand(compilationResult) {
    const passes = [];
    const errors = [];
    const programs = {};
    const textureSpecs = {}; // nodeId_texName -> { width, height, format }
    const textureMap = new Map(); // logical_id -> virtual_texture_id

    // Helper to resolve enum paths
    const resolveEnum = (path) => {
        const parts = path.split('.');
        let node = stdEnums;
        for (const part of parts) {
            if (node && node[part]) {
                node = node[part];
            } else {
                return null;
            }
        }
        return node && node.value !== undefined ? node.value : null;
    };

    // 1. Expand each plan into passes
    for (const plan of compilationResult.plans) {
        // Each plan is a chain of effects
        // We need to track the "current" output texture as we traverse the chain
        let currentInput = null;

        for (const step of plan.chain) {
            const effectName = step.op;
            const effectDef = getEffect(effectName);

            if (!effectDef) {
                errors.push({ message: `Effect '${effectName}' not found`, step });
                continue;
            }

            // Collect programs
            if (effectDef.shaders) {
                for (const [progName, shaders] of Object.entries(effectDef.shaders)) {
                    if (!programs[progName]) {
                        programs[progName] = {
                            ...shaders
                        };
                    }
                }
            }

            // Generate a unique ID for this effect instance
            const nodeId = `node_${step.temp}`;

            // Collect texture specs from effect definition
            if (effectDef.textures) {
                for (const [texName, spec] of Object.entries(effectDef.textures)) {
                    const virtualTexId = `${nodeId}_${texName}`;
                    textureSpecs[virtualTexId] = { ...spec };
                }
            }

            // Resolve inputs
            // If step.from is null, it's a generator (no input).
            // If step.from is a number, it refers to a previous temp output.
            if (step.from !== null) {
                // Find the output texture of the previous node
                const prevNodeId = `node_${step.from}`;
                // The output of the previous node is usually its 'outputColor'
                // We need to track what the "main" output of a node is.
                // For now, assume 'outputColor' is the main output.
                currentInput = textureMap.get(`${prevNodeId}_out`);
            }

            // Expand passes
            const effectPasses = effectDef.passes || [];
            for (let i = 0; i < effectPasses.length; i++) {
                const passDef = effectPasses[i];
                const passId = `${nodeId}_pass_${i}`;
                
                const pass = {
                    id: passId,
                    program: passDef.program,
                    programSpec: passDef.programSpec,
                    type: passDef.type || 'render',
                    drawMode: passDef.drawMode,
                    count: passDef.count,
                    blend: passDef.blend,
                    workgroups: passDef.workgroups,
                    storageBuffers: passDef.storageBuffers,
                    storageTextures: passDef.storageTextures,
                    inputs: {},
                    outputs: {},
                    uniforms: {}
                };

                // Attach metadata so downstream consumers can map passes back to their effect definitions
                pass.effectKey = effectName;
                pass.effectFunc = effectDef.func || effectName;
                pass.effectNamespace = effectDef.namespace || null;
                pass.nodeId = nodeId;

                // Initialize uniforms with defaults
                if (effectDef.globals) {
                    for (const [_key, def] of Object.entries(effectDef.globals)) {
                        if (def.uniform && def.default !== undefined) {
                            let val = def.default;
                            if (def.type === 'member' && typeof val === 'string') {
                                const resolved = resolveEnum(val);
                                if (resolved !== null) val = resolved;
                            }
                            pass.uniforms[def.uniform] = val;
                        }
                    }
                }

                // Map Uniforms
                if (step.args) {
                    for (const [argName, arg] of Object.entries(step.args)) {
                        const isObjectArg = arg !== null && typeof arg === 'object';

                        // Skip texture arguments (handled in inputs)
                        if (isObjectArg && (arg.kind === 'temp' || arg.kind === 'output' || arg.kind === 'source')) {
                            continue;
                        }
                        
                        // Resolve uniform name from globals
                        let uniformName = argName;
                        if (effectDef.globals && effectDef.globals[argName] && effectDef.globals[argName].uniform) {
                            uniformName = effectDef.globals[argName].uniform;
                        }
                        
                        // Extract value
                        if (isObjectArg && arg.value !== undefined) {
                            pass.uniforms[uniformName] = arg.value;
                        } else {
                            pass.uniforms[uniformName] = arg;
                        }
                    }
                }

                // Map Inputs
                if (passDef.inputs) {
                    for (const [uniformName, texRef] of Object.entries(passDef.inputs)) {
                        // Handle standard and legacy pipeline inputs
                        const isPipelineInput = 
                            texRef === 'inputTex' ||
                            texRef === 'inputColor' || 
                            texRef === 'src' ||
                            (texRef.startsWith('o') && !isNaN(parseInt(texRef.slice(1))));

                        if (isPipelineInput) {
                            pass.inputs[uniformName] = currentInput || texRef;
                        } else if (texRef === 'noise') {
                            pass.inputs[uniformName] = 'global_noise';
                        } else if (texRef === 'feedback') {
                            // Handle feedback texture
                            // If we are writing to a global surface, read from it
                            // For now, assume we are writing to o0 if not specified
                            // TODO: This should be smarter and look at the plan.out
                            pass.inputs[uniformName] = 'global_o0';
                        } else if (step.args && Object.prototype.hasOwnProperty.call(step.args, texRef)) {
                            // Reference to an argument (e.g. blend(tex: ...))
                            const arg = step.args[texRef];

                            // Null/undefined arguments indicate intentionally unbound inputs
                            if (arg == null) {
                                continue;
                            }

                            if (arg.kind === 'temp') {
                                pass.inputs[uniformName] = textureMap.get(`node_${arg.index}_out`);
                            } else if (arg.kind === 'output') {
                                pass.inputs[uniformName] = `global_${arg.name}`; // e.g. global_o0
                            } else if (arg.kind === 'source') {
                                pass.inputs[uniformName] = `global_${arg.name}`; // e.g. global_o0
                            } else if (typeof arg === 'string') {
                                // Allow direct string bindings to legacy texture ids
                                if (arg.startsWith('global_')) {
                                    pass.inputs[uniformName] = arg;
                                } else if (/^o[0-7]$/.test(arg)) {
                                    pass.inputs[uniformName] = `global_${arg}`;
                                } else {
                                    pass.inputs[uniformName] = arg;
                                }
                            }
                        } else if (effectDef.globals && effectDef.globals[texRef] && effectDef.globals[texRef].default !== undefined) {
                            // Parameter with default value - resolve the default
                            const defaultVal = effectDef.globals[texRef].default;
                            if (defaultVal === 'inputTex' || defaultVal === 'inputColor' || defaultVal === 'src') {
                                pass.inputs[uniformName] = currentInput || defaultVal;
                            } else if (/^o[0-7]$/.test(defaultVal)) {
                                pass.inputs[uniformName] = `global_${defaultVal}`;
                            } else if (defaultVal.startsWith('global_')) {
                                pass.inputs[uniformName] = defaultVal;
                            } else {
                                pass.inputs[uniformName] = defaultVal;
                            }
                        } else if (texRef.startsWith('global_')) {
                            // Explicit global reference
                            pass.inputs[uniformName] = texRef;
                        } else {
                            // Internal texture or explicit reference
                            pass.inputs[uniformName] = `${nodeId}_${texRef}`;
                        }
                    }
                }

                // Map Outputs
                if (passDef.outputs) {
                    for (const [attachment, texRef] of Object.entries(passDef.outputs)) {
                        let virtualTex;
                        if (texRef === 'outputColor') {
                            // This is the main output of this node
                            // OPTIMIZATION: If this is the last step and last pass, write directly to global output
                            const isLastStep = step === plan.chain[plan.chain.length - 1];
                            const isLastPass = i === effectPasses.length - 1;
                            
                            if (isLastStep && isLastPass && plan.out) {
                                const outName = typeof plan.out === 'object' ? plan.out.name : plan.out;
                                virtualTex = `global_${outName}`;
                            } else {
                                virtualTex = `${nodeId}_out`;
                            }
                            textureMap.set(virtualTex, virtualTex); // Register
                        } else if (texRef.startsWith('global_')) {
                            virtualTex = texRef;
                        } else {
                            virtualTex = `${nodeId}_${texRef}`;
                        }
                        pass.outputs[attachment] = virtualTex;
                    }
                }

                passes.push(pass);
            }
            
            // Update currentInput for the next step in the chain
            currentInput = textureMap.get(`${nodeId}_out`);
        }

        // Handle the final output of the chain (.out(o0))
        if (plan.out && currentInput) {
            const outName = typeof plan.out === 'object' ? plan.out.name : plan.out;
            const targetGlobal = `global_${outName}`;

            // Only add blit if the current input is not already the target global
            if (currentInput !== targetGlobal) {
                const blitPass = {
                    id: `final_blit_${outName}`,
                    program: 'blit',
                    type: 'render',
                    inputs: { src: currentInput },
                    outputs: { color: targetGlobal },
                    uniforms: {}
                };
                passes.push(blitPass);

                if (!programs['blit']) {
                programs['blit'] = {
                    fragment: `#version 300 es
                        precision highp float;
                        in vec2 v_texCoord;
                        uniform sampler2D src;
                        out vec4 fragColor;
                        void main() {
                            fragColor = texture(src, v_texCoord);
                        }`,
                    wgsl: `
                        struct FragmentInput {
                            @builtin(position) position: vec4<f32>,
                            @location(0) uv: vec2<f32>,
                        }

                        @group(0) @binding(0) var src: texture_2d<f32>;
                        @group(0) @binding(1) var srcSampler: sampler;

                        @fragment
                        fn main(in: FragmentInput) -> @location(0) vec4<f32> {
                            return textureSample(src, srcSampler, in.uv);
                        }
                    `,
                    fragmentEntryPoint: 'main'
                };
            }
            }
        }
    }

    return { passes, errors, programs, textureSpecs };
}
