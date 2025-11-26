import { Effect } from '../../../src/runtime/effect.js';

export default class Kaleido extends Effect {
  name = "Kaleido";
  namespace = "nd";
  func = "kaleido";

  globals = {
    kaleido: {
      type: "int",
      default: 8,
      uniform: "kaleido",
      min: 2,
      max: 32,
      ui: {
        label: "sides",
        control: "slider"
      }
    },
    metric: {
      type: "int",
      default: 0,
      uniform: "metric",
      choices: {
        Circle: 0,
        Diamond: 1,
        Hexagon: 2,
        Octagon: 3,
        Square: 4,
        Triangle: 5
      },
      ui: {
        label: "shape",
        control: "dropdown"
      }
    },
    direction: {
      type: "int",
      default: 2,
      uniform: "direction",
      choices: {
        Clockwise: 0,
        Counterclock: 1,
        None: 2
      },
      ui: {
        label: "rotate",
        control: "dropdown"
      }
    },
    loopOffset: {
      type: "int",
      default: 10,
      uniform: "loopOffset",
      choices: {
        "Shapes:": null,
        Circle: 10,
        Triangle: 20,
        Diamond: 30,
        Square: 40,
        Pentagon: 50,
        Hexagon: 60,
        Heptagon: 70,
        Octagon: 80,
        Nonagon: 90,
        Decagon: 100,
        Hendecagon: 110,
        Dodecagon: 120,
        "Directional:": null,
        "Horizontal Scan": 200,
        "Vertical Scan": 210,
        "Noise:": null,
        "Noise Constant": 300,
        "Noise Linear": 310,
        "Noise Hermite": 320,
        "Noise Catmull Rom 3x3": 330,
        "Noise Catmull Rom 4x4": 340,
        "Noise B Spline 3x3": 350,
        "Noise B Spline 4x4": 360,
        "Noise Simplex": 370,
        "Noise Sine": 380,
        "Misc:": null,
        Rings: 400,
        Sine: 410
      },
      ui: {
        label: "loop offset",
        control: "dropdown"
      }
    },
    loopScale: {
      type: "float",
      default: 1,
      uniform: "loopScale",
      min: 1,
      max: 100,
      ui: {
        label: "loop scale",
        control: "slider"
      }
    },
    loopAmp: {
      type: "float",
      default: 5,
      uniform: "loopAmp",
      min: -100,
      max: 100,
      ui: {
        label: "loop power",
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
    wrap: {
      type: "boolean",
      default: true,
      uniform: "wrap",
      ui: {
        label: "wrap",
        control: "checkbox"
      }
    },
    kernel: {
      type: "int",
      default: 0,
      uniform: "kernel",
      choices: {
        None: 0,
        Blur: 1,
        Derivatives: 120,
        "Deriv+divide": 2,
        Edge: 3,
        Emboss: 4,
        Outline: 5,
        Pixels: 10,
        Posterize: 110,
        Shadow: 6,
        Sharpen: 7,
        Sobel: 8
      },
      ui: {
        label: "effect",
        control: "dropdown"
      }
    },
    effectWidth: {
      type: "float",
      default: 0,
      uniform: "effectWidth",
      min: 0,
      max: 10,
      ui: {
        label: "effect width",
        control: "slider"
      }
    }
  };

  passes = [
    {
      name: "render",
      program: "kaleido",
      inputs: {
        inputTex: "inputTex"
      },

      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
