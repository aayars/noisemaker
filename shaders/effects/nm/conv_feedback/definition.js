import { Effect } from '../../../src/runtime/effect.js';

/**
 * Conv Feedback
 * /shaders/effects/conv_feedback/conv_feedback.wgsl
 */
export default class ConvFeedback extends Effect {
  name = "ConvFeedback";
  namespace = "nm";
  func = "convfeedback";

  globals = {
    iterations: {
        type: "float",
        default: 100,
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
      type: "render",
      program: "conv_feedback_blur",
      inputs: {
        input_texture: "inputTex"
      },
      outputs: {
        fragColor: "blurred"
      }
    },
    {
      name: "sharpen",
      type: "render",
      program: "conv_feedback_sharpen",
      inputs: {
        blurredTex: "blurred"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
