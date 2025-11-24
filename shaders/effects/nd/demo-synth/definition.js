import { Effect } from '../../../src/runtime/effect.js';

export default class DemoSynth extends Effect {
  name = "DemoSynth";
  namespace = "nd";
  func = "demo_synth";

  globals = {
    scale: {
      type: "float",
      default: 25,
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
