import { Effect } from '../../../src/runtime/effect.js';

/**
 * Vignette - normalize input and blend edges toward constant brightness
 */
export default class Vignette extends Effect {
  name = "Vignette";
  namespace = "nm";
  func = "vignette";

  globals = {
    brightness: {
      type: "float",
      default: 0,
      min: 0,
      max: 1,
      step: 0.01,
      ui: {
        label: "Brightness",
        control: "slider"
      }
    },
    alpha: {
      type: "float",
      default: 1,
      min: 0,
      max: 1,
      step: 0.01,
      ui: {
        label: "Alpha",
        control: "slider"
      }
    }
  };

  passes = [
    {
      name: "main",
      type: "render",
      program: "vignette",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
