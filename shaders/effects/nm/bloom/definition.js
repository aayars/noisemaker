import { Effect } from '../../../src/runtime/effect.js';

/**
 * Bloom
 * /shaders/effects/bloom/bloom.wgsl
 */
export default class Bloom extends Effect {
  name = "Bloom";
  namespace = "nm";
  func = "bloom";

  globals = {
    alpha: {
        type: "float",
        default: 0.5,
        uniform: "alpha",
        min: 0,
        max: 1,
        step: 0.05,
        ui: {
            label: "Alpha",
            control: "slider"
        }
    }
};

  // TODO: Define passes based on shader requirements
  // This effect was originally implemented as a WebGPU compute shader.
  // A render pass implementation needs to be created for GLSL/WebGL2 compatibility.
  passes = [
    {
      name: "main",
      type: "compute",
      program: "bloom",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputBuffer: "outputColor"
      }
    }
  ];
}
