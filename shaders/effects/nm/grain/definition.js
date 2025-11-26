import { Effect } from '../../../src/runtime/effect.js';

/**
 * Grain
 * /shaders/effects/grain/grain.wgsl
 */
export default class Grain extends Effect {
  name = "Grain";
  namespace = "nm";
  func = "grain";

  globals = {
    alpha: {
        type: "float",
        default: 0.25,
        uniform: "alpha",
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
      program: "grain",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputBuffer: "outputColor"
      }
    }
  ];
}
