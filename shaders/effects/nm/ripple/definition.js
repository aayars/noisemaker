import { Effect } from '../../../src/runtime/effect.js';

/**
 * Ripple
 * /shaders/effects/ripple/ripple.wgsl
 */
export default class Ripple extends Effect {
  name = "Ripple";
  namespace = "nm";
  func = "ripple";

  globals = {
    freq: {
        type: "float",
        default: 3,
        min: 1,
        max: 16,
        step: 0.5,
        ui: {
            label: "Frequency",
            control: "slider"
        }
    },
    displacement: {
        type: "float",
        default: 0.025,
        min: 0,
        max: 0.5,
        step: 0.001,
        ui: {
            label: "Displacement",
            control: "slider"
        }
    },
    kink: {
        type: "float",
        default: 1,
        min: 0,
        max: 32,
        step: 0.5,
        ui: {
            label: "Kink",
            control: "slider"
        }
    },
    spline_order: {
        type: "int",
        default: 3,
        min: 0,
        max: 3,
        step: 1,
        ui: {
            label: "Spline Order",
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
      program: "ripple",
      inputs: {
        input_texture: "inputTex",
        reference_texture: "inputTex"
      },
      outputs: {
        color: "outputColor"
      }
    }
  ];
}
