import { Effect } from '../../../src/runtime/effect.js';

/**
 * Lowpoly
 * /shaders/effects/lowpoly/lowpoly.wgsl
 */
export default class Lowpoly extends Effect {
  name = "Lowpoly";
  namespace = "nm";
  func = "lowpoly";

  globals = {
    distrib: {
        type: "enum",
        default: 1000000,
        ui: {
            label: "Point Distribution"
        }
    },
    freq: {
        type: "int",
        default: 10,
        min: 1,
        max: 64,
        step: 1,
        ui: {
            label: "Frequency",
            control: "slider"
        }
    },
    dist_metric: {
        type: "enum",
        default: 1,
        ui: {
            label: "Distance Metric"
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
      program: "lowpoly",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputBuffer: "outputColor"
      }
    }
  ];
}
