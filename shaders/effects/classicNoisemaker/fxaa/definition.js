import { Effect } from '../../../src/runtime/effect.js';

/**
 * FXAA
 * Fast Approximate Anti-Aliasing
 */
export default class Fxaa extends Effect {
  name = "Fxaa";
  namespace = "classicNoisemaker";
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
        fragColor: "outputTex"
      }
    }
  ];
}
