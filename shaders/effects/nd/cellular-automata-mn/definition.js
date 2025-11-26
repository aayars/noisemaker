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

  textures = {};

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
      },
      uniform: "seed"
    },
    resetState: {
      type: "boolean",
      default: false,
      ui: {
        control: "button",
        buttonLabel: "reset",
        category: "control"
      },
      uniform: "resetState"
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
      },
      uniform: "smoothing"
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
      },
      uniform: "colorMode"
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
      },
      uniform: "paletteMode"
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
      },
      uniform: "cyclePalette"
    },
    rotatePalette: {
      type: "float",
      default: 0,
      min: 0,
      max: 100,
      ui: {
        label: "rotate palette",
        control: "slider"
      },
      uniform: "rotatePalette"
    },
    repeatPalette: {
      type: "int",
      default: 1,
      min: 1,
      max: 5,
      ui: {
        label: "repeat palette",
        control: "slider"
      },
      uniform: "repeatPalette"
    },
    paletteOffset: {
      type: "vec3",
      default: [0.83, 0.6, 0.63],
      ui: {
        label: "palette offset",
        control: "slider"
      },
      uniform: "paletteOffset"
    },
    paletteAmp: {
      type: "vec3",
      default: [0.5, 0.5, 0.5],
      ui: {
        label: "palette amplitude",
        control: "slider"
      },
      uniform: "paletteAmp"
    },
    paletteFreq: {
      type: "vec3",
      default: [1, 1, 1],
      ui: {
        label: "palette frequency",
        control: "slider"
      },
      uniform: "paletteFreq"
    },
    palettePhase: {
      type: "vec3",
      default: [0.3, 0.1, 0],
      ui: {
        label: "palette phase",
        control: "slider"
      },
      uniform: "palettePhase"
    },
    speed: {
      type: "float",
      default: 10,
      min: 1,
      max: 100,
      ui: {
        label: "speed",
        control: "slider"
      },
      uniform: "speed"
    },
    weight: {
      type: "float",
      default: 0,
      min: 0,
      max: 100,
      ui: {
        label: "input weight",
        control: "slider"
      },
      uniform: "weight"
    },
    n1v1: {
      type: "float",
      default: 21,
      min: 0,
      max: 100,
      ui: {
        label: "n1 thresh 1",
        control: "slider"
      },
      uniform: "n1v1"
    },
    n1r1: {
      type: "float",
      default: 1,
      min: 0,
      max: 100,
      ui: {
        label: "n1 range 1",
        control: "slider"
      },
      uniform: "n1r1"
    },
    n1v2: {
      type: "float",
      default: 35,
      min: 0,
      max: 100,
      ui: {
        label: "n1 thresh 2",
        control: "slider"
      },
      uniform: "n1v2"
    },
    n1r2: {
      type: "float",
      default: 15,
      min: 0,
      max: 100,
      ui: {
        label: "n1 range 2",
        control: "slider"
      },
      uniform: "n1r2"
    },
    n1v3: {
      type: "float",
      default: 75,
      min: 0,
      max: 100,
      ui: {
        label: "n1 thresh 3",
        control: "slider"
      },
      uniform: "n1v3"
    },
    n1r3: {
      type: "float",
      default: 10,
      min: 0,
      max: 100,
      ui: {
        label: "n1 range 3",
        control: "slider"
      },
      uniform: "n1r3"
    },
    n1v4: {
      type: "float",
      default: 12,
      min: 0,
      max: 100,
      ui: {
        label: "n1 thresh 4",
        control: "slider"
      },
      uniform: "n1v4"
    },
    n1r4: {
      type: "float",
      default: 3,
      min: 0,
      max: 100,
      ui: {
        label: "n1 range 4",
        control: "slider"
      },
      uniform: "n1r4"
    },
    n2v1: {
      type: "float",
      default: 10,
      min: 0,
      max: 100,
      ui: {
        label: "n2 thresh 1",
        control: "slider"
      },
      uniform: "n2v1"
    },
    n2r1: {
      type: "float",
      default: 18,
      min: 0,
      max: 100,
      ui: {
        label: "n2 range 1",
        control: "slider"
      },
      uniform: "n2r1"
    },
    n2v2: {
      type: "float",
      default: 43,
      min: 0,
      max: 100,
      ui: {
        label: "n2 thresh 2",
        control: "slider"
      },
      uniform: "n2v2"
    },
    n2r2: {
      type: "float",
      default: 12,
      min: 0,
      max: 100,
      ui: {
        label: "n2 range 2",
        control: "slider"
      },
      uniform: "n2r2"
    },
    source: {
      type: "int",
      default: 0,
      min: 0,
      max: 7,
      ui: {
        control: false
      },
      uniform: "source"
    },
  };

  passes = [
    {
      name: "update",
      type: "compute",  // GPGPU: cellular automata MN state update
      program: "cellular-automata-mn-fb",
      inputs: {
        bufTex: "global_ca_mn_state",
        seedTex: "inputTex"
      },
      outputs: {
        fragColor: "global_ca_mn_state"
      }
    },
    {
      name: "render",
      type: "render",
      program: "cellular-automata-mn",
      inputs: {
        fbTex: "global_ca_mn_state",
        prevFrameTex: "global_ca_mn_state",
        bufTex: "global_ca_mn_state",
        inputTex: "inputTex"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
