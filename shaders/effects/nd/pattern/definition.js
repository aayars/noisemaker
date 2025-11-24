import { Effect } from '../../../src/runtime/effect.js';

export default class Pattern extends Effect {
  name = "Pattern";
  namespace = "nd";
  func = "pattern_nd";

  globals = {
    patternType: {
      type: "int",
      default: 1,
      choices: {
        Checkers: 0,
        Dots: 1,
        Grid: 2,
        Hearts: 3,
        Hexagons: 4,
        Rings: 5,
        Squares: 6,
        Stripes: 7,
        Waves: 8,
        Zigzag: 9,
        "Truchet Lines": 10,
        "Truchet Curves": 11
      },
      ui: {
        label: "pattern",
        control: "dropdown"
      }
    },
    scale: {
      type: "float",
      default: 80,
      min: 1,
      max: 100,
      ui: {
        label: "scale",
        control: "slider"
      }
    },
    skewAmt: {
      type: "float",
      default: 0,
      min: -100,
      max: 100,
      ui: {
        label: "skew",
        control: "slider"
      }
    },
    rotation: {
      type: "int",
      default: 0,
      min: -180,
      max: 180,
      ui: {
        label: "rotate",
        control: "slider"
      }
    },
    lineWidth: {
      type: "float",
      default: 100,
      min: 1,
      max: 100,
      ui: {
        label: "width",
        control: "slider"
      }
    },
    seed: {
      type: "int",
      default: 1,
      min: 1,
      max: 100,
      ui: {
        label: "truchet seed",
        control: "slider"
      }
    },
    animation: {
      type: "int",
      default: 0,
      choices: {
        None: 0,
        "Pan With Rotation": 1,
        "Pan Left": 2,
        "Pan Right": 3,
        "Pan Up": 4,
        "Pan Down": 5,
        "Rotate Cw": 6,
        "Rotate Ccw": 7
      },
      ui: {
        label: "animation",
        control: "dropdown"
      }
    },
    speed: {
      type: "int",
      default: 1,
      min: 0,
      max: 10,
      ui: {
        label: "speed",
        control: "slider"
      }
    },
    sharpness: {
      type: "float",
      default: 100,
      min: 0,
      max: 100,
      ui: {
        label: "sharpness",
        control: "slider"
      }
    },
    color1: {
      type: "vec3",
      default: [1.0, 0.9176470588235294, 0.19215686274509805],
      ui: {
        label: "color 1",
        control: "color"
      }
    },
    color2: {
      type: "vec3",
      default: [0.0, 0.0, 0.0],
      ui: {
        label: "color 2",
        control: "color"
      }
    }
  };

  passes = [
    {
      name: "render",
      type: "render",
      program: "pattern",
      inputs: {
      },

      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
