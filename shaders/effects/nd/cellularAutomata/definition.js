import { Effect } from '../../../src/runtime/effect.js';
import { stdEnums } from '../../../src/lang/std_enums.js';

const paletteChoices = {};
for (const [key, val] of Object.entries(stdEnums.palette)) {
  paletteChoices[key] = val.value;
}

export default class CellularAutomata extends Effect {
  name = "CellularAutomata";
  namespace = "nd";
  func = "cellularAutomata";


  // WGSL uniform packing layouts (per-program for multi-pass effects)
  uniformLayouts = {
    cellularAutomata: {
      resolution: { slot: 0, components: 'xy' },
      time: { slot: 0, components: 'z' },
      smoothing: { slot: 1, components: 'y' },
      colorMode: { slot: 1, components: 'z' },
      paletteMode: { slot: 1, components: 'w' },
      cyclePalette: { slot: 2, components: 'x' },
      rotatePalette: { slot: 2, components: 'y' },
      repeatPalette: { slot: 2, components: 'z' },
      offset: { slot: 4, components: 'xyz' },
      amp: { slot: 5, components: 'xyz' },
      freq: { slot: 6, components: 'xyz' },
      phase: { slot: 7, components: 'xyz' }
    },
    cellularAutomataFb: {
      deltaTime: { slot: 0, components: 'y' },
      seed: { slot: 0, components: 'z' },
      resetState: { slot: 0, components: 'w' },
      ruleIndex: { slot: 1, components: 'x' },
      speed: { slot: 1, components: 'y' },
      weight: { slot: 1, components: 'z' },
      useCustom: { slot: 1, components: 'w' },
      bornMask0: { slot: 2, components: 'xyzw' },
      bornMask1: { slot: 3, components: 'xyzw' },
      bornMask2: { slot: 4, components: 'x' },
      surviveMask0: { slot: 4, components: 'yzw' },
      surviveMask1: { slot: 5, components: 'xyzw' },
      surviveMask2: { slot: 6, components: 'xy' },
      source: { slot: 6, components: 'z' }
    }
  };
  textures = {};

  globals = {
    zoom: {
      type: "int",
      default: 32,
      choices: {
        x1: 1,
        x2: 2,
        x4: 4,
        x8: 8,
        x16: 16,
        x32: 32,
        x64: 64
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
        mono: 0,
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
    ruleIndex: {
      type: "int",
      default: 0,
      choices: {
        "Classic Life": 0,
        Highlife: 1,
        Seeds: 2,
        Coral: 3,
        "Day & Night": 4,
        "Life Without Death": 5,
        Replicator: 6,
        Amoeba: 7,
        Maze: 8,
        "Glider Walk": 9,
        Diamoeba: 10,
        "2x2": 11,
        Morley: 12,
        Anneal: 13,
        "34 Life": 14,
        "Simple Replicator": 15,
        Waffles: 16,
        "Pond Life": 17
      },
      ui: {
        label: "rules",
        control: "dropdown"
      },
      uniform: "ruleIndex"
    },
    useCustom: {
      type: "boolean",
      default: false,
      ui: {
        label: "use custom",
        control: "checkbox"
      },
      uniform: "useCustom"
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
      program: "cellularAutomataFb",
      inputs: {
        bufTex: "globalCaState",
        seedTex: "inputTex"
      },
      outputs: {
        fragColor: "globalCaState"
      }
    },
    {
      name: "render",
      program: "cellularAutomata",
      inputs: {
        fbTex: "globalCaState",
        prevFrameTex: "globalCaState",
        bufTex: "globalCaState",
        inputTex: "inputTex"
      },
      outputs: {
        fragColor: "outputTex"
      }
    }
  ];
}
