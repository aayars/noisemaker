import { Effect } from '../../../src/runtime/effect.js';

export default class Effects extends Effect {
  name = "Effects";
  namespace = "nd";
  func = "effects";

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
    effect: {
      type: "int",
      default: 0,
      choices: {
        None: 0,
        Bloom: 220,
        Blur: 1,
        "Blur Sharpen": 300,
        Cga: 200,
        Derivatives: 120,
        "Deriv+divide": 2,
        Edge: 3,
        Emboss: 4,
        "Lit Edge": 9,
        Outline: 5,
        Pixels: 100,
        Posterize: 110,
        Shadow: 6,
        Sharpen: 7,
        "Smooth Edge": 301,
        Sobel: 8,
        Subpixel: 210,
        "Zoom Blur": 230
      },
      ui: {
        label: "effect",
        control: "dropdown"
      }
    },
    effectAmt: {
      type: "int",
      default: 1,
      min: 0,
      max: 20,
      ui: {
        label: "effect amt",
        control: "slider"
      }
    },
    flip: {
      type: "int",
      default: 0,
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
    scaleAmt: {
      type: "float",
      default: 100,
      min: 25,
      max: 400,
      ui: {
        label: "scale %",
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
    offsetX: {
      type: "float",
      default: 0,
      min: -100,
      max: 100,
      ui: {
        label: "offset x",
        control: "slider"
      }
    },
    offsetY: {
      type: "float",
      default: 0,
      min: -100,
      max: 100,
      ui: {
        label: "offset y",
        control: "slider"
      }
    },
    intensity: {
      type: "int",
      default: 0,
      min: -100,
      max: 100,
      ui: {
        label: "intensity",
        control: "slider"
      }
    },
    saturation: {
      type: "int",
      default: 0,
      min: -100,
      max: 100,
      ui: {
        label: "saturation",
        control: "slider"
      }
    }
  };

  passes = [
    {
      name: "render",
      type: "render",
      program: "effects",
      inputs: {
        inputTex: "inputTex"
      },

      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
