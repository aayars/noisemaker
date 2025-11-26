import { Effect } from '../../../src/runtime/effect.js';

/**
 * Adjust Saturation
 * /shaders/effects/adjust_saturation/adjust_saturation.wgsl
 */
export default class AdjustSaturation extends Effect {
  name = "AdjustSaturation";
  namespace = "nm";
  func = "adjustsaturation";

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

  // TODO: Define passes based on shader requirements
  // This effect was originally implemented as a WebGPU compute shader.
  // A render pass implementation needs to be created for GLSL/WebGL2 compatibility.
  passes = [
    {
      name: "main",
      type: "render",
      program: "adjust_saturation",
      inputs: {
        input_texture: "inputTex"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
