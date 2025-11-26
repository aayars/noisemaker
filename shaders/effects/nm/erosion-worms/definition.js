import { Effect } from '../../../src/runtime/effect.js';

export default class ErosionWorms extends Effect {
  name = "ErosionWorms";
  namespace = "nd";
  func = "erosion_worms";

  globals = {
    channelCount: {
      type: "float",
      default: 4,
      uniform: "channelCount",
      ui: {
        label: "channels",
        control: "slider"
      }
    },
    density: {
      type: "float",
      default: 5,
      uniform: "density",
      min: 1,
      max: 100,
      step: 1,
      ui: {
        label: "density",
        control: "slider"
      }
    },
    stride: {
      type: "float",
      default: 1.0,
      uniform: "stride",
      min: 0.1,
      max: 10.0,
      step: 0.1,
      ui: {
        label: "stride",
        control: "slider"
      }
    },
    quantize: {
      type: "boolean",
      default: false,
      uniform: "quantize",
      ui: {
        label: "quantize",
        control: "checkbox"
      }
    },
    padding1: {
      type: "float",
      default: 0,
      uniform: "padding1",
      ui: {
        label: "padding",
        control: "slider"
      }
    },
    intensity: {
      type: "float",
      default: 90,
      uniform: "intensity",
      min: 0,
      max: 100,
      step: 1,
      ui: {
        label: "intensity",
        control: "slider"
      }
    },
    inverse: {
      type: "boolean",
      default: false,
      uniform: "inverse",
      ui: {
        label: "inverse",
        control: "checkbox"
      }
    },
    xy_blend: {
      type: "boolean",
      default: false,
      uniform: "xy_blend",
      ui: {
        label: "xy blend",
        control: "checkbox"
      }
    },
    worm_lifetime: {
      type: "float",
      default: 30,
      uniform: "worm_lifetime",
      min: 0,
      max: 60,
      step: 1,
      ui: {
        label: "lifetime",
        control: "slider"
      }
    },
    inputIntensity: {
      type: "float",
      default: 100,
      uniform: "inputIntensity",
      min: 0,
      max: 100,
      step: 1,
      ui: {
        label: "input intensity",
        control: "slider"
      }
    },
    padding3: {
      type: "float",
      default: 0,
      uniform: "padding3",
      ui: {
        label: "padding",
        control: "slider"
      }
    },
    resetState: {
      type: "button",
      default: false,
      uniform: "resetState",
      ui: { label: "state" }
    }
  };

  passes = [
    {
      name: "render",
      type: "render",
      program: "erosion-worms",
      inputs: {
        inputTex: "inputTex",
        erosionTex: "erosionTex"
      },

      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
