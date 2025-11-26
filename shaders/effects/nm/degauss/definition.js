import { Effect } from '../../../src/runtime/effect.js';

/**
 * Degauss
 * /shaders/effects/degauss/degauss.wgsl
 */
export default class Degauss extends Effect {
  name = "Degauss";
  namespace = "nm";
  func = "degauss";

  globals = {
    displacement: {
        type: "float",
        default: 0.0625,
        uniform: "displacement",
        min: 0,
        max: 0.25,
        step: 0.001,
        ui: {
            label: "Displacement",
            control: "slider"
        }
    },
    speed: {
        type: "float",
        default: 1.0,
        uniform: "speed",
        min: 0.0,
        max: 2.0,
        step: 0.1,
        ui: {
            label: "Speed",
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
      program: "degauss",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputBuffer: "outputColor"
      }
    }
  ];
}
