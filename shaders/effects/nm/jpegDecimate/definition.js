import { Effect } from '../../../src/runtime/effect.js';

/**
 * JPEG Decimate
 * /shaders/effects/jpeg_decimate/jpeg_decimate.wgsl
 */
export default class JpegDecimate extends Effect {
  name = "JpegDecimate";
  namespace = "nm";
  func = "jpegDecimate";

  globals = {};

  // TODO: Define passes based on shader requirements
  // This effect was originally implemented as a WebGPU compute shader.
  // A render pass implementation needs to be created for GLSL/WebGL2 compatibility.
  passes = [
    {
      name: "main",
      program: "jpegDecimate",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputBuffer: "outputColor"
      }
    }
  ];
}
