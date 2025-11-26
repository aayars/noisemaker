import { Effect } from '../../../src/runtime/effect.js';

/**
 * Adjust Contrast
 * /shaders/effects/adjust_contrast/adjust_contrast.wgsl
 */
export default class AdjustContrast extends Effect {
  name = "AdjustContrast";
  namespace = "nm";
  func = "adjustcontrast";

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

  // TODO: Define passes based on shader requirements
  // This effect was originally implemented as a WebGPU compute shader.
  // A render pass implementation needs to be created for GLSL/WebGL2 compatibility.
  passes = [
    {
      name: "main",
      type: "render",
      program: "adjust_contrast",
      inputs: {
        input_texture: "inputTex"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
