import { Effect } from '../../../src/runtime/effect.js';

/**
 * Adjust Contrast
 * /shaders/effects/adjust_contrast/adjust_contrast.wgsl
 */
export default class AdjustContrast extends Effect {
  name = "AdjustContrast";
  namespace = "nm";
  func = "adjustContrast";

  globals = {
    amount: {
        type: "float",
        default: 1.25,
        uniform: "amount",
        min: 0,
        max: 5,
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
      program: "adjustContrast",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        color: "outputColor"
      }
    }
  ];
}
