import { Effect } from '../../../src/runtime/effect.js';

/**
 * Texture
 * /shaders/effects/texture/texture.wgsl
 */
export default class Texture extends Effect {
  name = "Texture";
  namespace = "nm";
  func = "texture";

  globals = {};

  // TODO: Define passes based on shader requirements
  // This effect was originally implemented as a WebGPU compute shader.
  // A render pass implementation needs to be created for GLSL/WebGL2 compatibility.
  passes = [
    {
      name: "main",
      type: "compute",
      program: "texture",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputBuffer: "outputColor"
      }
    }
  ];
}
