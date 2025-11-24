import { Effect } from '../../../src/runtime/effect.js';

/**
 * Refract
 * /shaders/effects/refract/refract.wgsl
 */
export default class Refract extends Effect {
  name = "Refract";
  namespace = "nm";
  func = "refract";

  globals = {
    displacement: {
      type: "float",
      default: 0.5,
      min: 0,
      max: 2,
      step: 0.01,
      ui: {
        label: "Displacement",
        control: "slider"
      }
    },
    warp: {
      type: "float",
      default: 0,
      min: 0,
      max: 4,
      step: 0.1,
      ui: {
        label: "Warp",
        control: "slider"
      }
    },
    spline_order: {
      type: "int",
      default: 3,
      min: 0,
      max: 5,
      step: 1,
      ui: {
        label: "Spline Order",
        control: "slider"
      }
    },
    derivative: {
      type: "int",
      default: 1,
      min: 0,
      max: 3,
      step: 1,
      ui: {
        label: "Derivative",
        control: "slider"
      }
    },
    range: {
      type: "float",
      default: 1,
      min: 0.1,
      max: 4,
      step: 0.1,
      ui: {
        label: "Range",
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
    }
  };

  passes = [
    {
      name: "main",
      type: "render",
      program: "refract",
      inputs: {
        input_texture: "inputTex"
      },
      outputs: {
        color: "outputColor"
      }
    }
  ];
}
