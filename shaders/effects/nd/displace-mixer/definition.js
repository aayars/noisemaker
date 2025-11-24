import { Effect } from '../../../src/runtime/effect.js';

export default class DisplaceMixer extends Effect {
  name = "DisplaceMixer";
  namespace = "nd";
  func = "displace_mixer";

  globals = {
    mode: {
      type: "int",
      default: 1,
      choices: {
        Displace: 0,
        Reflect: 2,
        Refract: 1
      },
      ui: {
        label: "mode",
        control: "dropdown"
      }
    },
    displaceSource: {
      type: "int",
      default: 1,
      choices: {
        "inputTex": 0,
        "tex": 1
      },
      ui: {
        label: "map source",
        control: "dropdown"
      }
    },
    intensity: {
      type: "float",
      default: 50,
      min: 0,
      max: 100,
      ui: {
        label: "intensity",
        control: "slider"
      }
    },
    direction: {
      type: "float",
      default: 0,
      min: 0,
      max: 360,
      ui: {
        label: "direction",
        control: "slider"
      }
    },
    wrap: {
      type: "int",
      default: 0,
      choices: {
        Clamp: 2,
        Mirror: 0,
        Repeat: 1
      },
      ui: {
        label: "wrap",
        control: "dropdown"
      }
    },
    smoothing: {
      type: "float",
      default: 1,
      min: 1,
      max: 100,
      ui: {
        label: "smoothing",
        control: "slider"
      }
    },
    aberration: {
      type: "float",
      default: 0,
      min: 0,
      max: 100,
      ui: {
        label: "aberration",
        control: "slider"
      }
    }
  };

  passes = [
    {
      name: "render",
      type: "render",
      program: "displace-mixer",
      inputs: {
              tex0: "inputTex",
              tex1: "tex"
            }
,
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
