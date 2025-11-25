import { Effect } from '../../../src/runtime/effect.js';
import { stdEnums } from '../../../src/lang/std_enums.js';

const paletteChoices = {};
for (const [key, val] of Object.entries(stdEnums.palette)) {
  paletteChoices[key] = val.value;
}

export default class Fractal extends Effect {
  name = "Fractal";
  namespace = "nd";
  func = "fractal";

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
    fractalType: {
      type: "int",
      default: 0,
      choices: {
        Julia: 0,
        Mandelbrot: 2,
        Newton: 1
      },
      ui: {
        label: "type",
        control: "dropdown"
      }
    },
    symmetry: {
      type: "int",
      default: 0,
      ui: {
        label: "symmetry",
        control: "slider"
      }
    },
    zoomAmt: {
      type: "float",
      default: 0,
      min: 0,
      max: 130,
      ui: {
        label: "zoom",
        control: "slider"
      }
    },
    rotation: {
      type: "int",
      default: 0,
      min: -180,
      max: 180,
      ui: {
        label: "rotate",
        control: "slider"
      }
    },
    speed: {
      type: "float",
      default: 30,
      min: 0,
      max: 100,
      ui: {
        label: "speed",
        control: "slider"
      }
    },
    offsetX: {
      type: "float",
      default: 70,
      min: -100,
      max: 100,
      ui: {
        label: "offset x",
        control: "slider"
      }
    },
    offsetY: {
      type: "float",
      default: 50,
      min: -100,
      max: 100,
      ui: {
        label: "offset y",
        control: "slider"
      }
    },
    centerX: {
      type: "float",
      default: 0,
      min: -100,
      max: 100,
      ui: {
        label: "center x",
        control: "slider"
      }
    },
    centerY: {
      type: "float",
      default: 0,
      min: -100,
      max: 100,
      ui: {
        label: "center y",
        control: "slider"
      }
    },
    mode: {
      type: "int",
      default: 0,
      choices: {
        Iter: 0,
        Z: 1
      },
      ui: {
        label: "mode",
        control: "dropdown"
      }
    },
    iterations: {
      type: "int",
      default: 50,
      min: 1,
      max: 50,
      ui: {
        label: "iterations",
        control: "slider"
      }
    },
    colorMode: {
      type: "int",
      default: 4,
      choices: {
        Grayscale: 0,
        Palette: 4,
        Hsv: 6
      },
      ui: {
        label: "color space",
        control: "dropdown"
      }
    },
    palette: {
      type: "palette",
      default: 12,
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
      default: [0.5, 0.5, 0.5],
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
      default: [0, 0, 0],
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
    hueRange: {
      type: "float",
      default: 100,
      min: 1,
      max: 100,
      ui: {
        label: "hue range",
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
    backgroundColor: {
      type: "vec3",
      default: [0.0, 0.0, 0.0],
      ui: {
        label: "bkg color",
        control: "color"
      }
    },
    backgroundOpacity: {
      type: "float",
      default: 100,
      min: 0,
      max: 100,
      ui: {
        label: "bkg opacity",
        control: "slider"
      }
    },
    cutoff: {
      type: "float",
      default: 0,
      min: 0,
      max: 100,
      ui: {
        label: "cutoff",
        control: "slider"
      }
    }
  };

  passes = [
    {
      name: "render",
      type: "render",
      program: "fractal",
      inputs: {
      },

      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
