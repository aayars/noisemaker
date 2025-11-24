/**
 * WebGPU Backend Implementation
 * 
 * Implements the Noisemaker Rendering Pipeline specification for WebGPU.
 * Handles render and compute passes, texture management, and uniform buffers.
 */

import { Backend } from '../backend.js'
import {
    DEFAULT_FRAGMENT_ENTRY_POINT,
    DEFAULT_VERTEX_ENTRY_POINT,
    DEFAULT_VERTEX_SHADER_WGSL
} from '../default-shaders.js'

/**
 * Convert a float16 value (stored as uint16) to float32
 */
function float16ToFloat32(h) {
    const sign = (h >> 15) & 0x1
    const exponent = (h >> 10) & 0x1f
    const mantissa = h & 0x3ff
    
    if (exponent === 0) {
        // Denormalized number or zero
        if (mantissa === 0) {
            return sign ? -0 : 0
        }
        // Denormalized
        const f = mantissa / 1024
        return (sign ? -1 : 1) * f * Math.pow(2, -14)
    } else if (exponent === 31) {
        // Infinity or NaN
        if (mantissa === 0) {
            return sign ? -Infinity : Infinity
        }
        return NaN
    }
    
    // Normalized number
    const f = 1 + mantissa / 1024
    return (sign ? -1 : 1) * f * Math.pow(2, exponent - 15)
}

/**
 * Standard uniform struct that all shaders can expect.
 * Packed according to std140/WGSL alignment rules for uniform buffers.
 */
const UNIFORM_BUFFER_INITIAL_SIZE = 256

export class WebGPUBackend extends Backend {
    constructor(device, context) {
        super(device)
        this.device = device
        this.context = context
        this.queue = device.queue
        this.pipelines = new Map() // programId -> render or compute pipeline
        this.bindGroups = new Map() // passId -> bind group
        this.samplers = new Map() // config -> sampler
        this.commandEncoder = null
        this.defaultVertexModule = null
        this.canvasFormat = (typeof navigator !== 'undefined' && navigator.gpu?.getPreferredCanvasFormat)
            ? navigator.gpu.getPreferredCanvasFormat()
            : null
        
        // Uniform buffer pool for efficient buffer reuse
        this.uniformBufferPool = []
        this.activeUniformBuffers = []
    }

    async init() {
        // Create default sampler (linear filtering)
        this.samplers.set('default', this.device.createSampler({
            minFilter: 'linear',
            magFilter: 'linear',
            addressModeU: 'clamp-to-edge',
            addressModeV: 'clamp-to-edge'
        }))
        
        // Create nearest sampler for pixel-perfect sampling
        this.samplers.set('nearest', this.device.createSampler({
            minFilter: 'nearest',
            magFilter: 'nearest',
            addressModeU: 'clamp-to-edge',
            addressModeV: 'clamp-to-edge'
        }))
        
        // Create repeat sampler for tiling textures
        this.samplers.set('repeat', this.device.createSampler({
            minFilter: 'linear',
            magFilter: 'linear',
            addressModeU: 'repeat',
            addressModeV: 'repeat'
        }))
        
        return Promise.resolve()
    }

    createTexture(id, spec) {
        const format = this.resolveFormat(spec.format)
        const usage = this.resolveUsage(spec.usage || ['render', 'sample'])
        
        const texture = this.device.createTexture({
            size: {
                width: spec.width,
                height: spec.height,
                depthOrArrayLayers: 1
            },
            format,
            usage
        })
        
        const view = texture.createView()
        
        this.textures.set(id, {
            handle: texture,
            view,
            width: spec.width,
            height: spec.height,
            format: spec.format,
            gpuFormat: format
        })
        
        return texture
    }

    destroyTexture(id) {
        const tex = this.textures.get(id)
        if (tex) {
            tex.handle.destroy()
            this.textures.delete(id)
        }
    }

    /**
     * Resolve the WGSL shader source from a program spec.
     * Looks for sources in order: wgsl, source, fragment (for render shaders)
     */
    resolveWGSLSource(spec) {
        // Prefer explicit WGSL source
        if (spec.wgsl) return spec.wgsl
        
        // Fall back to generic source field
        if (spec.source) return spec.source
        
        // For fragment shaders, might be under 'fragment' key
        if (spec.fragment && !spec.fragment.includes('#version')) {
            return spec.fragment
        }
        
        return null
    }

    async compileProgram(id, spec) {
        const source = this.resolveWGSLSource(spec)
        
        if (!source) {
            throw {
                code: 'ERR_NO_WGSL_SOURCE',
                detail: `No WGSL shader source found for program '${id}'. Available keys: ${Object.keys(spec).join(', ')}`,
                program: id
            }
        }
        
        // Inject defines
        const processedSource = this.injectDefines(source, spec.defines || {})
        
        if (spec.type === 'compute') {
            return this.compileComputeProgram(id, processedSource, spec)
        }
        
        return this.compileRenderProgram(id, processedSource, spec)
    }

    async compileComputeProgram(id, source, spec) {
        const module = this.device.createShaderModule({ code: source })
        const compilationInfo = await module.getCompilationInfo()
        const errors = compilationInfo.messages.filter(m => m.type === 'error')

        if (errors.length > 0) {
            throw {
                code: 'ERR_SHADER_COMPILE',
                detail: errors.map(e => `Line ${e.lineNum}: ${e.message}`).join('\n'),
                program: id
            }
        }

        const pipeline = this.device.createComputePipeline({
            layout: 'auto',
            compute: {
                module,
                entryPoint: spec.computeEntryPoint || 'cs_main'
            }
        })

        const programInfo = {
            module,
            pipeline,
            type: 'compute',
            entryPoint: spec.computeEntryPoint || 'cs_main'
        }

        this.programs.set(id, programInfo)
        return programInfo
    }

