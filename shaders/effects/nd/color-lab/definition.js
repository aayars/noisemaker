import { Effect } from '../../../src/runtime/effect.js';
import { stdEnums } from '../../../src/lang/std_enums.js';

const paletteChoices = {};
for (const [key, val] of Object.entries(stdEnums.palette)) {
  paletteChoices[key] = val.value;
}

export default class ColorLab extends Effect {
  name = "ColorLab";
  namespace = "nd";
  func = "color_lab";

  globals = {
    seed: {
      type: "int",
      default: 1,
      min: 1,
      max: 100,
      ui: {
        label: "seed",
        control: "slider"
      }
    },
    colorMode: {
      type: "int",
      default: 2,
      choices: {
        Grayscale: 0,
        "Linear Rgb": 1,
        "Srgb (default)": 2,
        Oklab: 3,
        Palette: 4
      },
      ui: {
        label: "color space",
        control: "dropdown"
      }
    },
    palette: {
      type: "palette",
      default: 46,
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
    },
    cyclePalette: {
      type: "int",
      default: 1,
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
    hueRotation: {
      type: "float",
      default: 0,
      min: 0,
      max: 360,
      ui: {
        label: "hue rotate",
        control: "slider"
      }
    },
    hueRange: {
      type: "float",
      default: 100,
      min: 0,
      max: 200,
      ui: {
        label: "hue range",
        control: "slider"
      }
    },
    saturation: {
      type: "float",
      default: 0,
      min: -100,
      max: 100,
      ui: {
        label: "saturation",
        control: "slider"
      }
    },
    invert: {
      type: "boolean",
      default: false,
      ui: {
        label: "invert",
        control: "checkbox"
      }
    },
    brightness: {
      type: "int",
      default: 0,
      min: -100,
      max: 100,
      ui: {
        label: "brightness",
        control: "slider"
      }
    },
    contrast: {
      type: "int",
      default: 50,
      min: 0,
      max: 100,
      ui: {
        label: "contrast",
        control: "slider"
      }
    },
    levels: {
      type: "int",
      default: 0,
      min: 0,
      max: 32,
      ui: {
        label: "posterize",
        control: "slider"
      }
    },
    dither: {
      type: "int",
      default: 0,
      choices: {
        None: 0,
        Threshold: 1,
        Random: 2,
        "Random + Time": 3,
        Bayer: 4
      },
      ui: {
        label: "dither",
        control: "dropdown"
      }
    }
  };

  passes = [
    {
      name: "render",
      type: "render",
      program: "color-lab",
      inputs: {
        inputTex: "inputTex"
      },

      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
