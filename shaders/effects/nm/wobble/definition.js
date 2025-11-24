import { Effect } from '../../../src/runtime/effect.js';

/**
 * Wobble
 * /shaders/effects/wobble/wobble.wgsl
 */
export default class Wobble extends Effect {
  name = "Wobble";
  namespace = "nm";
  func = "wobble";

  globals = {};

  // TODO: Define passes based on shader requirements
  // This effect was originally implemented as a WebGPU compute shader.
  // A render pass implementation needs to be created for GLSL/WebGL2 compatibility.
  passes = [
    {
      name: "main",
      type: "compute",
      program: "wobble",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputBuffer: "outputColor"
      }
    }
  ];
}