    async compileRenderProgram(id, source, spec) {
        // Parse binding declarations from the shader
        const bindings = this.parseShaderBindings(source)
        
        // Compile fragment module
        const fragmentModule = this.device.createShaderModule({ code: source })
        const fragmentInfo = await fragmentModule.getCompilationInfo()
        const fragmentErrors = fragmentInfo.messages.filter(m => m.type === 'error')

        if (fragmentErrors.length > 0) {
            throw {
                code: 'ERR_SHADER_COMPILE',
                detail: fragmentErrors.map(e => `Line ${e.lineNum}: ${e.message}`).join('\n'),
                program: id
            }
        }

        // Handle vertex module
        let vertexModule
        let vertexEntryPoint

        if (spec.vertexWGSL || spec.vertexWgsl) {
            const vertexSource = spec.vertexWGSL || spec.vertexWgsl
            vertexModule = this.device.createShaderModule({ code: vertexSource })
            const vertexInfo = await vertexModule.getCompilationInfo()
            const vertexErrors = vertexInfo.messages.filter(m => m.type === 'error')

            if (vertexErrors.length > 0) {
                throw {
                    code: 'ERR_SHADER_COMPILE',
                    detail: vertexErrors.map(e => `Line ${e.lineNum}: ${e.message}`).join('\n'),
                    program: id
                }
            }

            vertexEntryPoint = spec.vertexEntryPoint || DEFAULT_VERTEX_ENTRY_POINT
        } else {
            vertexModule = this.getDefaultVertexModule()
            vertexEntryPoint = DEFAULT_VERTEX_ENTRY_POINT
        }

        const fragmentEntryPoint = spec.fragmentEntryPoint || spec.entryPoint || DEFAULT_FRAGMENT_ENTRY_POINT
        const outputFormat = this.resolveFormat(spec?.outputFormat || 'rgba16float')

        // Create initial pipeline
        const pipeline = this.device.createRenderPipeline({
            layout: 'auto',
            vertex: {
                module: vertexModule,
                entryPoint: vertexEntryPoint
            },
            fragment: {
                module: fragmentModule,
                entryPoint: fragmentEntryPoint,
                targets: [{
                    format: outputFormat,
                    blend: this.resolveBlendState(spec?.blend)
                }]
            },
            primitive: {
                topology: spec?.topology || 'triangle-list'
            }
        })

        // Create pipeline cache for different output formats/blend modes
        const pipelineCache = new Map()
        const initialKey = this.getPipelineKey({ 
            topology: spec?.topology, 
            blend: spec?.blend, 
            format: outputFormat 
        })
        pipelineCache.set(initialKey, pipeline)

        const programInfo = {
            module: fragmentModule,
            pipeline,
            type: spec.type || 'render',
            vertexModule,
            fragmentModule,
            vertexEntryPoint,
            fragmentEntryPoint,
            outputFormat,
            pipelineCache,
            bindings, // Store parsed bindings for bind group creation
            packedUniformLayout: this.parsePackedUniformLayout(source) // Store packed uniform layout if present
        }

        this.programs.set(id, programInfo)
        return programInfo
    }

