import { Effect } from '../../../src/runtime/effect.js';

/**
 * nu/bloom - Two-pass bloom effect
 */
export default class Bloom extends Effect {
  name = "Bloom";
  namespace = "filter";
  func = "bloom";

  globals = {
    alpha: {
      type: "float",
      default: 0.5,
      uniform: "bloomAlpha",
      min: 0,
      max: 1,
      step: 0.05,
      ui: {
        label: "Alpha",
        control: "slider"
      }
    }
  };

  // Internal texture for downsampled bloom data
  textures = {
    _bloomDownsample: {
      width: 64,
      height: 64,
      format: "rgba16float"
    }
  };

  passes = [
    {
      name: "downsample",
      program: "downsample",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        fragColor: "_bloomDownsample"
      }
    },
    {
      name: "upsample",
      program: "upsample",
      inputs: {
        inputTex: "inputTex",
        downsampleBuffer: "_bloomDownsample"
      },
      outputs: {
        fragColor: "outputTex"
      }
    }
  ];
}
