/**
 * Full Integration Module
 * Ties together compiler, expander, resources, and pipeline executor
 */

import { compile } from '../lang/index.js'
import { expand } from './expander.js'
import { allocateResources } from './resources.js'
import { createPipeline } from './pipeline.js'

/**
 * Compile DSL source into an executable graph
 * @param {string} source - DSL source code
 * @param {object} options - Compilation options
 * @returns {object} Compiled graph ready for execution
 */
export function compileGraph(source, options = {}) {
    // Stage 1: Parse and validate DSL
    const compilationResult = compile(source)
    
    if (compilationResult.diagnostics && compilationResult.diagnostics.length > 0) {
        const errors = compilationResult.diagnostics.filter(d => d.severity === 'error')
        if (errors.length > 0) {
            throw {
                code: 'ERR_COMPILATION_FAILED',
                diagnostics: compilationResult.diagnostics
            }
        }
    }
    
    // Stage 2: Expand logical graph into render passes
    const { passes, errors: expandErrors, programs, textureSpecs } = expand(compilationResult)
    
    if (expandErrors && expandErrors.length > 0) {
        throw {
            code: 'ERR_EXPANSION_FAILED',
            errors: expandErrors
        }
    }
    
    // Stage 3: Allocate resources (texture pooling)
    const allocations = allocateResources(passes)
    
    // Stage 4: Build execution graph
    const graph = {
        id: hashSource(source),
        source,
        passes,
        programs,
        allocations,
        textures: extractTextureSpecs(passes, options, textureSpecs),
        compiledAt: Date.now()
    }
    
    return graph
}

/**
 * Create a complete runtime from DSL source
 * @param {string} source - DSL source code
 * @param {object} options - Runtime options { canvas, width, height, preferWebGPU }
 * @returns {Promise<Pipeline>} Initialized pipeline ready to render
 */
export async function createRuntime(source, options = {}) {
    const graph = compileGraph(source, options)
    const pipeline = await createPipeline(graph, options)
    return pipeline
}

/**
 * Extract texture specifications from passes
 * @param {Array} passes - Render passes
 * @param {object} options - Runtime options with width/height
 * @param {object} textureSpecs - Effect-defined texture specs from expander
 */
function extractTextureSpecs(passes, options, textureSpecs = {}) {
    const textures = new Map()
    const defaultWidth = options.width || 800
    const defaultHeight = options.height || 600
    
    for (const pass of passes) {
        // Collect output textures
        if (pass.outputs) {
            for (const texId of Object.values(pass.outputs)) {
                if (texId.startsWith('global_')) continue
                
                if (!textures.has(texId)) {
                    // Use effect-defined specs if available
                    const effectSpec = textureSpecs[texId]
                    if (effectSpec) {
                        const spec = {
                            width: effectSpec.width || defaultWidth,
                            height: effectSpec.height || defaultHeight,
                            format: effectSpec.format || 'rgba16f',
                            // Include copySrc to allow readback for testing/debugging
                            usage: ['render', 'sample', 'copySrc']
                        }
                        // Handle 3D textures
                        if (effectSpec.is3D) {
                            spec.depth = effectSpec.depth || effectSpec.width || 64
                            spec.is3D = true
                            spec.usage = ['storage', 'sample', 'copySrc'] // 3D textures need storage for compute writes
                        }
                        textures.set(texId, spec)
                    } else {
                        textures.set(texId, {
                            width: defaultWidth,
                            height: defaultHeight,
                            format: 'rgba16f',
                            // Include copySrc to allow readback for testing/debugging
                            usage: ['render', 'sample', 'copySrc']
                        })
                    }
                }
            }
        }
    }
    
    return textures
}

/**
 * Simple hash function for source code
 */
function hashSource(source) {
    let hash = 0
    for (let i = 0; i < source.length; i++) {
        const char = source.charCodeAt(i)
        hash = ((hash << 5) - hash) + char
        hash = hash & hash // Convert to 32bit integer
    }
    return hash.toString(36)
}

/**
 * Hot reload support - recompile and swap graph
 * @param {Pipeline} pipeline - Existing pipeline
 * @param {string} newSource - New DSL source
 * @returns {object} New graph (pipeline will update on next frame)
 */
export function recompile(pipeline, newSource) {
    try {
        const newGraph = compileGraph(newSource, {
            width: pipeline.width,
            height: pipeline.height
        })
        
        // Swap graph on pipeline
        pipeline.graph = newGraph
        
        // Recreate global surfaces and textures to reflect new graph requirements
        pipeline.createSurfaces()
        
        // Recreate textures
        pipeline.recreateTextures()
        
        return newGraph
    } catch (error) {
        console.error('Recompilation failed:', error)
        return null
    }
}
