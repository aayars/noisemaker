import { Effect } from '../../../src/runtime/effect.js';

/**
 * nu/lens - Lens distortion (barrel/pincushion)
 */
export default class Lens extends Effect {
  name = "Lens";
  namespace = "nu";
  func = "lens";

  globals = {
    displacement: {
      type: "float",
      default: 0,
      uniform: "lensDisplacement",
      min: -1,
      max: 1,
      step: 0.01,
      ui: {
        label: "Displacement",
        control: "slider"
      }
    }
  };

  passes = [
    {
      name: "render",
      program: "lens",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        fragColor: "outputTex"
      }
    }
  ];
}
