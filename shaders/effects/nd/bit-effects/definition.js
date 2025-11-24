import { Effect } from '../../../src/runtime/effect.js';

export default class BitEffects extends Effect {
  name = "BitEffects";
  namespace = "nd";
  func = "bit_effects";

  globals = {
    mode: {
      type: "int",
      default: 1,
      choices: {
        "Bit Field": 0,
        "Bit Mask": 1
      },
      ui: {
        label: "mode",
        control: "dropdown"
      }
    },
    loopAmp: {
      type: "float",
      default: 50,
      min: 0,
      max: 100,
      ui: {
        label: "speed",
        control: "slider"
      }
    },
    formula: {
      type: "int",
      default: 0,
      choices: {
        Alien: 0,
        Sierpinski: 1
      },
      ui: {
        label: "formula",
        control: "dropdown"
      }
    },
    n: {
      type: "int",
      default: 1,
      min: 1,
      max: 200,
      ui: {
        label: "mod",
        control: "slider"
      }
    },
    colorScheme: {
      type: "int",
      default: 20,
      choices: {
        Blue: 0,
        Cyan: 1,
        Green: 2,
        Magenta: 3,
        Red: 4,
        White: 5,
        Yellow: 6,
        "Blue And Green": 10,
        "Blue And Red": 11,
        "Blue And Yellow": 12,
        "Green And Magenta": 13,
        "Green And Red": 14,
        "Red And Cyan": 15,
        "Red, Green, And Blue": 20
      },
      ui: {
        label: "colors",
        control: "dropdown"
      }
    },
    interp: {
      type: "int",
      default: 0,
      choices: {
        Constant: 0,
        Linear: 1
      },
      ui: {
        label: "blend",
        control: "dropdown"
      }
    },
    scale: {
      type: "float",
      default: 75,
      min: 1,
      max: 100,
      ui: {
        label: "scale",
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
    maskFormula: {
      type: "int",
      default: 10,
      choices: {
        Invaders: 10,
        "Wide Invaders": 11,
        Glyphs: 20,
        "Arecibo Number": 30
      },
      ui: {
        label: "formula",
        control: "dropdown"
      }
    },
    tiles: {
      type: "int",
      default: 5,
      min: 1,
      max: 40,
      ui: {
        label: "tiles",
        control: "slider"
      }
    },
    complexity: {
      type: "float",
      default: 57,
      min: 1,
      max: 100,
      ui: {
        label: "complexity",
        control: "slider"
      }
    },
    maskColorScheme: {
      type: "int",
      default: 1,
      choices: {
        "Black & White": 0,
        "Just Hue": 3,
        "Hue & Saturation": 2,
        Hsv: 1
      },
      ui: {
        label: "color space",
        control: "dropdown"
      }
    },
    baseHueRange: {
      type: "float",
      default: 50,
      min: 0,
      max: 100,
      ui: {
        label: "hue variants",
        control: "slider"
      }
    },
    hueRotation: {
      type: "float",
      default: 180,
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
      min: 0,
      max: 100,
      ui: {
        label: "hue range",
        control: "slider"
      }
    },
    seed: {
      type: "int",
      default: 63,
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
      program: "bit-effects",
      inputs: {
      },

      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
