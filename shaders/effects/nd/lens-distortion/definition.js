import { Effect } from '../../../src/runtime/effect.js';

export default class LensDistortion extends Effect {
  name = "LensDistortion";
  namespace = "nd";
  func = "lens_distortion";

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
    shape: {
      type: "int",
      default: 0,
      choices: {
        Circle: 0,
        Cosine: 10,
        Diamond: 1,
        Hexagon: 2,
        Octagon: 3,
        Square: 4,
        Triangle: 6
      },
      ui: {
        label: "shape",
        control: "dropdown"
      }
    },
    distortion: {
      type: "float",
      default: 0,
      min: -100,
      max: 100,
      ui: {
        label: "distortion",
        control: "slider"
      }
    },
    loopScale: {
      type: "float",
      default: 100,
      min: 1,
      max: 100,
      ui: {
        label: "loop scale",
        control: "slider"
      }
    },
    loopAmp: {
      type: "float",
      default: 0,
      min: -100,
      max: 100,
      ui: {
        label: "loop power",
        control: "slider"
      }
    },
    aspectLens: {
      type: "boolean",
      default: false,
      ui: {
        label: "1:1 aspect",
        control: "checkbox"
      }
    },
    mode: {
      type: "int",
      default: 0,
      choices: {
        "Chromatic (rgb)": 0,
        "Prismatic (hsv)": 1
      },
      ui: {
        label: "mode",
        control: "dropdown"
      }
    },
    aberrationAmt: {
      type: "float",
      default: 50,
      min: 0,
      max: 100,
      ui: {
        label: "aberration",
        control: "slider"
      }
    },
    blendMode: {
      type: "int",
      default: 0,
      choices: {
        Add: 0,
        Alpha: 1
      },
      ui: {
        label: "blend",
        control: "dropdown"
      }
    },
    modulate: {
      type: "boolean",
      default: false,
      ui: {
        label: "modulate",
        control: "checkbox"
      }
    },
    tint: {
      type: "vec4",
      default: [0.0, 0.0, 0.0, 1.0],
      ui: {
        label: "tint",
        control: "color"
      }
    },
    opacity: {
      type: "float",
      default: 0,
      min: 0,
      max: 100,
      ui: {
        label: "tint opacity",
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
      default: 0,
      min: 0,
      max: 100,
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
    passthru: {
      type: "float",
      default: 50,
      min: 0,
      max: 100,
      ui: {
        label: "passthru",
        control: "slider"
      }
    },
    vignetteAmt: {
      type: "float",
      default: 0,
      min: -100,
      max: 100,
      ui: {
        label: "vignette",
        control: "slider"
      }
    }
  };

  passes = [
    {
      name: "render",
      type: "render",
      program: "lens-distortion",
      inputs: {
        src: "inputTex"
      },

      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
