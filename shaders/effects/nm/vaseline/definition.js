import { Effect } from '../../../src/runtime/effect.js';

/**
 * Vaseline
 * /shaders/effects/vaseline/vaseline.wgsl
 */
export default class Vaseline extends Effect {
  name = "Vaseline";
  namespace = "nm";
  func = "vaseline";

  globals = {
    alpha: {
        type: "float",
        default: 0.5,
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
      program: "vaseline",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputBuffer: "outputColor"
      }
    }
  ];
}
