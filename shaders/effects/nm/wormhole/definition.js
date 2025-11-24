import { Effect } from '../../../src/runtime/effect.js';

/**
 * Wormhole
 * /shaders/effects/wormhole/wormhole.wgsl
 */
export default class Wormhole extends Effect {
  name = "Wormhole";
  namespace = "nm";
  func = "wormhole";

  globals = {
    kink: {
        type: "float",
        default: 1,
        min: 0,
        max: 10,
        step: 0.1,
        ui: {
            label: "Kink",
            control: "slider"
        }
    },
    input_stride: {
        type: "float",
        default: 0.05,
        min: 0,
        max: 5,
        step: 0.01,
        ui: {
            label: "Input Stride",
            control: "slider"
        }
    },
    alpha: {
        type: "float",
        default: 1,
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
      type: "compute",
      program: "wormhole",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputBuffer: "outputColor"
      }
    }
  ];
}
