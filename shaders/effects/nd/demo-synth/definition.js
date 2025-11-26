import { Effect } from '../../../src/runtime/effect.js';

export default class DemoSynth extends Effect {
  name = "DemoSynth";
  namespace = "nd";
  func = "demo_synth";

  globals = {
    scale: {
      type: "float",
      default: 25,
      uniform: "scale",
      min: 1,
      max: 100,
      ui: {
        label: "scale",
        control: "slider"
      }
    },
    offset: {
      type: "float",
      default: 0,
      uniform: "offset",
      min: -1000,
      max: 1000,
      ui: {
        label: "offset",
        control: "slider"
      }
    },
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
    octaves: {
      type: "int",
      default: 5,
      uniform: "octaves",
      min: 1,
      max: 10,
      ui: {
        label: "octaves",
        control: "slider"
      }
    },
    colorMode: {
      type: "int",
      default: 0,
      uniform: "colorMode",
      choices: {
        Mono: 0,
        Rgb: 1,
        Hsv: 2
      },
      ui: {
        label: "color mode",
        control: "dropdown"
      }
    },
    hueRotation: {
      type: "float",
      default: 0,
      uniform: "hueRotation",
      min: 0,
      max: 360,
      ui: {
        label: "hue rotate",
        control: "slider"
      }
    },
    hueRange: {
      type: "float",
      default: 100,
      uniform: "hueRange",
      min: 0,
      max: 100,
      ui: {
        label: "hue range",
        control: "slider"
      }
    },
    ridged: {
      type: "boolean",
      default: false,
      uniform: "ridged",
      ui: {
        label: "ridged",
        control: "checkbox"
      }
    }
  };

  passes = [
    {
      name: "render",
      type: "render",
      program: "demo-synth",
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
