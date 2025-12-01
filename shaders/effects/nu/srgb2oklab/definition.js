import { Effect } from '../../../src/runtime/effect.js';

/**
 * nu/srgb2oklab - Reinterpret RGB channels as OKLab
 * Treats RGB channels as OKLab values and converts to RGB
 */
export default class Oklab extends Effect {
  name = "Oklab";
  namespace = "nu";
  func = "srgb2oklab";

  uniformLayout = {};

  globals = {};

  passes = [
    {
      name: "render",
      program: "oklab",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        fragColor: "outputTex"
      }
    }
  ];
}
