/**
 * Pipeline Executor
 * Orchestrates frame execution using a compiled graph and backend.
 */

import { WebGL2Backend } from './backends/webgl2.js'
import { WebGPUBackend } from './backends/webgpu.js'

export class Pipeline {
    constructor(graph, backend) {
        this.graph = graph
        this.backend = backend
        this.frameIndex = 0
        this.lastTime = 0
        this.surfaces = new Map()
        this.globalUniforms = {}
        this.width = 0
        this.height = 0
        this.frameReadTextures = null
        this.getGlobalZoom = null  // Function to get zoom from effect
    }

    /**
     * Initialize the pipeline
     */
    async init(width, height) {
        await this.backend.init()
        await this.compilePrograms()
        this.resize(width, height)
    }

    /**
     * Compile all shader programs referenced by the graph
     */
    async compilePrograms() {
        if (!this.graph || !this.graph.passes) return

        const compiled = new Set()

        for (const pass of this.graph.passes) {
            if (compiled.has(pass.program)) continue

            const spec = this.resolveProgramSpec(pass)

            if (!spec) {
                throw {
                    code: 'ERR_PROGRAM_SPEC_MISSING',
                    program: pass.program,
                    pass: pass.id
                }
            }
            
            // Include pass type in spec (compute vs render)
            if (pass.type && !spec.type) {
                spec.type = pass.type
            }

            await this.backend.compileProgram(pass.program, spec)
            compiled.add(pass.program)
        }
    }

    /**
     * Resolve the program specification for a pass
     */
    resolveProgramSpec(pass) {
        const programs = this.graph?.programs

        // Check pass-level programSpec first (inline shaders take priority)
        if (pass.programSpec) {
            return pass.programSpec
        }

        if (programs instanceof Map && programs.has(pass.program)) {
            return programs.get(pass.program)
        }

        if (programs && typeof programs === 'object' && programs[pass.program]) {
            return programs[pass.program]
        }

        return null
    }

    /**
     * Resize the pipeline
     */
    resize(width, height) {
        this.width = width
        this.height = height
        
        // Create/recreate global surfaces
        this.createSurfaces()
        
        // Recreate textures with screen-relative dimensions
        this.recreateTextures()
        
        this.backend.resize(width, height)
    }

    /**
     * Create global output surfaces (o0, o1, o2, o3, o4, o5, o6, o7)
     * Also scans the graph for any other required global surfaces (starting with global_)
     */
    createSurfaces() {
        const surfaceNames = new Set(['o0', 'o1', 'o2', 'o3', 'o4', 'o5', 'o6', 'o7'])
        
        // Scan graph for other globals
        if (this.graph && this.graph.passes) {
            for (const pass of this.graph.passes) {
                if (pass.inputs) {
                    for (const texId of Object.values(pass.inputs)) {
                        if (texId.startsWith('global_')) {
                            surfaceNames.add(texId.replace('global_', ''))
                        }
                    }
                }
                if (pass.outputs) {
                    for (const texId of Object.values(pass.outputs)) {
                        if (texId.startsWith('global_')) {
                            surfaceNames.add(texId.replace('global_', ''))
                        }
                    }
                }
            }
        }

        // Get zoom value if available
        const zoom = this.getGlobalZoom ? this.getGlobalZoom() : 1
        const effectiveZoom = (typeof zoom === 'number' && zoom > 0) ? zoom : 1

        for (const name of surfaceNames) {
            // Destroy old surface if exists
            const oldSurface = this.surfaces.get(name)
            if (oldSurface) {
                this.backend.destroyTexture(`global_${name}_read`)
                this.backend.destroyTexture(`global_${name}_write`)
            }
            
            // Calculate scaled dimensions for zoom-sensitive surfaces
            let surfaceWidth = this.width
            let surfaceHeight = this.height
            
            // Apply zoom scaling for CA-specific surfaces
            if (name.includes('ca_state') || name.includes('physarum')) {
                surfaceWidth = Math.max(1, Math.round(this.width / effectiveZoom))
                surfaceHeight = Math.max(1, Math.round(this.height / effectiveZoom))
            }
            
            // Create double-buffered surface
            // Include 'storage' usage for compute shader output
            this.backend.createTexture(`global_${name}_read`, {
                width: surfaceWidth,
                height: surfaceHeight,
                format: 'rgba16f',
                usage: ['render', 'sample', 'copySrc', 'storage']
            })
            
            this.backend.createTexture(`global_${name}_write`, {
                width: surfaceWidth,
                height: surfaceHeight,
                format: 'rgba16f',
                usage: ['render', 'sample', 'copySrc', 'storage']
            })
            
            this.surfaces.set(name, {
                read: `global_${name}_read`,
                write: `global_${name}_write`,
                currentFrame: 0
            })
        }
    }

