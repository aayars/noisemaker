import { Effect } from '../../../src/runtime/effect.js';

/**
 * Tint
 * /shaders/effects/tint/tint.wgsl
 */
export default class Tint extends Effect {
  name = "Tint";
  namespace = "nm";
  func = "tint";

  globals = {
    alpha: {
        type: "float",
        default: 0.5,
        min: 0,
        max: 1,
        step: 0.01,
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
      program: "tint",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputBuffer: "outputColor"
      }
    }
  ];
}
