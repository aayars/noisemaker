import { Effect } from '../../../src/runtime/effect.js';

/**
 * Conv Feedback
 * Iterative blur+sharpen feedback effect.
 * 
 * Uses selfTex (previous frame's output) for frame-by-frame accumulation.
 * Each frame applies one blur+sharpen iteration to the accumulated result.
 * The effect converges after ~100 frames.
 * 
 * Usage: search nm
 *        noise(seed: 1).convFeedback(alpha: 0.5).out(o0)
 */
export default class ConvFeedback extends Effect {
  name = "ConvFeedback";
  namespace = "nm";
  func = "convFeedback";

  globals = {
    alpha: {
        type: "float",
        default: 0.5,
        uniform: "alpha",
        min: 0,
        max: 1,
        step: 0.01,
        ui: {
            label: "Blend Alpha",
            control: "slider"
        }
    }
  };

  // Internal texture for intermediate blur result
  textures = {
    _blurred: { width: "100%", height: "100%", format: "rgba16f" }
  };

  // Two-pass feedback: blur then sharpen
  // selfTex provides previous frame's output for accumulation
  passes = [
    // Pass 1: Blur the previous frame's accumulated result
    {
      name: "blur",
      program: "convFeedbackBlur",
      inputs: {
        inputTex: "selfTex"  // Previous frame's output (o0)
      },
      outputs: {
        fragColor: "_blurred"
      }
    },
    // Pass 2: Sharpen and blend with original input
    {
      name: "sharpenBlend",
      program: "convFeedbackSharpenBlend",
      inputs: {
        blurredTex: "_blurred",
        inputTex: "inputTex",   // Original input for blending
        selfTex: "selfTex"      // For first-frame detection
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
