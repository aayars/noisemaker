import { Effect } from '../../../src/runtime/effect.js';
import { stdEnums } from '../../../src/lang/std_enums.js';

const paletteChoices = {};
for (const [key, val] of Object.entries(stdEnums.palette)) {
  paletteChoices[key] = val.value;
}

export default class ShapeMixer extends Effect {
  name = "ShapeMixer";
  namespace = "nd";
  func = "shapeMixer";

  globals = {
    blendMode: {
      type: "int",
      default: 2,
      uniform: "blendMode",
      choices: {
        Add: 0,
        Divide: 1,
        Max: 2,
        Min: 3,
        Mix: 4,
        Mod: 5,
        Multiply: 6,
        Reflect: 7,
        Refract: 8,
        Subtract: 9
      },
      ui: {
        label: "mode",
        control: "dropdown"
      }
    },
    loopOffset: {
      type: "int",
      default: 10,
      uniform: "loopOffset",
      choices: {
        None: 0,
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
        label: "shape",
        control: "dropdown"
      }
    },
    loopScale: {
      type: "float",
      default: 80,
      uniform: "loopScale",
      min: 1,
      max: 100,
      ui: {
        label: "shape scale",
        control: "slider"
      }
    },
    animate: {
      type: "int",
      default: 1,
      uniform: "animate",
      choices: {
        Off: 0,
        Forward: 1,
        Backward: -1
      },
      ui: {
        label: "animate",
        control: "dropdown"
      }
    },
    palette: {
      type: "palette",
      default: 41,
      uniform: "palette",
      choices: paletteChoices,
      ui: {
        label: "palette",
        control: "dropdown"
      }
    },
    paletteMode: {
      type: "int",
      default: 0,
      uniform: "paletteMode",
      ui: {
        control: false
      }
    },
    paletteOffset: {
      type: "vec3",
      default: [0.83, 0.6, 0.63],
      uniform: "paletteOffset",
      ui: {
        label: "palette offset",
        control: "slider"
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
    paletteFreq: {
      type: "vec3",
      default: [1, 1, 1],
      uniform: "paletteFreq",
      ui: {
        label: "palette frequency",
        control: "slider"
      }
    },
    palettePhase: {
      type: "vec3",
      default: [0.3, 0.1, 0],
      uniform: "palettePhase",
      ui: {
        label: "palette phase",
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
    levels: {
      type: "int",
      default: 0,
      uniform: "levels",
      min: 0,
      max: 32,
      ui: {
        label: "posterize",
        control: "slider"
      }
    },
    wrap: {
      type: "boolean",
      default: true,
      uniform: "wrap",
      ui: {
        label: "noise wrap",
        control: "checkbox"
      }
    },
    seed: {
      type: "int",
      default: 1,
      uniform: "seed",
      min: 1,
      max: 100,
      ui: {
        label: "noise seed",
        control: "slider"
      }
    }
  };

  passes = [
    {
      name: "render",
      program: "shapeMixer",
      inputs: {
              tex0: "inputTex",
              tex1: "inputTex"
            }
,
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
