import { Effect } from '../../../src/runtime/effect.js';

/**
 * Spatter
 * /shaders/effects/spatter/spatter.wgsl
 */
export default class Spatter extends Effect {
  name = "Spatter";
  namespace = "nm";
  func = "spatter";

  globals = {
    color: {
        type: "boolean",
        default: true,
        ui: {
            label: "Color",
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
      program: "spatter",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputBuffer: "outputColor"
      }
    }
  ];
}
