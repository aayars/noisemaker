import { Effect } from '../../../src/runtime/effect.js';

export default class Noise3d extends Effect {
  name = "Noise3d";
  namespace = "nd";
  func = "noise3d";

  globals = {
    noiseType: {
      type: "int",
      default: 12,
      uniform: "noiseType",
      choices: {
        Cubes: 50,
        Simplex: 12,
        Sine: 30,
        Spheres: 40,
        "Wavy Planes": 60,
        "Wavy Plane Lower": 61,
        "Wavy Plane Upper": 62
      },
      ui: {
        label: "noise type",
        control: "dropdown"
      }
    },
    noiseScale: {
      type: "float",
      default: 25,
      uniform: "noiseScale",
      min: 1,
      max: 100,
      ui: {
        label: "scale",
        control: "slider"
      }
    },
    offsetX: {
      type: "float",
      default: 0,
      uniform: "offsetX",
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
      uniform: "offsetY",
      min: -100,
      max: 100,
      ui: {
        label: "offset y",
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
    colorMode: {
      type: "int",
      default: 6,
      uniform: "colorMode",
      choices: {
        "Depth Map": 8,
        Grayscale: 0,
        Hsv: 6,
        "Surface Normal": 7
      },
      ui: {
        label: "color mode",
        control: "dropdown"
      }
    },
    hueRotation: {
      type: "float",
      default: 0,
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
      default: 10,
      uniform: "hueRange",
      min: 0,
      max: 100,
      ui: {
        label: "hue range",
        control: "slider"
      }
    },
    speed: {
      type: "int",
      default: 1,
      uniform: "speed",
      min: -10,
      max: 10,
      ui: {
        label: "speed",
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
    }
  };

  passes = [
    {
      name: "render",
      program: "noise3d",
      inputs: {
      },

      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
