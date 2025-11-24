import { Effect } from '../../../src/runtime/effect.js';

/**
 * Warp - multi-octave displacement using noise
 */
export default class Warp extends Effect {
  name = "Warp";
  namespace = "nm";
  func = "warp";

  globals = {
    frequency: {
      type: "float",
      default: 2,
      min: 0.1,
      max: 10,
      step: 0.1,
      ui: {
        label: "Frequency",
        control: "slider"
      }
    },
    octaves: {
      type: "float",
      default: 5,
      min: 1,
      max: 10,
      step: 1,
      ui: {
        label: "Octaves",
        control: "slider"
      }
    },
    displacement: {
      type: "float",
      default: 0.1,
      min: 0,
      max: 1,
      step: 0.01,
      ui: {
        label: "Displacement",
        control: "slider"
      }
    },
    speed: {
      type: "float",
      default: 1,
      min: 0,
      max: 5,
      step: 0.1,
      ui: {
        label: "Speed",
        control: "slider"
      }
    },
    spline_order: {
      type: "float",
      default: 2,
      min: 0,
      max: 3,
      step: 1,
      ui: {
        label: "Spline Order",
        control: "slider"
      }
    }
  };

  passes = [
    {
      name: "main",
      type: "render",
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
