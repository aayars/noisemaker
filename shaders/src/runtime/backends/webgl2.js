/**
 * WebGL 2 Backend Implementation
 */

import { Backend } from '../backend.js'
import {
    DEFAULT_VERTEX_SHADER,
    FULLSCREEN_TRIANGLE_POSITIONS,
    FULLSCREEN_TRIANGLE_VERTEX_COUNT
} from '../default-shaders.js'

export class WebGL2Backend extends Backend {
    constructor(context) {
        super(context)
        this.gl = context
        this.fbos = new Map() // texture_id -> framebuffer
        this.fullscreenVAO = null
        this.presentProgram = null
        this.maxTextureUnits = 16
    }

    async init() {
        const gl = this.gl
        
        // Enable extensions for floating point textures
        if (!gl.getExtension('EXT_color_buffer_float')) {
            console.warn('EXT_color_buffer_float not supported');
        }
        if (!gl.getExtension('OES_texture_float_linear')) {
            console.warn('OES_texture_float_linear not supported');
        }

        // Get capabilities
        this.maxTextureUnits = gl.getParameter(gl.MAX_TEXTURE_IMAGE_UNITS)
        
        // Create full-screen quad VAO
        this.fullscreenVAO = this.createFullscreenVAO()
        this.emptyVAO = gl.createVertexArray()
        this.presentProgram = this.createPresentProgram()
        
        return Promise.resolve()
    }

    createPresentProgram() {
        const gl = this.gl
        const vs = DEFAULT_VERTEX_SHADER
        const fs = `#version 300 es
        precision highp float;
        in vec2 v_texCoord;
        uniform sampler2D u_texture;
        out vec4 fragColor;
        void main() {
            fragColor = texture(u_texture, v_texCoord);
        }`
        
        const vertShader = this.compileShader(gl.VERTEX_SHADER, vs)
        const fragShader = this.compileShader(gl.FRAGMENT_SHADER, fs)
        
        const program = gl.createProgram()
        gl.attachShader(program, vertShader)
        gl.attachShader(program, fragShader)
        
        // Ensure a_position is at location 0 to match VAO
        gl.bindAttribLocation(program, 0, 'a_position')
        
        gl.linkProgram(program)
        
        if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
            console.error('Failed to link present program')
            return null
        }
        
        gl.deleteShader(vertShader)
        gl.deleteShader(fragShader)
        
