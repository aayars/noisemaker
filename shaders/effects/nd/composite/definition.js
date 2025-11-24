import { Effect } from '../../../src/runtime/effect.js';

export default class Composite extends Effect {
  name = "Composite";
  namespace = "nd";
  func = "composite";

  globals = {
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
    blendMode: {
      type: "int",
      default: 1,
      choices: {
        "Color Splash": 0,
        "Greenscreen A > B": 1,
        "Greenscreen B > A": 2,
        "A > B Black": 3,
        "A > B Color Black": 4,
        "A > B Hue": 5,
        "A > B Saturation": 6,
        "A > B Value": 7,
        "B > A Black": 8,
        "B > A Color Black": 9,
        "B > A Hue": 10,
        "B > A Saturation": 11,
        "B > A Value": 12,
        Mix: 13,
        Psychedelic: 14,
        "Psychedelic 2": 15
      },
      ui: {
        label: "mode",
        control: "dropdown"
      }
    },
    inputColor: {
      type: "vec4",
      default: [0.0, 0.0, 0.0, 1.0],
      ui: {
        label: "color",
        control: "color"
      }
    },
    range: {
      type: "float",
      default: 20,
      min: 0,
      max: 100,
      ui: {
        label: "range",
        control: "slider"
      }
    },
    mixAmt: {
      type: "float",
      default: 50,
      min: 0,
      max: 100,
      ui: {
        label: "mix",
        control: "slider"
      }
    }
  };

  passes = [
    {
      name: "render",
      type: "render",
      program: "composite",
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
