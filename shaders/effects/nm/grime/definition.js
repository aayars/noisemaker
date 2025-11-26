import { Effect } from '../../../src/runtime/effect.js';

/**
 * Grime
 * /shaders/effects/grime/grime.wgsl
 */
export default class Grime extends Effect {
  name = "Grime";
  namespace = "nm";
  func = "grime";

  globals = {
    strength: {
        type: "number",
        default: 1,
        uniform: "strength",
        min: 0,
        max: 5,
        step: 0.1,
        ui: {
            label: "Strength",
            control: "slider"
        }
    },
    debugMode: {
        type: "number",
        default: 0,
        uniform: "debugMode",
        min: 0,
        max: 4,
        step: 1,
        ui: {
            label: "Debug Mode",
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
      program: "grime",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputBuffer: "outputColor"
      }
    }
  ];
}
