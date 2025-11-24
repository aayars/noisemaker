import { Effect } from '../../../src/runtime/effect.js';

/**
 * Snow
 * /shaders/effects/snow/snow.wgsl
 */
export default class Snow extends Effect {
  name = "Snow";
  namespace = "nm";
  func = "snow";

  globals = {
    alpha: {
        type: "float",
        default: 0.25,
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
      program: "snow",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputBuffer: "outputColor"
      }
    }
  ];
}
