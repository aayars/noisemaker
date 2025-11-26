import { Effect } from '../../../src/runtime/effect.js';

/**
 * Blur
 * /shaders/effects/blur/blur.wgsl
 */
export default class Blur extends Effect {
  name = "Blur";
  namespace = "nm";
  func = "blur";

  globals = {
    amount: {
        type: "float",
        default: 10,
        uniform: "amount",
        min: 1,
        max: 64,
        step: 1,
        ui: {
            label: "Amount",
            control: "slider"
        }
    },
    spline_order: {
        type: "float",
        default: 3,
        uniform: "spline_order",
        min: 0,
        max: 3,
        step: 1,
        ui: {
            label: "Spline Order",
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
      program: "blur",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputBuffer: "outputColor"
      }
    }
  ];
}
