import { Effect } from '../../../src/runtime/effect.js';
import { stdEnums } from '../../../src/lang/std_enums.js';

const paletteChoices = {};
for (const [key, val] of Object.entries(stdEnums.palette)) {
  paletteChoices[key] = val.value;
}

export default class CellNoise extends Effect {
  name = "CellNoise";
  namespace = "nd";
  func = "cell_noise";

  globals = {
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
        Triangle: 6
      },
      ui: {
        label: "metric",
        control: "dropdown"
      }
    },
    scale: {
      type: "float",
      default: 75,
      uniform: "scale",
      min: 1,
      max: 100,
      ui: {
        label: "noise scale",
        control: "slider"
      }
    },
    cellScale: {
      type: "float",
      default: 87,
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
      default: 11,
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
      default: 50,
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
    paletteMode: {
      type: "int",
      default: 4,
      uniform: "paletteMode",
      ui: {
        control: false
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
    colorMode: {
      type: "int",
      default: 0,
      uniform: "colorMode",
      choices: {
        Grayscale: 0,
        "Grayscale Inverse": 1,
        Palette: 2
      },
      ui: {
        label: "color space",
        control: "dropdown"
      }
    },
    palette: {
      type: "palette",
      default: 32,
      uniform: "palette",
      choices: paletteChoices,
      ui: {
        label: "palette",
        control: "dropdown"
      }
    },
    paletteOffset: {
      type: "vec3",
      default: [0.5, 0.5, 0.5],
      uniform: "paletteOffset",
      ui: {
        label: "palette offset",
        control: "slider"
      }
    },
    cyclePalette: {
      type: "int",
      default: 1,
      uniform: "cyclePalette",
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
    paletteAmp: {
      type: "vec3",
      default: [0.5, 0.5, 0.5],
      uniform: "paletteAmp",
      ui: {
        label: "palette amplitude",
        control: "slider"
      }
    },
    rotatePalette: {
      type: "float",
      default: 0,
      uniform: "rotatePalette",
      min: 0,
      max: 100,
      ui: {
        label: "rotate palette",
        control: "slider"
      }
    },
    paletteFreq: {
      type: "vec3",
      default: [2, 2, 2],
      uniform: "paletteFreq",
      ui: {
        label: "palette frequency",
        control: "slider"
      }
    },
    repeatPalette: {
      type: "int",
      default: 1,
      uniform: "repeatPalette",
      min: 1,
      max: 5,
      ui: {
        label: "repeat palette",
        control: "slider"
      }
    },
    palettePhase: {
      type: "vec3",
      default: [1, 1, 1],
      uniform: "palettePhase",
      ui: {
        label: "palette phase",
        control: "slider"
      }
    },
    texSource: {
      type: "int",
      default: 0,
      uniform: "texSource",
      choices: {
        None: 0,
        Input: 3
      },
      ui: {
        label: "tex source",
        control: "dropdown"
      }
    },
    texInfluence: {
      type: "int",
      default: 1,
      uniform: "texInfluence",
      choices: {
        Warp: null,
        "Cell Scale": 1,
        "Noise Scale": 2,
        Combine: null,
        Add: 10,
        Divide: 11,
        Min: 12,
        Max: 13,
        Mod: 14,
        Multiply: 15,
        Subtract: 16
      },
      ui: {
        label: "influence",
        control: "dropdown"
      }
    },
    texIntensity: {
      type: "float",
      default: 100,
      uniform: "texIntensity",
      min: 0,
      max: 100,
      ui: {
        label: "intensity",
        control: "slider"
      }
    }
  };

  passes = [
    {
      name: "render",
      type: "render",
      program: "cell-noise",
      inputs: {
      },

      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
