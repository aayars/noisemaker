import { Effect } from '../../../src/runtime/effect.js';

/**
 * nu/oklab - Reinterpret RGB channels as OKLab
 * Treats RGB channels as OKLab values and converts to RGB
 */
export default class Oklab extends Effect {
  name = "Oklab";
  namespace = "nu";
  func = "oklab";

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
