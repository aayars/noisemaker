import { Effect } from '../../../src/runtime/effect.js';

/**
 * nu/inv - Invert brightness
 * Simple luminance inversion: 1.0 - brightness
 */
export default class Inv extends Effect {
  name = "Inv";
  namespace = "nu";
  func = "inv";

  uniformLayout = {};

  globals = {};

  passes = [
    {
      name: "render",
      program: "inv",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        fragColor: "outputTex"
      }
    }
  ];
}
