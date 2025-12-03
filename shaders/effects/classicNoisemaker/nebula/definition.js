import { Effect } from '../../../src/runtime/effect.js';

/**
 * Nebula
 * /shaders/effects/nebula/nebula.wgsl
 */
export default class Nebula extends Effect {
  name = "Nebula";
  namespace = "classicNoisemaker";
  func = "nebula";

  globals = {};

  // TODO: Define passes based on shader requirements
  // This effect was originally implemented as a WebGPU compute shader.
  // A render pass implementation needs to be created for GLSL/WebGL2 compatibility.
  passes = [
    {
      name: "main",
      program: "nebula",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputBuffer: "outputTex"
      }
    }
  ];
}
