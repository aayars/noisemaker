import { Effect } from '../../../src/runtime/effect.js';
import { stdEnums } from '../../../src/lang/std_enums.js';

const paletteChoices = {};
for (const [key, val] of Object.entries(stdEnums.palette)) {
  paletteChoices[key] = val.value;
}

export default class Noise extends Effect {
  name = "Noise";
  namespace = "nd";
  func = "noise";

  globals = {
    aspect: {
      type: "float",
      default: null,
      uniform: "aspect",
      ui: {
        label: "aspect",
        control: "slider"
      }
    },
    noiseType: {
      type: "int",
      default: 10,
      uniform: "noiseType",
      choices: {
        Constant: 0,
        Linear: 1,
        Hermite: 2,
        "Catmull Rom 3x3": 3,
        "Catmull Rom 4x4": 4,
        "B Spline 3x3": 5,
        "B Spline 4x4": 6,
        Simplex: 10,
        Sine: 11
      },
      ui: {
        label: "noise type",
        control: "dropdown"
      }
    },
    octaves: {
      type: "int",
      default: 2,
      uniform: "octaves",
      min: 1,
      max: 8,
      ui: {
        label: "octaves",
        control: "slider"
      }
    },
    xScale: {
      type: "float",
      default: 75,
      uniform: "xScale",
      min: 1,
      max: 100,
      ui: {
        label: "horiz scale",
        control: "slider"
      }
    },
    yScale: {
      type: "float",
      default: 75,
      uniform: "yScale",
      min: 1,
      max: 100,
      ui: {
        label: "vert scale",
        control: "slider"
      }
    },
    ridges: {
      type: "boolean",
      default: false,
      uniform: "ridges",
      ui: {
        label: "ridges",
        control: "checkbox"
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
    refractMode: {
      type: "int",
      default: 2,
      uniform: "refractMode",
      choices: {
        Color: 0,
        Topology: 1,
        "Color + Topology": 2
      },
      ui: {
        label: "refract mode",
        control: "dropdown"
      }
    },
    refractAmt: {
      type: "float",
      default: 0,
      uniform: "refractAmt",
      min: 0,
      max: 100,
      ui: {
        label: "refract",
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
    loopOffset: {
      type: "int",
      default: 300,
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
        "Misc:": null,
        Noise: 300,
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
      default: 75,
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
      default: 25,
      uniform: "loopAmp",
      min: -100,
      max: 100,
      ui: {
        label: "loop power",
        control: "slider"
      }
    },
    kaleido: {
      type: "int",
      default: 1,
      uniform: "kaleido",
      min: 1,
      max: 32,
      ui: {
        label: "kaleido sides",
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
        label: "kaleido shape",
        control: "dropdown"
      }
    },
    colorMode: {
      type: "int",
      default: 6,
      uniform: "colorMode",
      choices: {
        Grayscale: 0,
        "Linear Rgb": 1,
        Srgb: 2,
        Oklab: 3,
        Palette: 4,
        Hsv: 6
      },
      ui: {
        label: "color space",
        control: "dropdown"
      }
    },
    paletteMode: {
      type: "int",
      default: 3,
      uniform: "paletteMode",
      ui: {
        control: false
      }
    },
    hueRotation: {
      type: "float",
      default: 179,
      uniform: "hueRotation",
      min: 0,
      max: 360,
      ui: {
        label: "hue rotate",
        control: "slider"
      }
    },
    hueRange: {
      type: "float",
      default: 25,
      uniform: "hueRange",
      min: 0,
      max: 100,
      ui: {
        label: "hue range",
        control: "slider"
      }
    },
    palette: {
      type: "palette",
      default: 2,
      uniform: "palette",
      choices: paletteChoices,
      ui: {
        label: "palette",
        control: "dropdown"
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
    paletteOffset: {
      type: "vec3",
      default: [0.5, 0.5, 0.5],
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
      default: [0.3, 0.2, 0.2],
      uniform: "palettePhase",
      ui: {
        label: "palette phase",
        control: "slider"
      }
    }
  };

  passes = [
    {
      name: "render",
      program: "noise",
      inputs: {
      },

      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
