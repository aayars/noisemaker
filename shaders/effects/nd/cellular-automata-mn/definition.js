import { Effect } from '../../../src/runtime/effect.js';
import { stdEnums } from '../../../src/lang/std_enums.js';

const paletteChoices = {};
for (const [key, val] of Object.entries(stdEnums.palette)) {
  paletteChoices[key] = val.value;
}

export default class CellularAutomataMN extends Effect {
  name = "CellularAutomataMn";
  namespace = "nd";
  func = "cellular_automata_mn";

  textures = {
    _feedbackBuffer: {
      width: { scale: 1 },
      height: { scale: 1 },
      format: "rgba16f",
      usage: ["render", "sample"],
      persistent: true
    }
  };

  globals = {
    zoom: {
      type: "int",
      default: 8,
      choices: {
        "1x": 1,
        "2x": 2,
        "4x": 4,
        "8x": 8,
        "16x": 16,
        "32x": 32,
        "64x": 64
      },
      ui: {
        label: "zoom",
        control: "dropdown"
      }
    },
    seed: {
      type: "float",
      default: 1,
      min: 1,
      max: 100,
      ui: {
        label: "seed",
        control: "slider"
      }
    },
    smoothing: {
      type: "int",
      default: 0,
      choices: {
        Constant: 0,
        Linear: 1,
        Hermite: 2,
        "Catmull Rom 3x3": 3,
        "Catmull Rom 4x4": 4,
        "B Spline 3x3": 5,
        "B Spline 4x4": 6
      },
      ui: {
        label: "smoothing",
        control: "dropdown"
      }
    },
    colorMode: {
      type: "int",
      default: 0,
      choices: {
        Grayscale: 0,
        Palette: 4
      },
      ui: {
        label: "color mode",
        control: "dropdown"
      }
    },
    palette: {
      type: "palette",
      default: 2,
      choices: paletteChoices,
      ui: {
        label: "palette",
        control: "dropdown"
      }
    },
    paletteMode: {
      type: "int",
      default: 0,
      ui: {
        control: false
      }
    },
    cyclePalette: {
      type: "int",
      default: 0,
      choices: {
        Off: 0,
        Forward: 1,
        Backward: -1
      },
      ui: {
        label: "cycle palette",
        control: "dropdown"
      }
    },
    rotatePalette: {
      type: "float",
      default: 0,
      min: 0,
      max: 100,
      ui: {
        label: "rotate palette",
        control: "slider"
      }
    },
    repeatPalette: {
      type: "int",
      default: 1,
      min: 1,
      max: 5,
      ui: {
        label: "repeat palette",
        control: "slider"
      }
    },
    paletteOffset: {
      type: "vec3",
      default: [0.83, 0.6, 0.63],
      ui: {
        label: "palette offset",
        control: "slider"
      }
    },
    paletteAmp: {
      type: "vec3",
      default: [0.5, 0.5, 0.5],
      ui: {
        label: "palette amplitude",
        control: "slider"
      }
    },
    paletteFreq: {
      type: "vec3",
      default: [1, 1, 1],
      ui: {
        label: "palette frequency",
        control: "slider"
      }
    },
    palettePhase: {
      type: "vec3",
      default: [0.3, 0.1, 0],
      ui: {
        label: "palette phase",
        control: "slider"
      }
    }
  };

  passes = [
    {
      name: "update",
      type: "render",
      program: "cellular-automata-mn-fb",
      inputs: {
        bufTex: "_feedbackBuffer",
        seedTex: "inputTex"
      },
      outputs: {
        fragColor: "_feedbackBuffer"
      }
    },
    {
      name: "render",
      type: "render",
      program: "cellular-automata-mn",
      inputs: {
        fbTex: "_feedbackBuffer",
        prevFrameTex: "_feedbackBuffer",
        bufTex: "_feedbackBuffer",
        inputTex: "inputTex"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
