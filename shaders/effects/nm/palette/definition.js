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
    palette_index: {
        type: "int",
        default: 1,
        uniform: "palette_index",
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

  // TODO: Define passes based on shader requirements
  // This effect was originally implemented as a WebGPU compute shader.
  // A render pass implementation needs to be created for GLSL/WebGL2 compatibility.
  passes = [
    {
      name: "main",
      type: "render",
      program: "palette",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputColor: "outputColor"
      }
    }
  ];
}
