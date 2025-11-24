import { Effect } from '../../../src/runtime/effect.js';

export default class CellRefract extends Effect {
  name = "CellRefract";
  namespace = "nd";
  func = "cell_refract";

  globals = {
    metric: {
      type: "int",
      default: 1,
      choices: {
        Circle: 0,
        Diamond: 1,
        Hexagon: 2,
        Octagon: 3,
        Square: 4,
        Triangle: 6
      },
      ui: {
        label: "metric",
        control: "dropdown"
      }
    },
    scale: {
      type: "float",
      default: 50,
      min: 1,
      max: 100,
      ui: {
        label: "scale",
        control: "slider"
      }
    },
    cellScale: {
      type: "float",
      default: 75,
      min: 1,
      max: 100,
      ui: {
        label: "cell scale",
        control: "slider"
      }
    },
    cellSmooth: {
      type: "float",
      default: 0,
      min: 0,
      max: 100,
      ui: {
        label: "cell smooth",
        control: "slider"
      }
    },
    cellVariation: {
      type: "float",
      default: 0,
      min: 0,
      max: 100,
      ui: {
        label: "cell variation",
        control: "slider"
      }
    },
    loopAmp: {
      type: "int",
      default: 1,
      min: 0,
      max: 5,
      ui: {
        label: "speed",
        control: "slider"
      }
    },
    kernel: {
      type: "int",
      default: 0,
      choices: {
        None: 0,
        Blur: 1,
        Derivatives: 120,
        "Deriv+divide": 2,
        Edge: 3,
        Emboss: 4,
        "Lit Edge": 9,
        Outline: 5,
        Pixels: 100,
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
      type: "int",
      default: 0,
      min: 0,
      max: 10,
      ui: {
        label: "effect width",
        control: "slider"
      }
    },
    refractAmt: {
      type: "float",
      default: 23,
      min: 0,
      max: 100,
      ui: {
        label: "refract",
        control: "slider"
      }
    },
    refractDir: {
      type: "float",
      default: 0,
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
      choices: {
        Mirror: 0,
        Repeat: 1
      },
      ui: {
        label: "wrap",
        control: "dropdown"
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
    }
  };

  passes = [
    {
      name: "render",
      type: "render",
      program: "cell-refract",
      inputs: {
        inputTex: "inputTex"
      },

      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
