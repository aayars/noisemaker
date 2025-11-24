/**
 * Abstract Backend Interface
 * Defines the contract that both WebGL2 and WebGPU backends must implement.
 */

export class Backend {
    constructor(context) {
        this.context = context
        this.textures = new Map() // physicalId -> GPU texture handle
        this.programs = new Map() // programId -> compiled program/pipeline
        this.uniformBuffers = new Map() // bufferId -> buffer handle
    }

    /**
     * Initialize the backend
     * @returns {Promise<void>}
     */
    async init() {
        throw new Error('Backend.init() must be implemented')
    }

    /**
     * Create a texture with the specified parameters
     * @param {string} id - Physical texture ID
     * @param {object} spec - { width, height, format, usage }
     * @returns {object} Texture handle
     */
    createTexture(_id, _spec) {
        throw new Error('Backend.createTexture() must be implemented')
    }

    /**
     * Destroy a texture
     * @param {string} id - Physical texture ID
     */
    destroyTexture(_id) {
        throw new Error('Backend.destroyTexture() must be implemented')
    }

    /**
     * Compile a shader program
     * @param {string} id - Program ID
     * @param {object} spec - { source, type, defines }
     * @returns {Promise<object>} Compiled program/pipeline
     */
    async compileProgram(_id, _spec) {
        throw new Error('Backend.compileProgram() must be implemented')
    }

    /**
     * Execute a render pass
     * @param {object} pass - Pass specification
     * @param {object} state - Current frame state
     */
    executePass(_pass, _state) {
        throw new Error('Backend.executePass() must be implemented')
    }

    /**
     * Begin a frame
     * @param {object} state - Frame state
     */
    beginFrame(_state) {
        throw new Error('Backend.beginFrame() must be implemented')
    }

    /**
     * End a frame
     */
    endFrame() {
        throw new Error('Backend.endFrame() must be implemented')
    }

    /**
     * Resize surfaces to new dimensions
     * @param {number} width
     * @param {number} height
     */
    resize(_width, _height) {
        throw new Error('Backend.resize() must be implemented')
    }

    /**
     * Get backend name
     * @returns {string}
     */
    getName() {
        throw new Error('Backend.getName() must be implemented')
    }

    /**
     * Check if backend is available
     * @returns {boolean}
     */
    static isAvailable() {
        throw new Error('Backend.isAvailable() must be implemented')
    }
}
