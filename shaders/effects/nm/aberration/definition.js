import { Effect } from '../../../src/runtime/effect.js';

/**
 * Aberration
 * /shaders/effects/aberration/aberration.wgsl
 */
export default class Aberration extends Effect {
  name = "Aberration";
  namespace = "nm";
  func = "aberration";

  globals = {
    displacement: {
        type: "float",
        default: 0.005,
        min: 0,
        max: 0.05,
        step: 0.001,
        ui: {
            label: "Displacement",
            control: "slider"
        }
    },
    speed: {
        type: "float",
        default: 0.2,
        min: 0,
        max: 2.0,
        step: 0.01,
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
      program: "aberration",
      inputs: {
        input_texture: "inputTex"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
