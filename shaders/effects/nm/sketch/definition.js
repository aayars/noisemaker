import { Effect } from '../../../src/runtime/effect.js';

/**
 * Sketch
 * /shaders/effects/sketch/sketch.wgsl
 */
export default class Sketch extends Effect {
  name = "Sketch";
  namespace = "nm";
  func = "sketch";

  globals = {};

  // TODO: Define passes based on shader requirements
  // This effect was originally implemented as a WebGPU compute shader.
  // A render pass implementation needs to be created for GLSL/WebGL2 compatibility.
  passes = [
    {
      name: "main",
      type: "compute",
      program: "sketch",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputBuffer: "outputColor"
      }
    }
  ];
}
