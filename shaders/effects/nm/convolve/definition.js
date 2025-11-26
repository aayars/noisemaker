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
    withNormalize: {
        type: "float",
        default: 1.0,
        uniform: "withNormalize",
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
      program: "convolveRender",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        fragColor: "convolved"
      }
    },
    {
      name: "reduce1",
      program: "reduce1",
      inputs: {
        inputTex: "convolved"
      },
      outputs: {
        fragColor: "minmax1"
      }
    },
    {
      name: "reduce2",
      program: "reduce2",
      inputs: {
        inputTex: "minmax1"
      },
      outputs: {
        fragColor: "minmaxGlobal"
      }
    },
    {
      name: "normalize",
      program: "normalizeRender",
      inputs: {
        convolvedTexture: "convolved",
        minmaxTexture: "minmaxGlobal",
        inputTex: "inputTex"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
