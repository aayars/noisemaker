import { Effect } from '../../../src/runtime/effect.js';

export default class Palette extends Effect {
  name = "Palette";
  namespace = "nd";
  func = "palette_nd";

  globals = {
    paletteType: {
      type: "int",
      default: 0,
      choices: {
        Cosine: 0,
        "Five Color": 1
      },
      ui: {
        label: "palette type",
        control: "dropdown"
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
    freq: {
      type: "int",
      default: 1,
      min: 1,
      max: 4,
      ui: {
        label: "repeat palette",
        control: "slider"
      }
    },
    color1: {
      type: "vec4",
      default: [1.0, 0.0, 0.0, 1.0],
      ui: {
        label: "color 1",
        control: "color"
      }
    },
    color2: {
      type: "vec4",
      default: [1.0, 1.0, 0.0, 1.0],
      ui: {
        label: "color 2",
        control: "color"
      }
    },
    color3: {
      type: "vec4",
      default: [0.0, 1.0, 0.0, 1.0],
      ui: {
        label: "color 3",
        control: "color"
      }
    },
    color4: {
      type: "vec4",
      default: [0.0, 1.0, 1.0, 1.0],
      ui: {
        label: "color 4",
        control: "color"
      }
    },
    color5: {
      type: "vec4",
      default: [0.0, 0.0, 1.0, 1.0],
      ui: {
        label: "color 5",
        control: "color"
      }
    },
    tint: {
      type: "vec4",
      default: [1.0, 1.0, 1.0, 1.0],
      ui: {
        label: "tint",
        control: "color"
      }
    },
    smoother: {
      type: "boolean",
      default: true,
      ui: {
        label: "smoother",
        control: "checkbox"
      }
    },
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
    offsetR: {
      type: "float",
      default: 50,
      min: 0,
      max: 100,
      ui: {
        label: "offset R",
        control: "slider"
      }
    },
    phaseR: {
      type: "float",
      default: 0,
      min: 0,
      max: 100,
      ui: {
        label: "phase R",
        control: "slider"
      }
    },
    offsetG: {
      type: "float",
      default: 50,
      min: 0,
      max: 100,
      ui: {
        label: "offset G",
        control: "slider"
      }
    },
    phaseG: {
      type: "float",
      default: 33,
      min: 0,
      max: 100,
      ui: {
        label: "phase G",
        control: "slider"
      }
    },
    offsetB: {
      type: "float",
      default: 50,
      min: 0,
      max: 100,
      ui: {
        label: "offset B",
        control: "slider"
      }
    },
    phaseB: {
      type: "float",
      default: 67,
      min: 0,
      max: 100,
      ui: {
        label: "phase B",
        control: "slider"
      }
    },
    ampR: {
      type: "float",
      default: 50,
      min: 0,
      max: 100,
      ui: {
        label: "amp R",
        control: "slider"
      }
    },
    ampB: {
      type: "float",
      default: 50,
      min: 0,
      max: 100,
      ui: {
        label: "amp B",
        control: "slider"
      }
    },
    ampG: {
      type: "float",
      default: 50,
      min: 0,
      max: 100,
      ui: {
        label: "amp G",
        control: "slider"
      }
    },
    colorMode: {
      type: "int",
      default: 2,
      choices: {
        Hsv: 0,
        Oklab: 1,
        Rgb: 2
      },
      ui: {
        label: "mode",
        control: "dropdown"
      }
    }
  };

  passes = [
    {
      name: "render",
      type: "render",
      program: "palette",
      inputs: {
        src: "o0"
      },

      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
