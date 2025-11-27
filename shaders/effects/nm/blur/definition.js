import { Effect } from '../../../src/runtime/effect.js';

/**
 * Blur
 * Two-pass blur: downsample to coarse buffer, then upsample with interpolation
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

  // Internal texture for downsample buffer
  textures = {
    blurDownsample: {
      width: 64,
      height: 64,
      format: "rgba16float"
    }
  };

  // Two-pass blur: downsample to coarse buffer, then upsample with interpolation
  passes = [
    {
      name: "downsample",
      program: "blur",
      viewport: { width: 64, height: 64 },
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        fragColor: "blurDownsample"
      }
    },
    {
      name: "upsample",
      program: "blurUpsample",
      inputs: {
        downsampleTex: "blurDownsample",
        inputTex: "inputTex"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
