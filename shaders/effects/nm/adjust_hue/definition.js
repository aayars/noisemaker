import { Effect } from '../../../src/runtime/effect.js';

/**
 * Adjust Hue
 * /shaders/effects/adjust_hue/adjust_hue.wgsl
 */
export default class AdjustHue extends Effect {
  name = "AdjustHue";
  namespace = "nm";
  func = "adjusthue";

  globals = {
    amount: {
        type: "float",
        default: 0.25,
        uniform: "amount",
        min: -1,
        max: 1,
        step: 0.01,
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
      program: "adjust_hue",
      inputs: {
        input_texture: "inputTex"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
