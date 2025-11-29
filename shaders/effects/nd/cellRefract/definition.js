import { Effect } from '../../../src/runtime/effect.js';

export default class CellRefract extends Effect {
  name = "CellRefract";
  namespace = "nd";
  func = "cellRefract";

  globals = {
    metric: {
      type: "int",
      default: 1,
      uniform: "metric",
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
      uniform: "scale",
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
      uniform: "cellScale",
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
      uniform: "cellSmooth",
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
      uniform: "cellVariation",
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
      uniform: "loopAmp",
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
      uniform: "kernel",
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
      uniform: "effectWidth",
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
      uniform: "refractAmt",
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
      uniform: "seed",
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
      program: "cellRefract",
      inputs: {
        inputTex: "inputTex"
      },

      outputs: {
        fragColor: "outputTex"
      }
    }
  ];
}