    /**
     * Parse WGSL shader to extract packed uniform layout from unpacking statements.
     * Looks for patterns like: varName = uniforms.data[N].xyz;
     * Returns an array of {name, slot, components} sorted by slot then component offset.
     * 
     * @param {string} source - WGSL shader source
     * @returns {Array<{name: string, slot: number, components: string}>|null}
     */
    parsePackedUniformLayout(source) {
        // Check if shader uses packed uniforms struct
        if (!source.includes('uniforms.data[')) {
            return null
        }
        
        const layout = []
        // Match various unpacking patterns:
        // - varName = uniforms.data[N].xyz;
        // - let varName: type = uniforms.data[N].xyz;  
        // - varName = i32(uniforms.data[N].x);
        // - varName = uniforms.data[N].xyz > 0.5; (for booleans)
        // - varName = max(1, i32(uniforms.data[N].w)); (for clamped values)
        // The regex captures the variable name (which may follow 'let' and have a type annotation)
        // IMPORTANT: [^\n=]+ prevents matching across newlines/equals, avoiding greedy struct field capture
        const unpackRegex = /(?:let\s+)?(\w+)(?:\s*:\s*[^\n=]+)?\s*=\s*(?:max\s*\([^,]+,\s*)?(?:i32\s*\(\s*)?uniforms\.data\[(\d+)\]\.([xyzw]+)/g
        
        let match
        while ((match = unpackRegex.exec(source)) !== null) {
            const name = match[1]
            const slot = parseInt(match[2], 10)
            const components = match[3]
            
            layout.push({ name, slot, components })
        }
        
        if (layout.length === 0) {
            return null
        }
        
        // Sort by slot, then by component offset (x=0, y=1, z=2, w=3)
        const componentOrder = { x: 0, y: 1, z: 2, w: 3 }
        layout.sort((a, b) => {
            if (a.slot !== b.slot) return a.slot - b.slot
            return componentOrder[a.components[0]] - componentOrder[b.components[0]]
        })
        
        return layout
    }

    /**
     * Parse WGSL shader source to extract binding declarations.
     * Returns an array of binding info objects sorted by binding index.
     * 
     * @param {string} source - WGSL shader source
     * @returns {Array<{binding: number, group: number, type: string, name: string}>}
     */
    parseShaderBindings(source) {
        const bindings = []
        
        // Match @group(N) @binding(M) var<...> name or @group(N) @binding(M) var name
        // Patterns:
        // @group(0) @binding(0) var<uniform> name: type;
        // @group(0) @binding(0) var name: texture_2d<f32>;
        // @group(0) @binding(0) var name: sampler;
        const bindingRegex = /@group\s*\(\s*(\d+)\s*\)\s*@binding\s*\(\s*(\d+)\s*\)\s*var(?:<([^>]+)>)?\s+(\w+)\s*:\s*([^;]+)/g
        
        let match
        while ((match = bindingRegex.exec(source)) !== null) {
            const group = parseInt(match[1], 10)
            const binding = parseInt(match[2], 10)
            const storage = match[3] || '' // e.g., 'uniform', 'storage, read_write'
            const name = match[4]
            const typeDecl = match[5].trim()
            
            // Determine binding type
            let bindingType = 'unknown'
            if (typeDecl.includes('texture_2d') || typeDecl.includes('texture_storage_2d')) {
                bindingType = 'texture'
            } else if (typeDecl === 'sampler') {
                bindingType = 'sampler'
            } else if (storage.includes('uniform')) {
                bindingType = 'uniform'
            } else if (storage.includes('storage')) {
                bindingType = 'storage'
            }
            
            bindings.push({
                group,
                binding,
                type: bindingType,
                name,
                storage,
                typeDecl
            })
        }
        
        // Sort by group then binding
        bindings.sort((a, b) => {
            if (a.group !== b.group) return a.group - b.group
            return a.binding - b.binding
        })
        
        return bindings
    }

    getDefaultVertexModule() {
        if (!this.defaultVertexModule) {
            this.defaultVertexModule = this.device.createShaderModule({
                code: DEFAULT_VERTEX_SHADER_WGSL
            })
        }
        return this.defaultVertexModule
    }

    injectDefines(source, defines) {
        if (!defines || Object.keys(defines).length === 0) {
            return source
        }
        
        let injected = ''
        
        for (const [key, value] of Object.entries(defines)) {
            // WGSL uses const declarations instead of #define
            if (typeof value === 'boolean') {
                injected += `const ${key}: bool = ${value};\n`
            } else if (typeof value === 'number') {
                if (Number.isInteger(value)) {
                    injected += `const ${key}: i32 = ${value};\n`
                } else {
                    injected += `const ${key}: f32 = ${value};\n`
                }
            } else {
                injected += `const ${key} = ${value};\n`
            }
        }
        
        return injected + source
    }

    executePass(pass, state) {
        const program = this.programs.get(pass.program)
        
        if (!program) {
            throw {
                code: 'ERR_PROGRAM_NOT_FOUND',
                pass: pass.id,
                program: pass.program
            }
        }
        
        if (program.type === 'compute') {
            this.executeComputePass(pass, program, state)
        } else {
            this.executeRenderPass(pass, program, state)
        }
    }

    executeRenderPass(pass, program, state) {
        // Resolve output texture
        let outputId = pass.outputs.color || Object.values(pass.outputs)[0]
        const originalOutputId = outputId

        if (outputId.startsWith('global_')) {
            const surfaceName = outputId.replace('global_', '')
            if (state.writeSurfaces && state.writeSurfaces[surfaceName]) {
                outputId = state.writeSurfaces[surfaceName]
            }
        }

        let outputTex = this.textures.get(outputId) || state.surfaces?.[outputId]
        let targetView = outputTex?.view

        // Handle screen output (direct to canvas)
        if (!outputTex && outputId === 'screen' && this.context) {
            const currentTexture = this.context.getCurrentTexture()
            outputTex = {
                handle: currentTexture,
                view: currentTexture.createView(),
                width: this.context.canvas?.width,
                height: this.context.canvas?.height,
                format: this.canvasFormat,
                gpuFormat: this.canvasFormat
            }
            targetView = outputTex.view
        }

        if (!outputTex) {
            throw {
                code: 'ERR_TEXTURE_NOT_FOUND',
                pass: pass.id,
                texture: outputId
            }
        }

        // Create bind group for this pass
        const bindGroup = this.createBindGroup(pass, program, state)

        // Resolve viewport
        const viewport = this.resolveViewport(pass, outputTex)
        
        // Configure color attachment
        const colorAttachment = {
            view: targetView,
            clearValue: { r: 0, g: 0, b: 0, a: 0 },
            loadOp: pass.clear ? 'clear' : 'load',
            storeOp: 'store'
        }

        // Begin render pass
        const renderPassDescriptor = { colorAttachments: [colorAttachment] }
        const passEncoder = this.commandEncoder.beginRenderPass(renderPassDescriptor)
        
        // Get or create pipeline for this output format
        const resolvedFormat = outputTex.gpuFormat || outputTex.format || program.outputFormat
        
        const pipeline = this.resolveRenderPipeline(program, {
            blend: pass.blend,
            topology: pass.drawMode === 'points' ? 'point-list' : 'triangle-list',
            format: resolvedFormat
        })
        
        passEncoder.setPipeline(pipeline)
        passEncoder.setBindGroup(0, bindGroup)
        
        if (viewport) {
            passEncoder.setViewport(viewport.x, viewport.y, viewport.w, viewport.h, 0, 1)
        }

        // Draw
        if (pass.drawMode === 'points') {
            const count = this.resolvePointCount(pass, state, outputId, outputTex)
            passEncoder.draw(count, 1, 0, 0)
        } else {
            passEncoder.draw(3, 1, 0, 0) // Full-screen triangle
        }
        
        passEncoder.end()
    }

    resolveRenderPipeline(program, { blend, topology, format }) {
        const key = this.getPipelineKey({ blend, topology, format })

        if (!program.pipelineCache.has(key)) {
            const pipeline = this.device.createRenderPipeline({
                layout: 'auto',
                vertex: {
                    module: program.vertexModule || this.getDefaultVertexModule(),
                    entryPoint: program.vertexEntryPoint || DEFAULT_VERTEX_ENTRY_POINT
                },
                fragment: {
                    module: program.fragmentModule || program.module,
                    entryPoint: program.fragmentEntryPoint || DEFAULT_FRAGMENT_ENTRY_POINT,
                    targets: [{
                        format: format || program.outputFormat || 'rgba16float',
                        blend: this.resolveBlendState(blend)
                    }]
                },
                primitive: {
                    topology: topology || 'triangle-list'
                }
            })

            program.pipelineCache.set(key, pipeline)
        }

        return program.pipelineCache.get(key)
    }

    getPipelineKey({ blend, topology, format }) {
        const blendKey = blend ? JSON.stringify(blend) : 'noblend'
        const topoKey = topology || 'triangle-list'
        return `${topoKey}|${blendKey}|${format || 'rgba16float'}`
    }

    resolveBlendState(blend) {
        if (!blend) return undefined

        const defaultBlend = {
            color: { srcFactor: 'one', dstFactor: 'one', operation: 'add' },
            alpha: { srcFactor: 'one', dstFactor: 'one', operation: 'add' }
        }

        if (Array.isArray(blend)) {
            const [srcFactor, dstFactor] = blend
            const toFactor = (factor) => {
                if (typeof factor === 'string') return factor
                return null
            }

            const resolvedSrc = toFactor(srcFactor) || defaultBlend.color.srcFactor
            const resolvedDst = toFactor(dstFactor) || defaultBlend.color.dstFactor

            return {
                color: { srcFactor: resolvedSrc, dstFactor: resolvedDst, operation: 'add' },
                alpha: { srcFactor: resolvedSrc, dstFactor: resolvedDst, operation: 'add' }
            }
        }

        return defaultBlend
    }

    resolveViewport(pass, tex) {
        if (tex?.width && tex?.height) {
            return { x: 0, y: 0, w: tex.width, h: tex.height }
        }

        if (pass.viewport) {
            return { x: pass.viewport.x, y: pass.viewport.y, w: pass.viewport.w, h: pass.viewport.h }
        }

        if (this.context?.canvas) {
            return { x: 0, y: 0, w: this.context.canvas.width, h: this.context.canvas.height }
        }

        return null
    }

    resolvePointCount(pass, state, outputId, outputTex) {
        let count = pass.count || 1000

        if (count === 'auto' || count === 'screen' || count === 'input') {
            let refTex = null

            if (count === 'input' && pass.inputs && pass.inputs.inputTex) {
                const inputId = pass.inputs.inputTex
                if (inputId.startsWith('global_')) {
                    const surfaceName = inputId.replace('global_', '')
                    refTex = state.surfaces?.[surfaceName]
                } else {
                    refTex = this.textures.get(inputId)
                }
            } else {
                refTex = outputTex || this.textures.get(outputId)
            }

            if (refTex && refTex.width && refTex.height) {
                count = refTex.width * refTex.height
            } else if (this.context?.canvas) {
                count = this.context.canvas.width * this.context.canvas.height
            }
        }

        return count
    }

    executeComputePass(pass, program, state) {
        // Create bind group for this pass
        const bindGroup = this.createBindGroup(pass, program, state)

        // Determine workgroup dispatch size
        const workgroups = this.resolveWorkgroups(pass)

        // Begin compute pass
        const passEncoder = this.commandEncoder.beginComputePass()
        passEncoder.setPipeline(program.pipeline)
        passEncoder.setBindGroup(0, bindGroup)
        passEncoder.dispatchWorkgroups(workgroups[0], workgroups[1], workgroups[2])
        passEncoder.end()
    }

    resolveWorkgroups(pass) {
        if (pass.workgroups) {
            return pass.workgroups
        }

        if (pass.size) {
            const { x = pass.size.width, y = pass.size.height, z = pass.size.depth || 1 } = pass.size
            if (x && y) {
                return [x, y, z]
            }
        }

        const outputId = pass.outputs?.color || Object.values(pass.outputs || {})[0]
        const output = outputId ? this.textures.get(outputId) : null

        if (!output) {
            throw {
                code: 'ERR_COMPUTE_DISPATCH_UNRESOLVED',
                pass: pass.id,
                detail: 'Compute dispatch dimensions could not be inferred'
            }
        }

        const width = output.width
        const height = output.height

        return [
            Math.ceil(width / 8),
            Math.ceil(height / 8),
            1
        ]
    }

    /**
     * Create a bind group for a pass.
     * 
     * Uses the parsed shader bindings to create entries that match what the shader expects.
     * This handles the various binding conventions used in existing WGSL shaders:
     * - Individual uniform bindings (one per uniform variable)
     * - Texture + sampler pairs
     * - Uniform buffer structs
     */
    createBindGroup(pass, program, state) {
        const entries = []
        const bindings = program.bindings || []
        
        // Get merged uniforms
        const uniforms = { ...state.globalUniforms, ...pass.uniforms }
        
        // Map input names to texture views
        const textureMap = new Map()
        if (pass.inputs) {
            for (const [inputName, texId] of Object.entries(pass.inputs)) {
                let textureView
                
                if (texId.startsWith('global_')) {
                    const surfaceName = texId.replace('global_', '')
                    textureView = state.surfaces?.[surfaceName]?.view
                } else {
                    textureView = this.textures.get(texId)?.view
                }
                
                if (textureView) {
                    textureMap.set(inputName, textureView)
                    // Also map by common alias patterns
                    if (inputName === 'inputTex') {
                        textureMap.set('tex0', textureView)
                        textureMap.set('inputColor', textureView)
                        textureMap.set('src', textureView)
                    }
                }
            }
        }
        
        // Create entries based on parsed shader bindings
        for (const binding of bindings) {
            if (binding.group !== 0) continue // Only support group 0 for now
            
            const entry = { binding: binding.binding }
            
            if (binding.type === 'texture') {
                // Find the texture view for this binding
                let view = textureMap.get(binding.name)
                if (!view) {
                    // Try to find by common patterns
                    if (binding.name.startsWith('tex')) {
                        const idx = parseInt(binding.name.slice(3), 10)
                        const inputKeys = Object.keys(pass.inputs || {})
                        if (!isNaN(idx) && idx < inputKeys.length) {
                            view = textureMap.get(inputKeys[idx])
                        }
                    }
                    if (!view) {
                        // Use first available texture as fallback
                        view = textureMap.values().next().value
                    }
                }
                
                if (view) {
                    entry.resource = view
                    entries.push(entry)
                }
            } else if (binding.type === 'sampler') {
                const samplerType = pass.samplerTypes?.[binding.name] || 'default'
                entry.resource = this.samplers.get(samplerType) || this.samplers.get('default')
                entries.push(entry)
            } else if (binding.type === 'uniform') {
                // Check if this is a struct or individual uniform
                const isStruct = binding.typeDecl && !binding.typeDecl.includes('<') && 
                    binding.typeDecl !== 'f32' && binding.typeDecl !== 'i32' && 
                    binding.typeDecl !== 'u32' && binding.typeDecl !== 'bool' &&
                    !binding.typeDecl.startsWith('vec') && !binding.typeDecl.startsWith('mat')

                if (isStruct) {
                    // This looks like a struct - create full uniform buffer
                    // Pass program to access packedUniformLayout
                    const uniformBuffer = this.createUniformBuffer(pass, state, program)
                    if (uniformBuffer) {
                        entry.resource = { buffer: uniformBuffer }
                        entries.push(entry)
                    }
                } else {
                    // Individual uniform - create small buffer for this value
                    // Use 0 as default for missing uniforms to ensure bind group completeness
                    let value = uniforms[binding.name]
                    if (value === undefined) {
                        // Provide sensible defaults based on type
                        if (binding.typeDecl === 'i32' || binding.typeDecl === 'u32') {
                            value = 0
                        } else if (binding.typeDecl.startsWith('vec2')) {
                            value = [0, 0]
                        } else if (binding.typeDecl.startsWith('vec3')) {
                            value = [0, 0, 0]
                        } else if (binding.typeDecl.startsWith('vec4')) {
                            value = [0, 0, 0, 0]
                        } else {
                            value = 0 // Default for f32 and others
                        }
                    }
                    const buffer = this.createSingleUniformBuffer(value, binding.typeDecl)
                    if (buffer) {
                        entry.resource = { buffer }
                        this.activeUniformBuffers.push(buffer)
                        entries.push(entry)
                    }
                }
            } else if (binding.type === 'storage') {
                // Storage buffers - create or get storage buffer
                const storage = this.createStorageBuffer(binding, pass)
                if (storage) {
                    entry.resource = { buffer: storage }
                    entries.push(entry)
                }
            }
        }
        
        // If no bindings were parsed (maybe older shader format), fall back to legacy approach
        if (bindings.length === 0) {
            return this.createLegacyBindGroup(pass, program, state)
        }
        

        
        // Create bind group
        try {
            const bindGroup = this.device.createBindGroup({
                layout: program.pipeline.getBindGroupLayout(0),
                entries
            })
            return bindGroup
        } catch (err) {
            console.error('Failed to create bind group:', err)
            console.log('Entries:', entries)
            console.log('Bindings:', bindings)
            throw err
        }
    }

    /**
     * Create a buffer for a single uniform value.
     */
    createSingleUniformBuffer(value, typeDecl) {
        let data
        
        if (typeof value === 'boolean') {
            data = new Int32Array([value ? 1 : 0])
        } else if (typeof value === 'number') {
            if (typeDecl === 'i32' || typeDecl === 'u32') {
                data = new Int32Array([Math.round(value)])
            } else {
                data = new Float32Array([value])
            }
        } else if (Array.isArray(value)) {
            if (value.length === 2) {
                // vec2 - needs 8 byte alignment
                data = new Float32Array(value)
            } else if (value.length === 3 || value.length === 4) {
                // vec3/vec4 - needs 16 byte alignment, pad vec3 to vec4
                data = new Float32Array(value.length === 3 ? [...value, 0] : value)
            } else {
                data = new Float32Array(value)
            }
        }
        
        if (!data) return null
        
        const buffer = this.device.createBuffer({
            size: Math.max(data.byteLength, 16), // Minimum 16 bytes for alignment
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
        })
        
        this.queue.writeBuffer(buffer, 0, data)
        return buffer
    }

    /**
     * Create a storage buffer for compute shaders.
     */
    createStorageBuffer(binding, pass) {
        // For now, return null - storage buffers need more context
        // This would be expanded for compute shader support
        return null
    }

    /**
     * Legacy bind group creation for shaders that don't have parsed bindings.
     */
    createLegacyBindGroup(pass, program, state) {
        const entries = []
        let binding = 0
        
        // Bind input textures (alternating texture/sampler)
        if (pass.inputs) {
            for (const [samplerName, texId] of Object.entries(pass.inputs)) {
                let textureView
                
                if (texId.startsWith('global_')) {
                    const surfaceName = texId.replace('global_', '')
                    textureView = state.surfaces?.[surfaceName]?.view
                } else {
                    textureView = this.textures.get(texId)?.view
                }
                
                if (textureView) {
                    entries.push({
                        binding: binding++,
                        resource: textureView
                    })
                    
                    const samplerType = pass.samplerTypes?.[samplerName] || 'default'
                    entries.push({
                        binding: binding++,
                        resource: this.samplers.get(samplerType) || this.samplers.get('default')
                    })
                }
            }
        }
        
        // Create uniform buffer if needed
        if (pass.uniforms || state.globalUniforms) {
            const uniformBuffer = this.createUniformBuffer(pass, state)
            if (uniformBuffer) {
                entries.push({
                    binding: binding++,
                    resource: {
                        buffer: uniformBuffer
                    }
                })
            }
        }
        
        const bindGroup = this.device.createBindGroup({
            layout: program.pipeline.getBindGroupLayout(0),
            entries
        })
        
        return bindGroup
    }

    /**
     * Create a uniform buffer with proper std140 alignment.
     * 
     * Alignment rules (simplified for common types):
     * - float, int, uint, bool: 4-byte align
     * - vec2: 8-byte align
     * - vec3, vec4: 16-byte align
     * - mat3: 48 bytes (3 x vec4 with 16-byte align)
     * - mat4: 64 bytes (4 x vec4)
     */
    createUniformBuffer(pass, state, program = null) {
        const uniforms = { ...state.globalUniforms, ...pass.uniforms }
        
        if (Object.keys(uniforms).length === 0) {
            return null
        }
        
        // Check if program has a packed uniform layout
        const packedLayout = program?.packedUniformLayout
        
        // Pack uniforms into buffer using layout if available
        const data = packedLayout 
            ? this.packUniformsWithLayout(uniforms, packedLayout)
            : this.packUniforms(uniforms)
        
        // Get or create buffer from pool
        let buffer = this.getBufferFromPool(data.byteLength)
        
        if (!buffer) {
            buffer = this.device.createBuffer({
                size: Math.max(data.byteLength, 16), // Minimum 16 bytes
                usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
            })
        }
        
        this.queue.writeBuffer(buffer, 0, data)
        this.activeUniformBuffers.push(buffer)
        
        return buffer
    }

    /**
     * Get a buffer from the pool or return null if none available.
     */
    getBufferFromPool(requiredSize) {
        for (let i = 0; i < this.uniformBufferPool.length; i++) {
            const buffer = this.uniformBufferPool[i]
            if (buffer.size >= requiredSize) {
                this.uniformBufferPool.splice(i, 1)
                return buffer
            }
        }
        return null
    }

    /**
     * Pack uniforms into an ArrayBuffer following std140 alignment rules.
     */
    packUniforms(uniforms) {
        // Calculate required size (rough estimate)
        let estimatedSize = 0
        for (const value of Object.values(uniforms)) {
            if (typeof value === 'number') {
                estimatedSize += 4
            } else if (Array.isArray(value)) {
                estimatedSize += value.length * 4 + 12 // Add padding for alignment
            } else if (typeof value === 'boolean') {
                estimatedSize += 4
            }
        }
        
        // Round up to next 16 bytes and add some buffer
        const bufferSize = Math.max(64, Math.ceil((estimatedSize + 32) / 16) * 16)
        const buffer = new ArrayBuffer(bufferSize)
        const view = new DataView(buffer)
        let offset = 0

        const alignTo = (currentOffset, alignment) => {
            return Math.ceil(currentOffset / alignment) * alignment
        }

        for (const [name, value] of Object.entries(uniforms)) {
            if (value === undefined || value === null) continue
            
            if (typeof value === 'boolean') {
                // bool -> i32
                offset = alignTo(offset, 4)
                view.setInt32(offset, value ? 1 : 0, true)
                offset += 4
            } else if (typeof value === 'number') {
                // Determine if int or float based on whether it's an integer
                offset = alignTo(offset, 4)
                if (Number.isInteger(value) && name !== 'time' && name !== 'deltaTime' && name !== 'aspect') {
                    view.setInt32(offset, value, true)
                } else {
                    view.setFloat32(offset, value, true)
                }
                offset += 4
            } else if (Array.isArray(value)) {
                // Handle vectors
                if (value.length === 2) {
                    // vec2: 8-byte align
                    offset = alignTo(offset, 8)
                    view.setFloat32(offset, value[0], true)
                    view.setFloat32(offset + 4, value[1], true)
                    offset += 8
                } else if (value.length === 3) {
                    // vec3: 16-byte align (stored as vec4 in std140)
                    offset = alignTo(offset, 16)
                    view.setFloat32(offset, value[0], true)
                    view.setFloat32(offset + 4, value[1], true)
                    view.setFloat32(offset + 8, value[2], true)
                    // padding
                    offset += 16
                } else if (value.length === 4) {
                    // vec4: 16-byte align
                    offset = alignTo(offset, 16)
                    for (let i = 0; i < 4; i++) {
                        view.setFloat32(offset + i * 4, value[i], true)
                    }
                    offset += 16
                } else if (value.length === 9) {
                    // mat3: 3 vec4s (each vec3 padded to vec4)
                    offset = alignTo(offset, 16)
                    for (let col = 0; col < 3; col++) {
                        for (let row = 0; row < 3; row++) {
                            view.setFloat32(offset + row * 4, value[col * 3 + row], true)
                        }
                        offset += 16
                    }
                } else if (value.length === 16) {
                    // mat4: 4 vec4s
                    offset = alignTo(offset, 16)
                    for (let i = 0; i < 16; i++) {
                        view.setFloat32(offset + i * 4, value[i], true)
                    }
                    offset += 64
                } else {
                    // Generic array
                    for (let i = 0; i < value.length; i++) {
                        offset = alignTo(offset, 4)
                        view.setFloat32(offset, value[i], true)
                        offset += 4
                    }
                }
            }
        }

        // Return only the used portion, but ensure at least 16 bytes
        const usedSize = Math.max(16, alignTo(offset, 16))
        return new Uint8Array(buffer, 0, Math.min(usedSize, bufferSize))
    }

    /**
     * Pack uniforms into an ArrayBuffer according to a parsed layout.
     * The layout specifies where each uniform should be placed in the array<vec4<f32>, N> struct.
     * 
     * @param {Object} uniforms - Map of uniform names to values
     * @param {Array<{name: string, slot: number, components: string}>} layout - Parsed layout
     * @returns {Uint8Array}
     */
    packUniformsWithLayout(uniforms, layout) {
        // Find the maximum slot index to determine buffer size
        let maxSlot = 0
        for (const entry of layout) {
            maxSlot = Math.max(maxSlot, entry.slot)
        }
        
        // Each slot is a vec4 (16 bytes)
        const bufferSize = (maxSlot + 1) * 16
        const buffer = new ArrayBuffer(bufferSize)
        const view = new DataView(buffer)
        
        // Component offset mapping
        const componentOffset = { x: 0, y: 4, z: 8, w: 12 }
        
        for (const entry of layout) {
            const value = uniforms[entry.name]
            if (value === undefined || value === null) {
                continue
            }
            
            const slotOffset = entry.slot * 16
            
            if (entry.components.length === 1) {
                // Single component (x, y, z, or w)
                const compOff = componentOffset[entry.components]
                const offset = slotOffset + compOff
                
                if (typeof value === 'boolean') {
                    view.setFloat32(offset, value ? 1.0 : 0.0, true)
                } else if (typeof value === 'number') {
                    view.setFloat32(offset, value, true)
                }
            } else if (entry.components.length === 2) {
                // Two components (xy, yz, etc.)
                const startComp = entry.components[0]
                const offset = slotOffset + componentOffset[startComp]
                
                if (Array.isArray(value)) {
                    for (let i = 0; i < Math.min(value.length, 2); i++) {
                        view.setFloat32(offset + i * 4, value[i], true)
                    }
                } else if (typeof value === 'number') {
                    view.setFloat32(offset, value, true)
                }
            } else if (entry.components.length === 3) {
                // Three components (xyz)
                const startComp = entry.components[0]
                const offset = slotOffset + componentOffset[startComp]
                
                if (Array.isArray(value)) {
                    for (let i = 0; i < Math.min(value.length, 3); i++) {
                        view.setFloat32(offset + i * 4, value[i], true)
                    }
                } else if (typeof value === 'number') {
                    view.setFloat32(offset, value, true)
                }
            } else if (entry.components.length === 4) {
                // Four components (xyzw)
                const offset = slotOffset
                
                if (Array.isArray(value)) {
                    for (let i = 0; i < Math.min(value.length, 4); i++) {
                        view.setFloat32(offset + i * 4, value[i], true)
                    }
                } else if (typeof value === 'number') {
                    view.setFloat32(offset, value, true)
                }
            }
        }
        
        return new Uint8Array(buffer)
    }

    beginFrame(_state) {
        // Return active buffers to pool
        while (this.activeUniformBuffers.length > 0) {
            const buffer = this.activeUniformBuffers.pop()
            this.uniformBufferPool.push(buffer)
        }
        
        // Create command encoder for this frame
        this.commandEncoder = this.device.createCommandEncoder()
    }

    endFrame() {
        // Submit commands
        if (this.commandEncoder) {
            const commandBuffer = this.commandEncoder.finish()
            this.queue.submit([commandBuffer])
            this.commandEncoder = null
        }
    }

    present(textureId) {
        if (!this.context) return
        
        const tex = this.textures.get(textureId)
        if (!tex) return
        
        // Use a render pass to blit the texture to the canvas
        // This handles format conversion (e.g., rgba16float -> bgra8unorm)
        const pipeline = this.getBlitPipeline()
        const bindGroup = this.createBlitBindGroup(tex)
        
        const commandEncoder = this.device.createCommandEncoder()
        const canvasTexture = this.context.getCurrentTexture()
        const canvasView = canvasTexture.createView()
        
        const renderPass = commandEncoder.beginRenderPass({
            colorAttachments: [{
                view: canvasView,
                clearValue: { r: 0, g: 0, b: 0, a: 1 },
                loadOp: 'clear',
                storeOp: 'store'
            }]
        })
        
        renderPass.setPipeline(pipeline)
        renderPass.setBindGroup(0, bindGroup)
        renderPass.draw(3, 1, 0, 0) // Full-screen triangle
        renderPass.end()
        
        this.queue.submit([commandEncoder.finish()])
    }
    
    /**
     * Get or create the blit pipeline for presenting to canvas
     */
    getBlitPipeline() {
        if (this._blitPipeline) return this._blitPipeline
        
        const blitShaderSource = `
            struct VertexOutput {
                @builtin(position) position: vec4<f32>,
                @location(0) uv: vec2<f32>,
            }
            
            @vertex
            fn vs_main(@builtin(vertex_index) vertexIndex: u32) -> VertexOutput {
                var pos = array<vec2<f32>, 3>(
                    vec2<f32>(-1.0, -1.0),
                    vec2<f32>(3.0, -1.0),
                    vec2<f32>(-1.0, 3.0)
                );
                var uv = array<vec2<f32>, 3>(
                    vec2<f32>(0.0, 1.0),
                    vec2<f32>(2.0, 1.0),
                    vec2<f32>(0.0, -1.0)
                );
                var output: VertexOutput;
                output.position = vec4<f32>(pos[vertexIndex], 0.0, 1.0);
                output.uv = uv[vertexIndex];
                return output;
            }
            
            @group(0) @binding(0) var srcTex: texture_2d<f32>;
            @group(0) @binding(1) var srcSampler: sampler;
            
            @fragment
            fn fs_main(input: VertexOutput) -> @location(0) vec4<f32> {
                return textureSample(srcTex, srcSampler, input.uv);
            }
        `
        
        const module = this.device.createShaderModule({ code: blitShaderSource })
        
        this._blitPipeline = this.device.createRenderPipeline({
            layout: 'auto',
            vertex: {
                module,
                entryPoint: 'vs_main'
            },
            fragment: {
                module,
                entryPoint: 'fs_main',
                targets: [{
                    format: this.canvasFormat || 'bgra8unorm'
                }]
            },
            primitive: {
                topology: 'triangle-list'
            }
        })
        
        return this._blitPipeline
    }
    
    /**
     * Create a bind group for blitting a texture to the canvas
     */
    createBlitBindGroup(tex) {
        const pipeline = this.getBlitPipeline()
        const sampler = this.samplers.get('default')
        
        return this.device.createBindGroup({
            layout: pipeline.getBindGroupLayout(0),
            entries: [
                { binding: 0, resource: tex.view },
                { binding: 1, resource: sampler }
            ]
        })
    }

    resize(_width, _height) {
        // Textures will be recreated by the pipeline when dimensions change
    }

    resolveFormat(format) {
        const formats = {
            'rgba8': 'rgba8unorm',
            'rgba16f': 'rgba16float',
            'rgba32f': 'rgba32float',
            'r8': 'r8unorm',
            'r16f': 'r16float',
            'r32f': 'r32float',
            'rg8': 'rg8unorm',
            'rg16f': 'rg16float',
            'rg32f': 'rg32float',
            // Pass-through for already-resolved formats
            'rgba8unorm': 'rgba8unorm',
            'rgba16float': 'rgba16float',
            'rgba32float': 'rgba32float',
            'r8unorm': 'r8unorm',
            'r16float': 'r16float',
            'r32float': 'r32float',
            'bgra8unorm': 'bgra8unorm'
        }
        
        return formats[format] || format || 'rgba8unorm'
    }

    resolveUsage(usageArray) {
        let usage = 0
        
        for (const u of usageArray) {
            switch (u) {
                case 'render':
                    usage |= GPUTextureUsage.RENDER_ATTACHMENT
                    break
                case 'sample':
                    usage |= GPUTextureUsage.TEXTURE_BINDING
                    break
                case 'storage':
                    usage |= GPUTextureUsage.STORAGE_BINDING
                    break
                case 'copySrc':
                    usage |= GPUTextureUsage.COPY_SRC
                    break
                case 'copyDst':
                    usage |= GPUTextureUsage.COPY_DST
                    break
            }
        }
        
        return usage
    }

    getName() {
        return 'WebGPU'
    }

    /**
     * Read pixels from a texture for testing purposes.
     * Note: This is async due to WebGPU's buffer mapping requirements.
     * @param {string} textureId - The texture ID to read from
     * @returns {Promise<{width: number, height: number, data: Uint8Array}>}
     */
    async readPixels(textureId) {
        const tex = this.textures.get(textureId)
        if (!tex) {
            throw new Error(`Texture ${textureId} not found`)
        }

        const { handle, width, height, gpuFormat } = tex
        
        // Determine bytes per pixel based on format
        let bytesPerPixel = 4 // Default for rgba8unorm
        let isFloat = false
        if (gpuFormat === 'rgba16float') {
            bytesPerPixel = 8 // 2 bytes per channel * 4 channels
            isFloat = true
        } else if (gpuFormat === 'rgba32float') {
            bytesPerPixel = 16 // 4 bytes per channel * 4 channels
            isFloat = true
        }
        
        const bytesPerRow = Math.ceil(width * bytesPerPixel / 256) * 256 // Align to 256 bytes
        const bufferSize = bytesPerRow * height

        // Create staging buffer for reading
        const stagingBuffer = this.device.createBuffer({
            size: bufferSize,
            usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ
        })

        // Copy texture to staging buffer
        const commandEncoder = this.device.createCommandEncoder()
        commandEncoder.copyTextureToBuffer(
            { texture: handle },
            { buffer: stagingBuffer, bytesPerRow },
            { width, height, depthOrArrayLayers: 1 }
        )
        this.queue.submit([commandEncoder.finish()])

        // Map and read the buffer
        await stagingBuffer.mapAsync(GPUMapMode.READ)
        const mappedRange = stagingBuffer.getMappedRange()
        
        // Convert to Uint8Array output (0-255 per channel)
        const data = new Uint8Array(width * height * 4)
        
        if (gpuFormat === 'rgba16float') {
            // Read as float16 and convert to uint8
            const srcData = new Uint16Array(mappedRange)
            for (let row = 0; row < height; row++) {
                const srcRowOffset = (row * bytesPerRow) / 2 // Uint16Array offset
                for (let col = 0; col < width; col++) {
                    const srcPixel = srcRowOffset + col * 4
                    const dstPixel = (row * width + col) * 4
                    // Convert float16 to float32 then to uint8
                    for (let c = 0; c < 4; c++) {
                        const f16 = srcData[srcPixel + c]
                        const f32 = float16ToFloat32(f16)
                        data[dstPixel + c] = Math.max(0, Math.min(255, Math.round(f32 * 255)))
                    }
                }
            }
        } else if (gpuFormat === 'rgba32float') {
            // Read as float32 and convert to uint8
            const srcData = new Float32Array(mappedRange)
            for (let row = 0; row < height; row++) {
                const srcRowOffset = (row * bytesPerRow) / 4 // Float32Array offset
                for (let col = 0; col < width; col++) {
                    const srcPixel = srcRowOffset + col * 4
                    const dstPixel = (row * width + col) * 4
                    for (let c = 0; c < 4; c++) {
                        const f32 = srcData[srcPixel + c]
                        data[dstPixel + c] = Math.max(0, Math.min(255, Math.round(f32 * 255)))
                    }
                }
            }
        } else {
            // Assume rgba8unorm - direct copy (removing row padding)
            const srcData = new Uint8Array(mappedRange)
            for (let row = 0; row < height; row++) {
                const srcOffset = row * bytesPerRow
                const dstOffset = row * width * 4
                data.set(srcData.subarray(srcOffset, srcOffset + width * 4), dstOffset)
            }
        }

        stagingBuffer.unmap()
        stagingBuffer.destroy()

        return { width, height, data }
    }

    static async isAvailable() {
        if (typeof navigator === 'undefined' || !navigator.gpu) {
            return false
        }
        
        try {
            const adapter = await navigator.gpu.requestAdapter()
            return !!adapter
        } catch {
            return false
        }
    }
}
