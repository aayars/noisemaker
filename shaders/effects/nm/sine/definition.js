import { Effect } from '../../../src/runtime/effect.js';

/**
 * Sine
 * /shaders/effects/sine/sine.wgsl
 */
export default class Sine extends Effect {
  name = "Sine";
  namespace = "nm";
  func = "sine";

  globals = {
    amount: {
        type: "float",
        default: 3,
        uniform: "amount",
        min: 0,
        max: 20,
        step: 0.1,
        ui: {
            label: "Amount",
            control: "slider"
        }
    },
    rgb: {
        type: "boolean",
        default: false,
        uniform: "rgb",
        ui: {
            label: "RGB",
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
      program: "sine",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputBuffer: "outputColor"
      }
    }
  ];
}
