import { Effect } from '../../../src/runtime/effect.js';

/**
 * FXAA
 * Fast Approximate Anti-Aliasing
 */
export default class Fxaa extends Effect {
  name = "Fxaa";
  namespace = "nm";
  func = "fxaa";

  globals = {};

  passes = [
    {
      name: "main",
      program: "fxaa",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
