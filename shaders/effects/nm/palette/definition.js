import { Effect } from '../../../src/runtime/effect.js';

/**
 * Palette
 * /shaders/effects/palette/palette.wgsl
 */
export default class Palette extends Effect {
  name = "Palette";
  namespace = "nm";
  func = "palette";

  globals = {
    paletteIndex: {
        type: "int",
        default: 1,
        uniform: "paletteIndex",
        min: 0,
        max: 37,
        step: 1,
        ui: {
            label: "Palette Index",
            control: "slider"
        }
    },
    alpha: {
        type: "float",
        default: 1,
        uniform: "alpha",
        min: 0,
        max: 1,
        step: 0.01,
        ui: {
            label: "Alpha",
            control: "slider"
        }
    }
};

  passes = [
    {
      name: "main",
      program: "palette",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        color: "outputColor"
      }
    }
  ];
}
