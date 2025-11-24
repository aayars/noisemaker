import { Effect } from '../../../src/runtime/effect.js';

/**
 * Vaseline - soft blur/glow toward edges using Chebyshev mask
 */
export default class Vaseline extends Effect {
  name = "Vaseline";
  namespace = "nm";
  func = "vaseline";

  globals = {
    alpha: {
        type: "float",
        default: 0.5,
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
      program: "vaseline",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
