import { Effect } from '../../../src/runtime/effect.js';

export default class Atmosphere extends Effect {
  name = "Atmosphere";
  namespace = "nd";
  func = "atmosphere";

  globals = {
    noiseType: {
      type: "int",
      default: 1,
      choices: {
        "Caustic": 0,
        "Simplex": 1,
        "Quad Tap": 2
      },
      ui: { label: "Noise Type", control: "dropdown" },
      uniform: "noiseType"
    },
    interp: {
      type: "int",
      default: 10,
      choices: {
        "Linear": 0,
        "Linear (Mix)": 1,
        "Hermite": 2,
        "Quadratic B-Spline": 3,
        "Bicubic (Texture)": 4,
        "Cubic B-Spline": 5,
        "Catmull-Rom": 7,
        "Catmull-Rom (4x4)": 8,
        "Simplex": 10,
        "Sine": 11,
        "Quintic": 12
      },
      ui: { label: "Interpolation", control: "dropdown" },
      uniform: "interp"
    },
    noiseScale: {
      type: "float",
      default: 85,
      min: 1,
      max: 200,
      ui: { label: "Scale", control: "slider" },
      uniform: "noiseScale"
    },
    loopAmp: {
      type: "float",
      default: 25,
      min: 0,
      max: 100,
      ui: { label: "Loop Amp", control: "slider" },
      uniform: "loopAmp"
    },
    refractAmt: {
      type: "float",
      default: 5,
      min: 0,
      max: 100,
      ui: { label: "Refract", control: "slider" },
      uniform: "refractAmt"
    },
    ridges: {
      type: "boolean",
      default: true,
      ui: { label: "Ridges", control: "checkbox" },
      uniform: "ridges"
    },
    wrap: {
      type: "boolean",
      default: true,
      ui: { label: "Wrap", control: "checkbox" },
      uniform: "wrap"
    },
    seed: {
      type: "float",
      default: 44,
      min: 0,
      max: 100,
      ui: { label: "Seed", control: "slider" },
      uniform: "seed"
    },
    colorMode: {
      type: "int",
      default: 2,
      choices: {
        "Grayscale": 0,
        "RGB": 1,
        "HSV": 2,
        "OKLab": 3
      },
      ui: { label: "Color Mode", control: "dropdown" },
      uniform: "colorMode"
    },
    hueRotation: {
      type: "float",
      default: 180,
      min: 0,
      max: 360,
      ui: { label: "Hue Rotation", control: "slider" },
      uniform: "hueRotation"
    },
    hueRange: {
      type: "float",
      default: 25,
      min: 0,
      max: 100,
      ui: { label: "Hue Range", control: "slider" },
      uniform: "hueRange"
    },
    intensity: {
      type: "float",
      default: 0,
      min: -100,
      max: 100,
      ui: { label: "Intensity", control: "slider" },
      uniform: "intensity"
    },
    color1: {
      type: "vec4",
      default: [1, 0, 0, 1],
      ui: { label: "Color 1", control: "color" },
      uniform: "color1"
    },
    color2: {
      type: "vec4",
      default: [0, 1, 0, 1],
      ui: { label: "Color 2", control: "color" },
      uniform: "color2"
    },
    color3: {
      type: "vec4",
      default: [0, 0, 1, 1],
      ui: { label: "Color 3", control: "color" },
      uniform: "color3"
    },
    color4: {
      type: "vec4",
      default: [1, 1, 0, 1],
      ui: { label: "Color 4", control: "color" },
      uniform: "color4"
    }
  };

  passes = [
    {
      name: "render",
      program: "atmosphere",
      inputs: {
        noiseTex: "noise"
      },

      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
