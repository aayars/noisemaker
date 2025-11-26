import { Effect } from '../../../src/runtime/effect.js';

export default class FeedbackPost extends Effect {
  name = "FeedbackPost";
  namespace = "nd";
  func = "feedbackPost";

  globals = {
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
    blendMode: {
      type: "int",
      default: 10,
      uniform: "blendMode",
      choices: {
        Add: 0,
        Cloak: 100,
        "Color Burn": 2,
        "Color Dodge": 3,
        Darken: 4,
        Difference: 5,
        Exclusion: 6,
        Glow: 7,
        "Hard Light": 8,
        Lighten: 9,
        Mix: 10,
        Multiply: 11,
        Negation: 12,
        Overlay: 13,
        Phoenix: 14,
        Reflect: 15,
        Screen: 16,
        "Soft Light": 17,
        Subtract: 18
      },
      ui: {
        label: "mode",
        control: "dropdown"
      }
    },
    mixAmt: {
      type: "float",
      default: 0,
      uniform: "mixAmt",
      min: 0,
      max: 100,
      ui: {
        label: "feedback",
        control: "slider"
      }
    },
    scaleAmt: {
      type: "float",
      default: 100,
      uniform: "scaleAmt",
      min: 75,
      max: 200,
      ui: {
        label: "scale %",
        control: "slider"
      }
    },
    rotation: {
      type: "int",
      default: 0,
      uniform: "rotation",
      min: -180,
      max: 180,
      ui: {
        label: "rotate",
        control: "slider"
      }
    },
    refractAAmt: {
      type: "float",
      default: 0,
      uniform: "refractAAmt",
      min: 0,
      max: 100,
      ui: {
        label: "refract a→b",
        control: "slider"
      }
    },
    refractBAmt: {
      type: "float",
      default: 0,
      uniform: "refractBAmt",
      min: 0,
      max: 100,
      ui: {
        label: "refract b→a",
        control: "slider"
      }
    },
    refractADir: {
      type: "float",
      default: 0,
      uniform: "refractADir",
      min: 0,
      max: 360,
      ui: {
        label: "refract dir a",
        control: "slider"
      }
    },
    refractBDir: {
      type: "float",
      default: 0,
      uniform: "refractBDir",
      min: 0,
      max: 360,
      ui: {
        label: "refract dir b",
        control: "slider"
      }
    },
    hueRotation: {
      type: "float",
      default: 0,
      uniform: "hueRotation",
      min: -180,
      max: 180,
      ui: {
        label: "hue shift",
        control: "slider"
      }
    },
    intensity: {
      type: "float",
      default: 0,
      uniform: "intensity",
      min: -100,
      max: 100,
      ui: {
        label: "intensity",
        control: "slider"
      }
    },
    aberrationAmt: {
      type: "float",
      default: 0,
      uniform: "aberrationAmt",
      min: 0,
      max: 100,
      ui: {
        label: "aberration",
        control: "slider"
      }
    },
    distortion: {
      type: "float",
      default: 0,
      uniform: "distortion",
      min: -100,
      max: 100,
      ui: {
        label: "lens",
        control: "slider"
      }
    },
    aspectLens: {
      type: "boolean",
      default: false,
      uniform: "aspectLens",
      ui: {
        label: "1:1 aspect",
        control: "checkbox"
      }
    }
  };

  passes = [
    {
      name: "render",
      program: "feedbackPost",
      inputs: {
        inputTex: "inputTex",
        selfTex: "selfTex"
      },

      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
