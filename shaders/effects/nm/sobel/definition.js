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
        ui: {
            label: "Alpha",
            control: "slider"
        }
    }
};

  // TODO: Define passes based on shader requirements
  // This effect was originally implemented as a WebGPU compute shader.
  // A render pass implementation needs to be created for GLSL/WebGL2 compatibility.
  passes = [
    {
      name: "main",
      type: "compute",
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
