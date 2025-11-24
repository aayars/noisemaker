import { Effect } from '../../../src/runtime/effect.js';

/**
 * Clouds
 * /shaders/effects/clouds/clouds.wgsl
 */
export default class Clouds extends Effect {
  name = "Clouds";
  namespace = "nm";
  func = "clouds";

  globals = {
    speed: {
      type: "float",
      default: 1.0,
      min: 0.0,
      max: 3.0,
      step: 0.05,
      ui: {
        label: "Speed",
        control: "slider"
      }
    },
    scale: {
      type: "float",
      default: 0.25,
      min: 0.1,
      max: 1.0,
      step: 0.05,
      ui: {
        label: "Scale",
        control: "slider"
      }
    }
  };

  passes = [
    {
      name: "downsample",
      type: "render",
      program: "clouds_downsample",
      outputs: {
        fragColor: "downsampleTex"
      }
    },
    {
      name: "shade",
      type: "render",
      program: "clouds_shade",
      inputs: {
        downsampleTex: "downsampleTex"
      },
      outputs: {
        fragColor: "shadedTex"
      }
    },
    {
      name: "upsample",
      type: "render",
      program: "clouds_upsample",
      inputs: {
        shadedTex: "shadedTex",
        inputTex: "inputTex"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
