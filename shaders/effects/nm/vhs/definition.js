import { Effect } from '../../../src/runtime/effect.js';

/**
 * VHS
 * /shaders/effects/vhs/vhs.wgsl
 */
export default class Vhs extends Effect {
  name = "Vhs";
  namespace = "nm";
  func = "vhs";

  globals = {};

  // TODO: Define passes based on shader requirements
  // This effect was originally implemented as a WebGPU compute shader.
  // A render pass implementation needs to be created for GLSL/WebGL2 compatibility.
  passes = [
    {
      name: "main",
      type: "compute",
      program: "vhs",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputBuffer: "outputColor"
      }
    }
  ];
}
