import { Effect } from '../../../src/runtime/effect.js';

/**
 * Ridge
 * /shaders/effects/ridge/ridge.wgsl
 */
export default class Ridge extends Effect {
  name = "Ridge";
  namespace = "nm";
  func = "ridge";

  globals = {};

  // TODO: Define passes based on shader requirements
  // This effect was originally implemented as a WebGPU compute shader.
  // A render pass implementation needs to be created for GLSL/WebGL2 compatibility.
  passes = [
    {
      name: "main",
      type: "compute",
      program: "ridge",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputBuffer: "outputColor"
      }
    }
  ];
}
