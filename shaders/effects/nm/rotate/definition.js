import { Effect } from '../../../src/runtime/effect.js';

/**
 * Rotate
 * /shaders/effects/rotate/rotate.wgsl
 */
export default class Rotate extends Effect {
  name = "Rotate";
  namespace = "nm";
  func = "rotate";

  globals = {
    angle: {
        type: "float",
        default: 0,
        uniform: "angle",
        min: -180,
        max: 180,
        step: 1,
        ui: {
            label: "Angle",
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
      program: "rotate",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputBuffer: "outputColor"
      }
    }
  ];
}
