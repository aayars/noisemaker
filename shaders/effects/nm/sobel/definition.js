import { Effect } from '../../../src/runtime/effect.js';

/**
 * Sobel
 * /shaders/effects/sobel/sobel.wgsl
 */
export default class Sobel extends Effect {
  name = "Sobel";
  namespace = "nm";
  func = "sobel";

  globals = {
    dist_metric: {
        type: "enum",
        default: 1,
        uniform: "dist_metric",
        ui: {
            label: "Distance Metric"
        }
    },
    alpha: {
        type: "float",
        default: 1,
        min: 0,
        max: 1,
        step: 0.01,
        uniform: "alpha",
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
      program: "sobel",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputBuffer: "outputColor"
      }
    }
  ];
}
