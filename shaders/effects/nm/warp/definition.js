import { Effect } from '../../../src/runtime/effect.js';

/**
 * Warp
 * /shaders/effects/warp/warp.wgsl
 */
export default class Warp extends Effect {
  name = "Warp";
  namespace = "nm";
  func = "warp";

  globals = {
    freq: {
        type: "float",
        default: 2,
        min: 0.1,
        max: 10,
        step: 0.1,
        ui: {
            label: "Frequency",
            control: "slider"
        }
    },
    octaves: {
        type: "integer",
        default: 5,
        min: 1,
        max: 10,
        step: 1,
        ui: {
            label: "Octaves",
            control: "slider"
        }
    },
    displacement: {
        type: "float",
        default: 1,
        min: 0,
        max: 5,
        step: 0.1,
        ui: {
            label: "Displacement",
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
      type: "compute",
      program: "warp",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputBuffer: "outputColor"
      }
    }
  ];
}
