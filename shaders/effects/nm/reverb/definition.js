import { Effect } from '../../../src/runtime/effect.js';

/**
 * Reverb
 * /shaders/effects/reverb/reverb.wgsl
 */
export default class Reverb extends Effect {
  name = "Reverb";
  namespace = "nm";
  func = "reverb";

  globals = {
    octaves: {
        type: "int",
        default: 3,
        min: 1,
        max: 8,
        step: 1,
        ui: {
            label: "Octaves",
            control: "slider"
        }
    },
    iterations: {
        type: "int",
        default: 2,
        min: 1,
        max: 8,
        step: 1,
        ui: {
            label: "Iterations",
            control: "slider"
        }
    },
    ridges: {
        type: "boolean",
        default: false,
        ui: {
            label: "Ridges",
            control: "checkbox"
        }
    }
};

  // TODO: Define passes based on shader requirements
  // This effect was originally implemented as a WebGPU compute shader.
  // A render pass implementation needs to be created for GLSL/WebGL2 compatibility.
  passes = [
    {
      name: "main",
      type: "compute",
      program: "reverb",
      inputs: {
        input_texture: "inputTex"
      },
      outputs: {
        outputBuffer: "outputColor"
      }
    }
  ];
}
