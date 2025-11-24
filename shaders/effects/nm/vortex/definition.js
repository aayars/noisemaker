import { Effect } from '../../../src/runtime/effect.js';

/**
 * Vortex
 * /shaders/effects/vortex/vortex.wgsl
 */
export default class Vortex extends Effect {
  name = "Vortex";
  namespace = "nm";
  func = "vortex";

  globals = {
    displacement: {
        type: "float",
        default: 64,
        min: 0,
        max: 256,
        step: 1,
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
      program: "vortex",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputBuffer: "outputColor"
      }
    }
  ];
}