    /**
     * Recreate textures with new dimensions
     */
    recreateTextures() {
        if (!this.graph || !this.graph.textures) return
        
        for (const [texId, spec] of this.graph.textures.entries()) {
            // Skip global surfaces
            if (texId.startsWith('global_')) continue
            
            // Resolve dimensions
            const width = this.resolveDimension(spec.width, this.width)
            const height = this.resolveDimension(spec.height, this.height)
            
            // Destroy old texture
            this.backend.destroyTexture(texId)
            
            // Create new texture
            this.backend.createTexture(texId, {
                ...spec,
                width,
                height
            })
        }
    }

    /**
     * Resolve dimension spec to actual pixel value
     */
    resolveDimension(spec, screenSize) {
        if (typeof spec === 'number') {
            return Math.max(1, Math.floor(spec))
        }
        
        if (spec === 'screen' || spec === 'auto') {
            return screenSize
        }
        
        if (typeof spec === 'string' && spec.endsWith('%')) {
            const percent = parseFloat(spec)
            return Math.max(1, Math.floor(screenSize * percent / 100))
        }
        
        if (typeof spec === 'object' && spec.scale !== undefined) {
            let computed = Math.floor(screenSize * spec.scale)
            if (spec.clamp) {
                if (spec.clamp.min !== undefined) {
                    computed = Math.max(spec.clamp.min, computed)
                }
                if (spec.clamp.max !== undefined) {
                    computed = Math.min(spec.clamp.max, computed)
                }
            }
            return Math.max(1, computed)
        }
        
        return screenSize
    }

    /**
     * Execute a single frame
     */
    render(time = 0) {
        const deltaTime = this.lastTime > 0 ? time - this.lastTime : 0
        this.lastTime = time
        
        // Update global uniforms
        this.updateGlobalUniforms(time, deltaTime)
        
        // Initialize per-frame surface bindings so within-frame reads see fresh writes
        this.frameReadTextures = new Map()
        for (const [name, surface] of this.surfaces.entries()) {
            this.frameReadTextures.set(name, surface.read)
        }

        // Begin frame
        this.backend.beginFrame(this.getFrameState())
        
        // Execute passes
        if (this.graph && this.graph.passes) {
            for (const pass of this.graph.passes) {
                // Check pass conditions
                if (this.shouldSkipPass(pass)) {
                    continue
                }
                
                // Execute pass
                const state = this.getFrameState()
                this.backend.executePass(pass, state)
                this.updateFrameSurfaceBindings(pass, state)
            }
        }
        
        // End frame
        this.backend.endFrame()
        
        // Present o0 to screen
        const o0 = this.surfaces.get('o0')
        if (o0 && this.backend.present) {
            this.backend.present(o0.write)
        }
        
        // Swap double buffers
        this.swapBuffers()
        
        // Clear per-frame bindings
        this.frameReadTextures = null

        this.frameIndex++
    }

    /**
     * Update global uniforms (time, resolution, etc.)
     */
    updateGlobalUniforms(time, deltaTime) {
        const aspectValue = this.width / this.height
        this.globalUniforms = {
            time: time,
            deltaTime: deltaTime,
            frame: this.frameIndex,
            resolution: [this.width, this.height],
            aspect: aspectValue,
            aspectRatio: aspectValue, // Alias for shaders expecting this name
            // Add more global uniforms as needed
        }
    }

