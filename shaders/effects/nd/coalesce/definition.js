import { Effect } from '../../../src/runtime/effect.js';

export default class Coalesce extends Effect {
  name = "Coalesce";
  namespace = "nd";
  func = "coalesce";

  globals = {
    seed: {
      type: "int",
      default: 1,
      uniform: "seed",
      min: 1,
      max: 100,
      ui: {
        label: "seed",
        control: "slider"
      }
    },
    blendMode: {
      type: "int",
      default: 10,
      uniform: "blendMode",
      choices: {
        Add: 0,
        Alpha: 1,
        "Brightness A→b": 1004,
        "Brightness B→a": 1005,
        Cloak: 100,
        "Color Burn": 2,
        "Color Dodge": 3,
        Darken: 4,
        Difference: 5,
        Exclusion: 6,
        Glow: 7,
        "Hard Light": 8,
        "Hue A→b": 1000,
        "Hue B→a": 1001,
        Lighten: 9,
        Mix: 10,
        Multiply: 11,
        Negation: 12,
        Overlay: 13,
        Phoenix: 14,
        Reflect: 15,
        "Saturation A→b": 1002,
        "Saturation B→a": 1003,
        Screen: 16,
        "Soft Light": 17,
        Subtract: 18
      },
      ui: {
        label: "mode",
        control: "dropdown"
      }
    },
    mixAmt: {
      type: "float",
      default: 0,
      uniform: "mixAmt",
      min: -100,
      max: 100,
      ui: {
        label: "mix",
        control: "slider"
      }
    },
    refractAAmt: {
      type: "float",
      default: 0,
      uniform: "refractAAmt",
      min: 0,
      max: 100,
      ui: {
        label: "refract a→b",
        control: "slider"
      }
    },
    refractBAmt: {
      type: "float",
      default: 0,
      uniform: "refractBAmt",
      min: 0,
      max: 100,
      ui: {
        label: "refract b→a",
        control: "slider"
      }
    },
    refractADir: {
      type: "float",
      default: 0,
      uniform: "refractADir",
      min: 0,
      max: 360,
      ui: {
        label: "refract dir a",
        control: "slider"
      }
    },
    refractBDir: {
      type: "float",
      default: 0,
      uniform: "refractBDir",
      min: 0,
      max: 360,
      ui: {
        label: "refract dir b",
        control: "slider"
      }
    }
  };

  passes = [
    {
      name: "render",
      type: "render",
      program: "coalesce",
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
