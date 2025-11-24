import { Effect } from '../../../src/runtime/effect.js';

/**
 * Derivative
 * /shaders/effects/derivative/derivative.wgsl
 */
export default class Derivative extends Effect {
  name = "Derivative";
  namespace = "nm";
  func = "derivative";

  globals = {
    dist_metric: {
        type: "enum",
        default: 1,
        ui: {
            label: "Distance Metric"
        }
    },
    with_normalize: {
        type: "boolean",
        default: true,
        ui: {
            label: "Normalize",
            control: "checkbox"
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
      type: "render",
      program: "derivative",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputBuffer: "outputColor"
      }
    }
  ];
}
