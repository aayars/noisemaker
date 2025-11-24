import { Effect } from '../../../src/runtime/effect.js';

/**
 * Outline
 * /shaders/effects/outline/outline.wgsl
 */
export default class Outline extends Effect {
  name = "Outline";
  namespace = "nm";
  func = "outline";

  globals = {
    sobel_metric: {
        type: "enum",
        default: 1,
        ui: {
            label: "Sobel Metric"
        }
    },
    invert: {
        type: "boolean",
        default: false,
        ui: {
            label: "Invert",
            control: "checkbox"
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
      program: "outline",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputBuffer: "outputColor"
      }
    }
  ];
}
