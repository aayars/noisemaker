import { Effect } from '../../../src/runtime/effect.js';

/**
 * Adjust Saturation
 * /shaders/effects/adjust_saturation/adjust_saturation.wgsl
 */
export default class AdjustSaturation extends Effect {
  name = "AdjustSaturation";
  namespace = "nm";
  func = "adjustSaturation";

  globals = {
    amount: {
        type: "float",
        default: 0.75,
        uniform: "amount",
        min: 0,
        max: 4,
        step: 0.05,
        ui: {
            label: "Amount",
            control: "slider"
        }
    }
};

  passes = [
    {
      name: "main",
      program: "adjustSaturation",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        color: "outputColor"
      }
    }
  ];
}
