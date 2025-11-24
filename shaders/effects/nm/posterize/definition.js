import { Effect } from '../../../src/runtime/effect.js';

/**
 * Posterize
 * /shaders/effects/posterize/posterize.wgsl
 */
export default class Posterize extends Effect {
  name = "Posterize";
  namespace = "nm";
  func = "posterize";

  globals = {
    levels: {
        type: "float",
        default: 5,
        min: 2,
        max: 32,
        step: 1,
        ui: {
            label: "Levels",
            control: "slider"
        }
    },
    gamma: {
        type: "float",
        default: 1,
        min: 0.1,
        max: 3,
        step: 0.05,
        ui: {
            label: "Gamma",
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
      program: "posterize",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputColor: "outputColor"
      }
    }
  ];
}