        return {
            handle: program,
            uniforms: {
                texture: gl.getUniformLocation(program, 'u_texture')
            }
        }
    }

    createFullscreenVAO() {
        const gl = this.gl
        
        // Create vertex buffer with full-screen triangle
        const positions = FULLSCREEN_TRIANGLE_POSITIONS
        
        const buffer = gl.createBuffer()
        gl.bindBuffer(gl.ARRAY_BUFFER, buffer)
        gl.bufferData(gl.ARRAY_BUFFER, positions, gl.STATIC_DRAW)
        
        // Create VAO
        const vao = gl.createVertexArray()
        gl.bindVertexArray(vao)
        gl.enableVertexAttribArray(0)
        gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0)
        gl.bindVertexArray(null)
        gl.bindBuffer(gl.ARRAY_BUFFER, null)
        
        return vao
    }

    createTexture(id, spec) {
        const gl = this.gl
        const texture = gl.createTexture()
        
        gl.bindTexture(gl.TEXTURE_2D, texture)
        
        // Resolve format
        const glFormat = this.resolveFormat(spec.format)
        
        // Allocate texture storage
        gl.texImage2D(
            gl.TEXTURE_2D,
            0,
            glFormat.internalFormat,
            spec.width,
            spec.height,
            0,
            glFormat.format,
            glFormat.type,
            null
        )
        
        // Set texture parameters
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
        
        gl.bindTexture(gl.TEXTURE_2D, null)
        
        this.textures.set(id, {
            handle: texture,
            width: spec.width,
            height: spec.height,
            format: spec.format,
            glFormat
        })
        
        // Create FBO if this will be a render target
        if (spec.usage && spec.usage.includes('render')) {
            this.createFBO(id, texture)
        }
        
        return texture
    }

    createFBO(id, texture) {
        const gl = this.gl
        const fbo = gl.createFramebuffer()
        
        gl.bindFramebuffer(gl.FRAMEBUFFER, fbo)
        gl.framebufferTexture2D(
            gl.FRAMEBUFFER,
            gl.COLOR_ATTACHMENT0,
            gl.TEXTURE_2D,
            texture,
            0
        )
        
        // Check FBO status
        const status = gl.checkFramebufferStatus(gl.FRAMEBUFFER)
        if (status !== gl.FRAMEBUFFER_COMPLETE) {
            console.error(`FBO incomplete for texture ${id}: ${status}`)
        }
        
        gl.bindFramebuffer(gl.FRAMEBUFFER, null)
        this.fbos.set(id, fbo)
    }

    destroyTexture(id) {
        const gl = this.gl
        const tex = this.textures.get(id)
        
        if (tex) {
            gl.deleteTexture(tex.handle)
            this.textures.delete(id)
        }
        
        const fbo = this.fbos.get(id)
        if (fbo) {
            gl.deleteFramebuffer(fbo)
            this.fbos.delete(id)
        }
    }

    async compileProgram(id, spec) {
        const gl = this.gl
        
        // Inject defines
        const source = this.injectDefines(spec.source || spec.glsl || spec.fragment, spec.defines || {})
        
        // Compile vertex shader
        const vsSource = spec.vertex || DEFAULT_VERTEX_SHADER
        const usingDefaultVertex = !spec.vertex
        const vertShader = this.compileShader(gl.VERTEX_SHADER, vsSource)
        
        // Compile fragment shader
        const fragShader = this.compileShader(gl.FRAGMENT_SHADER, source)
        
        // Link program
        const program = gl.createProgram()
        gl.attachShader(program, vertShader)
        gl.attachShader(program, fragShader)
        
        if (usingDefaultVertex) {
            gl.bindAttribLocation(program, 0, 'a_position')
        }
        
        gl.linkProgram(program)
        
        if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
            const log = gl.getProgramInfoLog(program)
            throw {
                code: 'ERR_SHADER_LINK',
                detail: log,
                program: id
            }
        }
        
        // Clean up shaders
        gl.deleteShader(vertShader)
        gl.deleteShader(fragShader)
        
        // Extract uniforms and attribute locations
        const uniforms = this.extractUniforms(program)
        const attributes = {
            a_position: gl.getAttribLocation(program, 'a_position'),
            aPosition: gl.getAttribLocation(program, 'aPosition')
        }
        
        const compiledProgram = {
            handle: program,
            uniforms,
            attributes
        }
        
        this.programs.set(id, compiledProgram)
        return compiledProgram
    }

    compileShader(type, source) {
        const gl = this.gl
        const shader = gl.createShader(type)
        
        gl.shaderSource(shader, source)
        gl.compileShader(shader)
        
        if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
            const log = gl.getShaderInfoLog(shader)
            gl.deleteShader(shader)
            throw {
                code: 'ERR_SHADER_COMPILE',
                detail: log,
                source
            }
        }
        
        return shader
    }

    injectDefines(source, defines) {
        let injected = '#version 300 es\nprecision highp float;\n'
        
        for (const [key, value] of Object.entries(defines)) {
            injected += `#define ${key} ${value}\n`
        }
        
        // Remove any existing version directive from source
        const cleaned = source.replace(/^\s*#version.*$/m, '')
        
        return injected + cleaned
    }

    extractUniforms(program) {
        const gl = this.gl
        const uniforms = {}
        const count = gl.getProgramParameter(program, gl.ACTIVE_UNIFORMS)
        
        for (let i = 0; i < count; i++) {
            const info = gl.getActiveUniform(program, i)
            const location = gl.getUniformLocation(program, info.name)
            
            uniforms[info.name] = {
                location,
                type: info.type,
                size: info.size
            }
        }
        
        return uniforms
    }

    executePass(pass, state) {
        const gl = this.gl
        const program = this.programs.get(pass.program)
        
        if (!program) {
            console.error(`Program ${pass.program} not found for pass ${pass.id}`)
            throw {
                code: 'ERR_PROGRAM_NOT_FOUND',
                pass: pass.id,
                program: pass.program
            }
        }
        
        // Use program
        gl.useProgram(program.handle)
        
        // Bind output FBO
        let outputId = pass.outputs.color || Object.values(pass.outputs)[0]
        
        // Resolve global surface to current write buffer
        if (outputId.startsWith('global_')) {
            const surfaceName = outputId.replace('global_', '')
            if (state.writeSurfaces && state.writeSurfaces[surfaceName]) {
                outputId = state.writeSurfaces[surfaceName]
            }
        }

        const fbo = this.fbos.get(outputId)
        if (!fbo && outputId !== 'screen') {
             console.warn(`FBO not found for ${outputId}`)
        }
        gl.bindFramebuffer(gl.FRAMEBUFFER, fbo || null)
        
        // Set viewport
        const tex = this.textures.get(outputId)
        if (tex) {
            gl.viewport(0, 0, tex.width, tex.height)
        } else if (pass.viewport) {
            gl.viewport(pass.viewport.x, pass.viewport.y, pass.viewport.w, pass.viewport.h)
        } else {
            gl.viewport(0, 0, gl.drawingBufferWidth, gl.drawingBufferHeight)
        }

        // DEBUG: Clear to random color to verify FBO write
        // gl.clearColor(Math.random(), Math.random(), Math.random(), 1.0)
        // gl.clear(gl.COLOR_BUFFER_BIT)
        
        // Bind input textures
        this.bindTextures(pass, program, state)
        
        // Bind uniforms
        this.bindUniforms(pass, program, state)
        
        // Handle Blending
        if (pass.blend) {
            gl.enable(gl.BLEND)
            if (Array.isArray(pass.blend)) {
                gl.blendFunc(pass.blend[0], pass.blend[1])
            } else {
                // Default to additive
                gl.blendFunc(gl.ONE, gl.ONE)
            }
        } else {
            gl.disable(gl.BLEND)
        }

        // Draw
        if (pass.drawMode === 'points') {
            let count = pass.count || 1000
            if (count === 'auto' || count === 'screen' || count === 'input') {
                // Determine count based on mode
                let refTex = null
                
                if (count === 'input' && pass.inputs && pass.inputs.inputTex) {
                    // Use input texture dimensions
                    const inputId = pass.inputs.inputTex
                    if (inputId.startsWith('global_')) {
                        const surfaceName = inputId.replace('global_', '')
                        const surfaceTex = state.surfaces?.[surfaceName]
                        if (surfaceTex) {
                            refTex = surfaceTex
                        }
                    } else {
                        refTex = this.textures.get(inputId)
                    }
                } else {
                    // Use output texture dimensions (auto) or screen
                    const tex = this.textures.get(outputId)
                    refTex = tex
                }

                if (refTex && refTex.width && refTex.height) {
                    count = refTex.width * refTex.height
                } else {
                    count = gl.drawingBufferWidth * gl.drawingBufferHeight
                }
            }
            
            gl.bindVertexArray(this.emptyVAO)
            gl.drawArrays(gl.POINTS, 0, count)
            gl.bindVertexArray(null)
        } else {
            // Default to fullscreen triangle
            gl.bindVertexArray(this.fullscreenVAO)
            gl.drawArrays(gl.TRIANGLES, 0, FULLSCREEN_TRIANGLE_VERTEX_COUNT)
            gl.bindVertexArray(null)
        }
        
        // Check for errors
        const error = gl.getError()
        if (error !== gl.NO_ERROR) {
            console.error(`WebGL Error in pass ${pass.id}: ${error}`)
        }
        
        // Unbind
        gl.bindFramebuffer(gl.FRAMEBUFFER, null)
        gl.useProgram(null)
        gl.disable(gl.BLEND)
    }

    bindTextures(pass, program, state) {
        const gl = this.gl
        let unit = 0
        
        if (!pass.inputs) return
        
        for (const [samplerName, texId] of Object.entries(pass.inputs)) {
            if (unit >= this.maxTextureUnits) {
                throw {
                    code: 'ERR_TOO_MANY_TEXTURES',
                    pass: pass.id,
                    limit: this.maxTextureUnits
                }
            }
            
            // Get texture from state or textures map
            let texture
            if (texId.startsWith('global_')) {
                // Global surface
                const surfaceName = texId.replace('global_', '')
                texture = state.surfaces?.[surfaceName]?.handle
            } else {
                texture = this.textures.get(texId)?.handle
            }
            
            gl.activeTexture(gl.TEXTURE0 + unit)
            gl.bindTexture(gl.TEXTURE_2D, texture || null)
            
            // Bind sampler uniform
            const uniform = program.uniforms[samplerName]
            if (uniform) {
                gl.uniform1i(uniform.location, unit)
            }
            
            unit++
        }
    }

    bindUniforms(pass, program, state) {
        const gl = this.gl
        const uniforms = { ...state.globalUniforms, ...pass.uniforms }
        
        for (const [name, value] of Object.entries(uniforms)) {
            const uniform = program.uniforms[name]
            if (!uniform) {
                // Warn if a user-provided uniform is missing in the shader
                // Skip warning for internal/global uniforms that might not be used
                if (pass.uniforms && pass.uniforms[name] !== undefined) {
                    // console.warn(`Uniform '${name}' provided but not found in program '${pass.program}'`)
                }
                continue
            }
            
            const loc = uniform.location
            
            if (value === undefined || value === null) {
                // console.warn(`Uniform '${name}' has undefined/null value`)
                continue
            }

            // Determine uniform type and bind accordingly
            switch (uniform.type) {
                case gl.FLOAT:
                    gl.uniform1f(loc, value)
                    break
                case gl.INT:
                case gl.BOOL:
                    gl.uniform1i(loc, typeof value === 'boolean' ? (value ? 1 : 0) : value)
                    break
                case gl.FLOAT_VEC2:
                    gl.uniform2fv(loc, value)
                    break
                case gl.FLOAT_VEC3:
                    gl.uniform3fv(loc, value)
                    break
                case gl.FLOAT_VEC4:
                    gl.uniform4fv(loc, value)
                    break
                case gl.FLOAT_MAT3:
                    gl.uniformMatrix3fv(loc, false, value)
                    break
                case gl.FLOAT_MAT4:
                    gl.uniformMatrix4fv(loc, false, value)
                    break
                // Add more types as needed
            }
        }
    }

    beginFrame(_state) {
        const gl = this.gl
        gl.clearColor(0, 0, 0, 0)
    }

    endFrame() {
        const gl = this.gl
        gl.flush()
    }

    present(textureId) {
        const gl = this.gl
        const tex = this.textures.get(textureId)
        if (!tex || !this.presentProgram || !this.fullscreenVAO) {
            console.warn('Present skipped: missing texture or program', { textureId, tex, prog: !!this.presentProgram })
            return
        }

        gl.bindFramebuffer(gl.FRAMEBUFFER, null)
        gl.viewport(0, 0, gl.drawingBufferWidth, gl.drawingBufferHeight)
        
        // Clear the screen first
        gl.clearColor(0, 0, 0, 1)
        gl.clear(gl.COLOR_BUFFER_BIT)
        
        gl.useProgram(this.presentProgram.handle)
        
        gl.activeTexture(gl.TEXTURE0)
        gl.bindTexture(gl.TEXTURE_2D, tex.handle)
        gl.uniform1i(this.presentProgram.uniforms.texture, 0)
        
        gl.bindVertexArray(this.fullscreenVAO)
        gl.drawArrays(gl.TRIANGLES, 0, FULLSCREEN_TRIANGLE_VERTEX_COUNT)
        
        const error = gl.getError()
        if (error !== gl.NO_ERROR) {
            console.error(`WebGL Error in present: ${error}`)
        }

        gl.bindVertexArray(null)
        
        gl.useProgram(null)
    }

    resize(_width, _height) {
        // Canvas resize is handled externally
        // We'll recreate textures in the pipeline when needed
    }

    resolveFormat(format) {
        const gl = this.gl
        
        const formats = {
            'rgba8': {
                internalFormat: gl.RGBA8,
                format: gl.RGBA,
                type: gl.UNSIGNED_BYTE
            },
            'rgba16f': {
                internalFormat: gl.RGBA16F,
                format: gl.RGBA,
                type: gl.HALF_FLOAT
            },
            'rgba32f': {
                internalFormat: gl.RGBA32F,
                format: gl.RGBA,
                type: gl.FLOAT
            },
            'r8': {
                internalFormat: gl.R8,
                format: gl.RED,
                type: gl.UNSIGNED_BYTE
            },
            'r16f': {
                internalFormat: gl.R16F,
                format: gl.RED,
                type: gl.HALF_FLOAT
            },
            'r32f': {
                internalFormat: gl.R32F,
                format: gl.RED,
                type: gl.FLOAT
            }
        }
        
        return formats[format] || formats['rgba8']
    }

    getName() {
        return 'WebGL2'
    }

    static isAvailable() {
        try {
            const canvas = document.createElement('canvas')
            const gl = canvas.getContext('webgl2')
            return !!gl
        } catch {
            return false
        }
    }
}
