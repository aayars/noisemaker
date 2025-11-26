import { Effect } from '../../../src/runtime/effect.js';

export default class Warp extends Effect {
  name = "Warp";
  namespace = "nd";
  func = "warp";

  globals = {
    distortionType: {
      type: "int",
      default: 10,
      uniform: "distortionType",
      choices: {
        Bulge: 21,
        Perlin: 10,
        Pinch: 20,
        Polar: 0,
        "Spiral Cw": 30,
        "Spiral Ccw": 31,
        Vortex: 1,
        Waves: 2
      },
      ui: {
        label: "type",
        control: "dropdown"
      }
    },
    flip: {
      type: "int",
      default: 0,
      uniform: "flip",
      choices: {
        None: 0,
        "Flip:": null,
        All: 1,
        Horizontal: 2,
        Vertical: 3,
        "Mirror:": null,
        "Left → Right": 11,
        "Left ← Right": 12,
        "Up → Down": 13,
        "Up ← Down": 14,
        "L → R / U → D": 15,
        "L → R / U ← D": 16,
        "L ← R / U → D": 17,
        "L ← R / U ← D": 18
      },
      ui: {
        label: "flip/mirror",
        control: "dropdown"
      }
    },
    scale: {
      type: "float",
      default: 1,
      uniform: "scale",
      min: -5,
      max: 5,
      ui: {
        label: "scale",
        control: "slider"
      }
    },
    rotateAmt: {
      type: "float",
      default: 0,
      uniform: "rotateAmt",
      min: -180,
      max: 180,
      ui: {
        label: "rotation",
        control: "slider"
      }
    },
    strength: {
      type: "float",
      default: 25,
      uniform: "strength",
      min: 0,
      max: 100,
      ui: {
        label: "strength",
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
        label: "noise seed",
        control: "slider"
      }
    },
    wrap: {
      type: "int",
      default: 0,
      uniform: "wrap",
      choices: {
        Clamp: 2,
        Mirror: 0,
        Repeat: 1
      },
      ui: {
        label: "wrap",
        control: "dropdown"
      }
    },
    center: {
      type: "float",
      default: 0,
      uniform: "center",
      min: -5,
      max: 5,
      ui: {
        label: "center",
        control: "slider"
      }
    },
    aspectLens: {
      type: "boolean",
      default: true,
      uniform: "aspectLens",
      ui: {
        label: "1:1 aspect",
        control: "checkbox"
      }
    },
    speed: {
      type: "int",
      default: 1,
      uniform: "speed",
      min: -5,
      max: 5,
      ui: {
        label: "speed",
        control: "slider"
      }
    },
    rotation: {
      type: "int",
      default: 0,
      uniform: "rotation",
      min: -5,
      max: 5,
      ui: {
        label: "rot speed",
        control: "slider"
      }
    }
  };

  passes = [
    {
      name: "render",
      program: "warp",
      inputs: {
        inputTex: "inputTex"
      },

      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
