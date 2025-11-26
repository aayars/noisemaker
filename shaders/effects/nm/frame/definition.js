import { Effect } from '../../../src/runtime/effect.js';

/**
 * Frame
 * /shaders/effects/frame/frame.wgsl
 */
export default class Frame extends Effect {
  name = "Frame";
  namespace = "nm";
  func = "frame";

  globals = {};

  // TODO: Define passes based on shader requirements
  // This effect was originally implemented as a WebGPU compute shader.
  // A render pass implementation needs to be created for GLSL/WebGL2 compatibility.
  passes = [
    {
      name: "main",
      program: "frame",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputBuffer: "outputColor"
      }
    }
  ];
}
