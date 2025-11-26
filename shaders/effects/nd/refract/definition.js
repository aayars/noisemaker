import { Effect } from '../../../src/runtime/effect.js';

export default class Refract extends Effect {
  name = "Refract";
  namespace = "nd";
  func = "refract";

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
        "Color Burn": 2,
        "Color Dodge": 3,
        Darken: 4,
        Difference: 5,
        Exclusion: 6,
        Glow: 7,
        "Hard Light": 8,
        Lighten: 9,
        Mix: 10,
        Multiply: 11,
        Negation: 12,
        Overlay: 13,
        Phoenix: 14,
        Reflect: 15,
        Screen: 16,
        "Soft Light": 17,
        Subtract: 18
      },
      ui: {
        label: "blend",
        control: "dropdown"
      }
    },
    mixAmt: {
      type: "float",
      default: 50,
      uniform: "mixAmt",
      min: 0,
      max: 100,
      ui: {
        label: "mix",
        control: "slider"
      }
    },
    mode: {
      type: "int",
      default: 0,
      uniform: "mode",
      choices: {
        Refract: 0,
        Reflect: 1
      },
      ui: {
        label: "mode",
        control: "dropdown"
      }
    },
    amount: {
      type: "float",
      default: 50,
      uniform: "amount",
      min: 0,
      max: 100,
      ui: {
        label: "amount",
        control: "slider"
      }
    },
    refractDir: {
      type: "float",
      default: 0,
      uniform: "refractDir",
      min: 0,
      max: 360,
      ui: {
        label: "refract dir",
        control: "slider"
      }
    },
    wrap: {
      type: "int",
      default: 0,
      uniform: "wrap",
      choices: {
        Clamp: 2,
        Mirror: 0,
        Repeat: 1
      },
      ui: {
        label: "wrap",
        control: "dropdown"
      }
    }
  };

  passes = [
    {
      name: "render",
      program: "refract",
      inputs: {
        inputTex: "inputTex"
      },

      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
