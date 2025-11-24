/**
 * Base class for all Effects.
 * Represents the runtime embodiment of an Effect Definition.
 */
export class Effect {
    constructor() {
        this.state = {};
        this.uniforms = {};
    }

    /**
     * Called once when the effect is initialized.
     */
    onInit() {
        // Override me
    }

    /**
     * Called every frame before rendering.
     * @param {object} context { time, delta, uniforms }
     * @returns {object} Uniforms to bind
     */
    onUpdate(_context) {
        return {};
    }

    /**
     * Called when the effect is destroyed.
     */
    onDestroy() {
        // Override me
    }
}
