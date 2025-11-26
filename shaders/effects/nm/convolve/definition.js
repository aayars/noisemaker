import { Effect } from '../../../src/runtime/effect.js';

/**
 * Convolve
 * /shaders/effects/convolve/convolve.wgsl
 */
export default class Convolve extends Effect {
  name = "Convolve";
  namespace = "nm";
  func = "convolve";

  globals = {
    kernel: {
        type: "int",
        default: 800,
        uniform: "kernel",
        min: 800,
        max: 810,
        step: 1,
        ui: {
            label: "Kernel Id",
            control: "slider"
        }
    },
    with_normalize: {
        type: "float",
        default: 1.0,
        uniform: "with_normalize",
        min: 0,
        max: 1,
        step: 1,
        ui: {
            label: "Normalize",
            control: "checkbox"
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
      name: "convolve",
      type: "render",
      program: "convolve_render",
      inputs: {
        input_texture: "inputTex"
      },
      outputs: {
        fragColor: "convolved"
      }
    },
    {
      name: "reduce_1",
      type: "render",
      program: "reduce_1",
      inputs: {
        input_texture: "convolved"
      },
      outputs: {
        fragColor: "minmax_1"
      }
    },
    {
      name: "reduce_2",
      type: "render",
      program: "reduce_2",
      inputs: {
        input_texture: "minmax_1"
      },
      outputs: {
        fragColor: "minmax_global"
      }
    },
    {
      name: "normalize",
      type: "render",
      program: "normalize_render",
      inputs: {
        convolved_texture: "convolved",
        minmax_texture: "minmax_global",
        input_texture: "inputTex"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