    /**
     * Check if a pass should be skipped based on conditions
     */
    shouldSkipPass(pass) {
        if (!pass.conditions) return false
        
        const { skipIf, runIf } = pass.conditions
        
        // Check skipIf conditions - skip if ANY condition matches
        if (skipIf) {
            for (const condition of skipIf) {
                const value = this.globalUniforms[condition.uniform] ?? pass.uniforms?.[condition.uniform]
                if (value === condition.equals) {
                    return true
                }
            }
        }
        
        // Check runIf conditions - skip if ANY condition doesn't match
        if (runIf) {
            let shouldRun = true
            for (const condition of runIf) {
                const value = this.globalUniforms[condition.uniform] ?? pass.uniforms?.[condition.uniform]
                if (value !== condition.equals) {
                    shouldRun = false
                    break
                }
            }
            if (!shouldRun) {
                return true
            }
        }
        
        return false
    }

    /**
     * Swap double-buffered surfaces
     */
    swapBuffers() {
        for (const [_, surface] of this.surfaces.entries()) {
            surface.currentFrame = this.frameIndex
            
            // Swap read/write pointers
            const temp = surface.read
            surface.read = surface.write
            surface.write = temp
        }
    }

    /**
     * Get current frame state
     */
    getFrameState() {
        // Build surfaces map with current read textures
        const surfaceMap = {}
        const writeSurfaceMap = {}
        
        for (const [name, surface] of this.surfaces.entries()) {
            const readTextureId = this.frameReadTextures?.get(name) ?? surface.read
            const tex = this.backend.textures.get(readTextureId)
            if (tex) {
                surfaceMap[name] = tex
            }
            writeSurfaceMap[name] = surface.write
        }
        
        const _o0 = this.surfaces.get('o0')
        
        return {
            frameIndex: this.frameIndex,
            time: this.lastTime,
            globalUniforms: this.globalUniforms,
            surfaces: surfaceMap,
            writeSurfaces: writeSurfaceMap,
            graph: this.graph,
            screenWidth: this.width,
            screenHeight: this.height
        }
    }

    /**
     * Get the output texture for a surface
     */
    getOutput(surfaceName = 'o0') {
        const surface = this.surfaces.get(surfaceName)
        if (!surface) return null
        
        return this.backend.textures.get(surface.read)
    }

    /**
     * Update frame-local surface bindings after a pass writes to a global surface.
     */
    updateFrameSurfaceBindings(pass, state) {
        if (!pass.outputs) return
        if (!this.frameReadTextures) return

        for (const outputName of Object.values(pass.outputs)) {
            if (typeof outputName !== 'string') continue
            if (!outputName.startsWith('global_')) continue

            const surfaceName = outputName.replace('global_', '')
            const writeId = state.writeSurfaces?.[surfaceName]
            if (!writeId) continue

            // Subsequent passes in this frame should sample the freshly written texture
            this.frameReadTextures.set(surfaceName, writeId)
        }
    }
}

/**
 * Create a pipeline with the appropriate backend
 */
export async function createPipeline(graph, options = {}) {
    let backend
    
    // Determine backend
    if (options.preferWebGPU && await WebGPUBackend.isAvailable()) {
        const adapter = await navigator.gpu.requestAdapter()
        const device = await adapter.requestDevice()
        let context = null
        if (options.canvas) {
            context = options.canvas.getContext('webgpu')
            if (context) {
                context.configure({
                    device: device,
                    format: navigator.gpu.getPreferredCanvasFormat(),
                    usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.COPY_DST
                })
            }
        }
        backend = new WebGPUBackend(device, context)
    } else if (options.canvas) {
        const gl = options.canvas.getContext('webgl2')
        if (!gl) {
            throw new Error('WebGL2 not available')
        }
        backend = new WebGL2Backend(gl)
    } else {
        throw new Error('No backend available or canvas not provided')
    }
    
    const pipeline = new Pipeline(graph, backend)
    await pipeline.init(options.width || 800, options.height || 600)
    
    return pipeline
}
