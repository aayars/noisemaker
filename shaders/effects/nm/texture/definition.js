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

  passes = [
    {
      name: "main",
      type: "render",
      program: "texture",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
