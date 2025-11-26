import { Effect } from '../../../src/runtime/effect.js';

/**
 * Adjust Brightness
 * /shaders/effects/adjust_brightness/adjust_brightness.wgsl
 */
export default class AdjustBrightness extends Effect {
  name = "AdjustBrightness";
  namespace = "nm";
  func = "adjustbrightness";

  globals = {
    amount: {
        type: "float",
        default: 0.125,
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
      program: "adjust_brightness",
      inputs: {
        input_texture: "inputTex"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
