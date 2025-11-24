import { Effect } from '../../../src/runtime/effect.js';

/**
 * Vignette
 * /shaders/effects/vignette/vignette.wgsl
 */
export default class Vignette extends Effect {
  name = "Vignette";
  namespace = "nm";
  func = "vignette";

  globals = {
    brightness: {
        type: "float",
        default: 0,
        min: 0,
        max: 1,
        step: 0.01,
        ui: {
            label: "Brightness",
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
      program: "vignette",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputBuffer: "outputColor"
      }
    }
  ];
}
