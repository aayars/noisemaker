import { Effect } from '../../../src/runtime/effect.js';

/**
 * FXAA
 * /shaders/effects/fxaa/fxaa.wgsl
 */
export default class Fxaa extends Effect {
  name = "Fxaa";
  namespace = "nm";
  func = "fxaa";

  globals = {};

  // TODO: Define passes based on shader requirements
  // This effect was originally implemented as a WebGPU compute shader.
  // A render pass implementation needs to be created for GLSL/WebGL2 compatibility.
  passes = [
    {
      name: "main",
      program: "fxaa",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputBuffer: "outputColor"
      }
    }
  ];
}
