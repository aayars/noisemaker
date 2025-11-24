import { Effect } from '../../../src/runtime/effect.js';

export default class Worms extends Effect {
  name = "Worms";
  namespace = "nd";
  func = "worms_nd";

  globals = {
    channelCount: {
      type: "float",
      default: 4,
      ui: {
        label: "channels",
        control: "slider"
      }
    },
    behavior: {
      type: "int",
      default: 1,
      choices: {
        None: 0,
        Obedient: 1,
        Crosshatch: 2,
        Unruly: 3,
        Chaotic: 4,
        "Random Mix": 5,
        Meandering: 10
      },
      ui: {
        label: "behavior",
        control: "dropdown"
      }
    },
    density: {
      type: "int",
      default: 20,
      min: 1,
      max: 100,
      step: 1,
      ui: {
        label: "density",
        control: "slider"
      }
    },
    stride: {
      type: "int",
      default: 10,
      min: 1,
      max: 100,
      step: 1,
      ui: {
        label: "stride",
        control: "slider"
      }
    },
    padding1: {
      type: "float",
      default: 0,
      ui: {
        label: "padding behavior stride",
        control: "slider"
      }
    },
    strideDeviation: {
      type: "float",
      default: 0.05,
      ui: {
        label: "stride deviation",
        control: "slider"
      }
    },
    padding_alpha: {
      type: "float",
      default: 1.0,
      ui: {
        label: "padding alpha",
        control: "slider"
      }
    },
    kink: {
      type: "float",
      default: 1,
      min: 0,
      max: 10,
      step: 0.1,
      ui: {
        label: "kink",
        control: "slider"
      }
    },
    quantize: {
      type: "boolean",
      default: false,
      ui: {
        label: "quantize",
        control: "checkbox"
      }
    },
    padding_speed: {
      type: "float",
      default: 0,
      ui: {
        label: "padding speed",
        control: "slider"
      }
    },
    intensity: {
      type: "float",
      default: 90,
      min: 0,
      max: 100,
      step: 1,
      ui: {
        label: "intensity",
        control: "slider"
      }
    },
    inputIntensity: {
      type: "float",
      default: 100,
      min: 0,
      max: 100,
      step: 1,
      ui: {
        label: "input intensity",
        control: "slider"
      }
    },
    lifetime: {
      type: "float",
      default: 30,
      min: 0,
      max: 60,
      step: 1,
      ui: {
        label: "lifetime",
        control: "slider"
      }
    },
    resetState: {
      type: "button",
      default: false,
      ui: { label: "state" }
    }
  };

  passes = [
    {
      name: "render",
      type: "render",
      program: "worms",
      inputs: {
        inputTex: "inputTex",
        wormsTex: "wormsTex"
      },

      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
