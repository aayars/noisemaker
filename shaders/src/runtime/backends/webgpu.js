/**
 * WebGPU Backend Implementation
 */

import { Backend } from '../backend.js'
import {
    DEFAULT_FRAGMENT_ENTRY_POINT,
    DEFAULT_VERTEX_ENTRY_POINT,
    DEFAULT_VERTEX_SHADER_WGSL
} from '../default-shaders.js'

// Full-screen triangle vertex shader for render passes
// const FULLSCREEN_TRIANGLE_WGSL = `
// @vertex
// fn vs_main(@builtin(vertex_index) vertexIndex: u32) -> @builtin(position) vec4<f32> {
//     let x = f32((vertexIndex << 1u) & 2u);
//     let y = f32(vertexIndex & 2u);
//     return vec4<f32>(x * 2.0 - 1.0, 1.0 - y * 2.0, 0.0, 1.0);
// }
// `

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
    }

    async init() {
        // Create default sampler
        const sampler = this.device.createSampler({
            minFilter: 'linear',
            magFilter: 'linear',
            addressModeU: 'clamp-to-edge',
            addressModeV: 'clamp-to-edge'
        })
        this.samplers.set('default', sampler)
        
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

    async compileProgram(id, spec) {
        // Inject defines
        const source = this.injectDefines(spec.source || spec.wgsl, spec.defines || {})
        
        if (spec.type === 'compute') {
            const module = this.device.createShaderModule({ code: source })
            const compilationInfo = await module.getCompilationInfo()
            const errors = compilationInfo.messages.filter(m => m.type === 'error')

            if (errors.length > 0) {
                throw {
                    code: 'ERR_SHADER_COMPILE',
                    detail: errors.map(e => e.message).join('\n'),
                    program: id
                }
            }

            const pipeline = await this.createComputePipeline(module, spec)

            this.programs.set(id, {
                module,
                pipeline,
                type: 'compute'
            })

            return { module, pipeline }
        }

        const fragmentModule = this.device.createShaderModule({ code: source })
        const fragmentInfo = await fragmentModule.getCompilationInfo()
        const fragmentErrors = fragmentInfo.messages.filter(m => m.type === 'error')

        if (fragmentErrors.length > 0) {
            throw {
                code: 'ERR_SHADER_COMPILE',
                detail: fragmentErrors.map(e => e.message).join('\n'),
                program: id
            }
        }

        let vertexModule
        let vertexEntryPoint

        if (spec.vertexWGSL) {
            vertexModule = this.device.createShaderModule({ code: spec.vertexWGSL })
            const vertexInfo = await vertexModule.getCompilationInfo()
            const vertexErrors = vertexInfo.messages.filter(m => m.type === 'error')

            if (vertexErrors.length > 0) {
                throw {
                    code: 'ERR_SHADER_COMPILE',
                    detail: vertexErrors.map(e => e.message).join('\n'),
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
        const pipeline = await this.createRenderPipeline({
            vertexModule,
            fragmentModule,
            vertexEntryPoint,
            fragmentEntryPoint,
            format: outputFormat,
            blend: spec?.blend,
            topology: spec?.topology
        })

        const pipelineCache = new Map()
        const pipelineKey = this.getPipelineKey({ topology: spec?.topology, blend: spec?.blend, format: outputFormat })
        pipelineCache.set(pipelineKey, pipeline)

        this.programs.set(id, {
            module: fragmentModule,
            pipeline,
            type: spec.type || 'render',
            vertexModule,
            fragmentModule,
            vertexEntryPoint,
            fragmentEntryPoint,
            outputFormat,
            pipelineCache
        })

        return { module: fragmentModule, pipeline }
    }

    async createRenderPipeline({ vertexModule, fragmentModule, vertexEntryPoint, fragmentEntryPoint, spec, format, blend, topology }) {
        // Create a basic render pipeline layout
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
                    format: format || this.resolveFormat(spec?.outputFormat || 'rgba16float'),
                    blend: this.resolveBlendState(blend)
                }]
            },
            primitive: {
                topology: topology || 'triangle-list'
            }
        })

        return pipeline
    }

    async createComputePipeline(module, _spec) {
        const pipeline = this.device.createComputePipeline({
            layout: 'auto',
            compute: {
                module,
                entryPoint: 'cs_main'
            }
        })
        
        return pipeline
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
        let injected = ''
        
        for (const [key, value] of Object.entries(defines)) {
            // WGSL uses const declarations instead of #define
            injected += `const ${key} = ${value};\n`
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
        // Get output texture
        let outputId = pass.outputs.color || Object.values(pass.outputs)[0]

        if (outputId.startsWith('global_')) {
            const surfaceName = outputId.replace('global_', '')
            if (state.writeSurfaces && state.writeSurfaces[surfaceName]) {
                outputId = state.writeSurfaces[surfaceName]
            }
        }

        let outputTex = this.textures.get(outputId) || state.surfaces?.[outputId]
        let targetView = outputTex?.view

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

        const viewport = this.resolveViewport(pass, outputTex)
        const colorAttachment = {
            view: targetView,
            clearValue: { r: 0, g: 0, b: 0, a: 0 },
            loadOp: pass.clear ? 'clear' : 'load',
            storeOp: 'store'
        }

        // Begin render pass
        const renderPassDescriptor = { colorAttachments: [colorAttachment] }

        const passEncoder = this.commandEncoder.beginRenderPass(renderPassDescriptor)
        const pipeline = this.resolveRenderPipeline(program, {
            blend: pass.blend,
            topology: pass.drawMode === 'points' ? 'point-list' : 'triangle-list',
            format: outputTex.gpuFormat || outputTex.format || program.outputFormat
        })
        passEncoder.setPipeline(pipeline)
        passEncoder.setBindGroup(0, bindGroup)
        if (viewport) {
            passEncoder.setViewport(viewport.x, viewport.y, viewport.w, viewport.h, 0, 1)
        }

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

    createBindGroup(pass, program, state) {
        const entries = []
        let binding = 0
        
        // Bind input textures
        if (pass.inputs) {
            for (const [_, texId] of Object.entries(pass.inputs)) {
                let textureView
                
                if (texId.startsWith('global_')) {
                    const surfaceName = texId.replace('global_', '')
                    textureView = state.surfaces?.[surfaceName]?.view
                } else {
                    textureView = this.textures.get(texId)?.view
                }
                
                if (textureView) {
                    // Add texture binding
                    entries.push({
                        binding: binding++,
                        resource: textureView
                    })
                    
                    // Add sampler binding
                    entries.push({
                        binding: binding++,
                        resource: this.samplers.get('default')
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
        
        // Create bind group
        const bindGroup = this.device.createBindGroup({
            layout: program.pipeline.getBindGroupLayout(0),
            entries
        })
        
        return bindGroup
    }

    createUniformBuffer(pass, state) {
        const uniforms = { ...state.globalUniforms, ...pass.uniforms }
        
        if (Object.keys(uniforms).length === 0) {
            return null
        }
        
        // Pack uniforms into buffer (simplified - would need proper std140 layout)
        const data = this.packUniforms(uniforms)
        
        const buffer = this.device.createBuffer({
            size: data.byteLength,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
        })
        
        this.queue.writeBuffer(buffer, 0, data)
        
        return buffer
    }

    packUniforms(uniforms) {
        // Simplified uniform packing
        // In production, would need proper std140 layout alignment
        const values = Object.values(uniforms)
        const floatCount = values.reduce((acc, v) => {
            if (typeof v === 'number') return acc + 1
            if (Array.isArray(v)) return acc + v.length
            return acc
        }, 0)
        
        const buffer = new Float32Array(floatCount)
        let offset = 0
        
        for (const value of values) {
            if (typeof value === 'number') {
                buffer[offset++] = value
            } else if (Array.isArray(value)) {
                buffer.set(value, offset)
                offset += value.length
            }
        }
        
        return buffer
    }

    beginFrame(_state) {
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
        
        const commandEncoder = this.device.createCommandEncoder()
        const canvasTexture = this.context.getCurrentTexture()
        
        // Simple copy if dimensions match
        if (tex.width === canvasTexture.width && tex.height === canvasTexture.height) {
             commandEncoder.copyTextureToTexture(
                 { texture: tex.handle },
                 { texture: canvasTexture },
                 { width: tex.width, height: tex.height, depthOrArrayLayers: 1 }
             )
        }
        
        this.queue.submit([commandEncoder.finish()])
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
            'rgba8unorm': 'rgba8unorm',
            'rgba16float': 'rgba16float',
            'rgba32float': 'rgba32float'
        }
        
        return formats[format] || 'rgba8unorm'
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

    static async isAvailable() {
        if (!navigator.gpu) {
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
