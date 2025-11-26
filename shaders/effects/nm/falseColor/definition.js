import { Effect } from '../../../src/runtime/effect.js';

/**
 * False Color
 * /shaders/effects/false_color/false_color.wgsl
 */
export default class FalseColor extends Effect {
  name = "FalseColor";
  namespace = "nm";
  func = "falseColor";

  globals = {
    horizontal: {
        type: "boolean",
        default: false,
        uniform: "horizontal",
        ui: {
            label: "Horizontal",
            control: "checkbox"
        }
    },
    displacement: {
        type: "float",
        default: 0.5,
        uniform: "displacement",
        min: 0,
        max: 1,
        step: 0.01,
        ui: {
            label: "Displacement",
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
      program: "falseColor",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputBuffer: "outputColor"
      }
    }
  ];
}
