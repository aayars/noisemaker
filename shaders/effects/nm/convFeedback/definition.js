import { Effect } from '../../../src/runtime/effect.js';

/**
 * Conv Feedback
 * /shaders/effects/conv_feedback/conv_feedback.wgsl
 */
export default class ConvFeedback extends Effect {
  name = "ConvFeedback";
  namespace = "nm";
  func = "convFeedback";

  globals = {
    iterations: {
        type: "float",
        default: 100,
        uniform: "iterations",
        min: 0,
        max: 100,
        step: 1,
        ui: {
            label: "Feedback Bias",
            control: "slider"
        }
    },
    alpha: {
        type: "float",
        default: 0.5,
        uniform: "alpha",
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
      name: "blur",
      program: "convFeedbackBlur",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        fragColor: "blurred"
      }
    },
    {
      name: "sharpen",
      program: "convFeedbackSharpen",
      inputs: {
        blurredTex: "blurred"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
