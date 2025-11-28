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
        this.surfaces = new Map()        // Global surfaces (o0-o7)
        this.feedbackSurfaces = new Map() // Feedback surfaces (f0-f3)
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

            await this.backend.compileProgram(pass.program, spec)
            compiled.add(pass.program)
        }
    }

    /**
     * Resolve the program specification for a pass
     */
    resolveProgramSpec(pass) {
        const programs = this.graph?.programs

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
    /**
     * Check if a texture ID is a global surface reference and extract the name.
     * Supports both "global_name" and "globalName" patterns.
     * Returns null if not a global, otherwise returns the surface name.
     */
    parseGlobalName(texId) {
        if (typeof texId !== 'string') return null
        
        // Pattern 1: "global_name" (underscore separator)
        if (texId.startsWith('global_')) {
            return texId.replace('global_', '')
        }
        
        // Pattern 2: "globalName" (camelCase)
        if (texId.startsWith('global') && texId.length > 6) {
            const suffix = texId.slice(6)
            // Check it's actually camelCase (next char is uppercase or digit)
            if (/^[A-Z0-9]/.test(suffix)) {
                // Convert to surface name: "CaState" → "caState"
                return suffix.charAt(0).toLowerCase() + suffix.slice(1)
            }
        }
        
        return null
    }

    /**
     * Check if a texture ID is a feedback surface reference and extract the name.
     * Supports "feedback_name" pattern (e.g., "feedback_f0").
     * Returns null if not a feedback surface, otherwise returns the surface name.
     */
    parseFeedbackName(texId) {
        if (typeof texId !== 'string') return null
        
        if (texId.startsWith('feedback_')) {
            return texId.replace('feedback_', '')
        }
        
        return null
    }

    createSurfaces() {
        const surfaceNames = new Set(['o0', 'o1', 'o2', 'o3', 'o4', 'o5', 'o6', 'o7'])
        const feedbackNames = new Set(['f0', 'f1', 'f2', 'f3'])
        
        // Scan graph for other globals and feedbacks
        if (this.graph && this.graph.passes) {
            for (const pass of this.graph.passes) {
                if (pass.inputs) {
                    for (const texId of Object.values(pass.inputs)) {
                        const globalName = this.parseGlobalName(texId)
                        if (globalName) {
                            surfaceNames.add(globalName)
                        }
                        const feedbackName = this.parseFeedbackName(texId)
                        if (feedbackName) {
                            feedbackNames.add(feedbackName)
                        }
                    }
                }
                if (pass.outputs) {
                    for (const texId of Object.values(pass.outputs)) {
                        const globalName = this.parseGlobalName(texId)
                        if (globalName) {
                            surfaceNames.add(globalName)
                        }
                        const feedbackName = this.parseFeedbackName(texId)
                        if (feedbackName) {
                            feedbackNames.add(feedbackName)
                        }
                    }
                }
            }
        }

        // Get zoom value if available
        const zoom = this.getGlobalZoom ? this.getGlobalZoom() : 1
        const effectiveZoom = (typeof zoom === 'number' && zoom > 0) ? zoom : 1

        // Create global surfaces (o0-o7 and dynamic globals)
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
            let surfaceFormat = 'rgba16f'
            
            // Check if there's a texture spec for this surface in graph.textures
            // This handles effect-defined textures that need ping-pong buffering
            const globalTexId = `global_${name}`
            const texSpec = this.graph?.textures?.get?.(globalTexId)
            if (texSpec) {
                surfaceWidth = this.resolveDimension(texSpec.width, this.width)
                surfaceHeight = this.resolveDimension(texSpec.height, this.height)
                if (texSpec.format) surfaceFormat = texSpec.format
            } else {
                // Apply zoom scaling for CA-specific surfaces
                // Match both "ca_state"/"physarum" and "caState"/"physarumState" patterns
                const lowerName = name.toLowerCase()
                if (lowerName.includes('ca') || lowerName.includes('physarum') || lowerName.includes('reaction')) {
                    surfaceWidth = Math.max(1, Math.round(this.width / effectiveZoom))
                    surfaceHeight = Math.max(1, Math.round(this.height / effectiveZoom))
                }
            }
            
            // Create double-buffered surface
            // Include 'storage' usage for compute shader output
            this.backend.createTexture(`global_${name}_read`, {
                width: surfaceWidth,
                height: surfaceHeight,
                format: surfaceFormat,
                usage: ['render', 'sample', 'copySrc', 'storage']
            })
            
            this.backend.createTexture(`global_${name}_write`, {
                width: surfaceWidth,
                height: surfaceHeight,
                format: surfaceFormat,
                usage: ['render', 'sample', 'copySrc', 'storage']
            })
            
            this.surfaces.set(name, {
                read: `global_${name}_read`,
                write: `global_${name}_write`,
                currentFrame: 0
            })
        }

        // Create feedback surfaces (f0-f3)
        // Feedback surfaces use ping-pong blitting: reads always get previous frame,
        // writes go to a separate buffer that is blitted to read buffer at frame end
        for (const name of feedbackNames) {
            // Destroy old surface if exists
            const oldSurface = this.feedbackSurfaces.get(name)
            if (oldSurface) {
                this.backend.destroyTexture(`feedback_${name}_read`)
                this.backend.destroyTexture(`feedback_${name}_write`)
            }
            
            // Feedback surfaces are screen-sized rgba16f
            const surfaceWidth = this.width
            const surfaceHeight = this.height
            const surfaceFormat = 'rgba16f'
            
            // Create double-buffered feedback surface
            this.backend.createTexture(`feedback_${name}_read`, {
                width: surfaceWidth,
                height: surfaceHeight,
                format: surfaceFormat,
                usage: ['render', 'sample', 'copySrc', 'copyDst', 'storage']
            })
            
            this.backend.createTexture(`feedback_${name}_write`, {
                width: surfaceWidth,
                height: surfaceHeight,
                format: surfaceFormat,
                usage: ['render', 'sample', 'copySrc', 'copyDst', 'storage']
            })
            
            this.feedbackSurfaces.set(name, {
                read: `feedback_${name}_read`,
                write: `feedback_${name}_write`,
                currentFrame: 0,
                dirty: false  // Track if written to this frame
            })
        }
    }

    /**
     * Mark a feedback surface as dirty (for testing and manual control).
     * @param {string} name - Feedback surface name (e.g., 'f0')
     */
    markFeedbackDirty(name) {
        const surface = this.feedbackSurfaces.get(name)
        if (surface) {
            surface.dirty = true
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
        
        // Note: feedback surfaces always read from previous frame (no frameReadTextures update)
        // We do NOT reset dirty flags here - they're set during pass execution
        // and cleared after blitFeedbackSurfaces at frame end

        // Begin frame
        this.backend.beginFrame(this.getFrameState())
        
        // Execute passes
        if (this.graph && this.graph.passes) {
            for (const pass of this.graph.passes) {
                // Check pass conditions
                if (this.shouldSkipPass(pass)) {
                    continue
                }
                
                // Determine iteration count (repeat N times per frame)
                const repeatCount = this.resolveRepeatCount(pass)
                
                for (let iter = 0; iter < repeatCount; iter++) {
                    // Execute pass
                    const state = this.getFrameState()
                    this.backend.executePass(pass, state)
                    this.updateFrameSurfaceBindings(pass, state)
                    
                    // Swap global surface read/write pointers for ping-pong between iterations
                    if (repeatCount > 1) {
                        this.swapIterationBuffers(pass)
                    }
                }
            }
        }
        
        // End frame
        this.backend.endFrame()
        
        // Blit feedback surface writes to reads (ping-pong)
        // This preserves the written content for next frame's reads
        this.blitFeedbackSurfaces()
        
        // Present o0 to screen
        const o0 = this.surfaces.get('o0')
        if (o0 && this.backend.present) {
            this.backend.present(o0.write)
        }
        
        // Swap double buffers for global surfaces
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
     * Resolve the repeat count for a pass.
     * Supports static values or uniform-driven iteration counts.
     * @param {Object} pass - The pass definition
     * @returns {number} - Number of times to execute the pass
     */
    resolveRepeatCount(pass) {
        if (!pass.repeat) return 1
        
        // If repeat is a number, use it directly
        if (typeof pass.repeat === 'number') {
            return Math.max(1, Math.floor(pass.repeat))
        }
        
        // If repeat is a string, treat it as a uniform name
        if (typeof pass.repeat === 'string') {
            const value = this.globalUniforms[pass.repeat] ?? pass.uniforms?.[pass.repeat]
            if (typeof value === 'number') {
                return Math.max(1, Math.floor(value))
            }
        }
        
        return 1
    }

    /**
     * Swap read/write pointers for global surfaces written by a pass.
     * Used for ping-pong between iterations of a repeated pass.
     * @param {Object} pass - The pass that just executed
     */
    swapIterationBuffers(pass) {
        if (!pass.outputs) return

        for (const outputName of Object.values(pass.outputs)) {
            if (typeof outputName !== 'string') continue
            
            // Only swap global surfaces (not feedback surfaces)
            const globalName = this.parseGlobalName(outputName)
            if (!globalName) continue
            
            const surface = this.surfaces.get(globalName)
            if (!surface) continue
            
            // Swap read/write pointers
            const temp = surface.read
            surface.read = surface.write
            surface.write = temp
            
            // Update frameReadTextures to match
            if (this.frameReadTextures) {
                this.frameReadTextures.set(globalName, surface.read)
            }
        }
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
        
        // Build feedback surfaces map
        // Reads always come from 'read' buffer (previous frame's content)
        // Writes go to 'write' buffer
        const feedbackSurfaceMap = {}
        const writeFeedbackMap = {}
        
        for (const [name, surface] of this.feedbackSurfaces.entries()) {
            const tex = this.backend.textures.get(surface.read)
            if (tex) {
                feedbackSurfaceMap[name] = tex
            }
            writeFeedbackMap[name] = surface.write
        }
        
        const _o0 = this.surfaces.get('o0')
        
        return {
            frameIndex: this.frameIndex,
            time: this.lastTime,
            globalUniforms: this.globalUniforms,
            surfaces: surfaceMap,
            writeSurfaces: writeSurfaceMap,
            feedbackSurfaces: feedbackSurfaceMap,
            writeFeedbackSurfaces: writeFeedbackMap,
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
     * For feedback surfaces, mark them as dirty (but don't update frameReadTextures).
     */
    updateFrameSurfaceBindings(pass, state) {
        if (!pass.outputs) return

        for (const outputName of Object.values(pass.outputs)) {
            if (typeof outputName !== 'string') continue
            
            // Handle global surface writes
            if (outputName.startsWith('global_')) {
                if (!this.frameReadTextures) continue
                
                const surfaceName = outputName.replace('global_', '')
                const writeId = state.writeSurfaces?.[surfaceName]
                if (!writeId) continue

                // Subsequent passes in this frame should sample the freshly written texture
                this.frameReadTextures.set(surfaceName, writeId)
            }
            
            // Handle feedback surface writes
            if (outputName.startsWith('feedback_')) {
                const feedbackName = outputName.replace('feedback_', '')
                const surface = this.feedbackSurfaces.get(feedbackName)
                if (surface) {
                    surface.dirty = true
                }
                // Note: We do NOT update frameReadTextures for feedback surfaces
                // Reads always come from previous frame's content
            }
        }
    }

    /**
     * Blit feedback surfaces from write buffer to read buffer.
     * This is called at the end of each frame to persist written content
     * for the next frame's reads.
     */
    blitFeedbackSurfaces() {
        for (const [_name, surface] of this.feedbackSurfaces.entries()) {
            if (!surface.dirty) continue
            
            // Blit write → read using the backend's copy capability
            this.backend.copyTexture(surface.write, surface.read)
            surface.dirty = false
        }
    }

    /**
     * Dispose of all pipeline resources
     */
    dispose() {
        // Destroy all global surfaces
        for (const [name] of this.surfaces) {
            this.backend.destroyTexture(`global_${name}_read`)
            this.backend.destroyTexture(`global_${name}_write`)
        }
        this.surfaces.clear()
        
        // Destroy all feedback surfaces
        for (const [name] of this.feedbackSurfaces) {
            this.backend.destroyTexture(`feedback_${name}_read`)
            this.backend.destroyTexture(`feedback_${name}_write`)
        }
        this.feedbackSurfaces.clear()

        // Destroy all graph textures
        if (this.graph && this.graph.textures) {
            for (const texId of this.graph.textures.keys()) {
                if (!texId.startsWith('global_') && !texId.startsWith('feedback_')) {
                    this.backend.destroyTexture(texId)
                }
            }
        }

        // Destroy backend resources
        if (this.backend && typeof this.backend.destroy === 'function') {
            this.backend.destroy({ skipTextures: true })
        }

        // Clear references
        this.graph = null
        this.frameReadTextures = null
        this.globalUniforms = {}
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
