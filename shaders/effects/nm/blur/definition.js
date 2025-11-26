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
    splineOrder: {
        type: "float",
        default: 3,
        uniform: "splineOrder",
        min: 0,
        max: 3,
        step: 1,
        ui: {
            label: "Spline Order",
            control: "slider"
        }
    }
};

  // Two-pass blur: downsample to coarse buffer, then upsample with interpolation
  passes = [
    {
      name: "downsample",
      program: "blur",
      entryPoint: "downsample_main",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        downsample_buffer: "_blurDownsample"
      }
    },
    {
      name: "upsample",
      program: "blur",
      entryPoint: "upsample_main",
      inputs: {
        downsample_buffer: "_blurDownsample"
      },
      outputs: {
        output_buffer: "outputColor"
      }
    }
  ];

  // Internal texture for downsample buffer
  textures = {
    _blurDownsample: {
      width: 64,
      height: 64,
      format: "rgba16float"
    }
  };
}
