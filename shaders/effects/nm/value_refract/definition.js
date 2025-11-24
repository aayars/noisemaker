import { Effect } from '../../../src/runtime/effect.js';

/**
 * ValueRefract
 * 
 */
export default class ValueRefract extends Effect {
  name = "ValueRefract";
  namespace = "nm";
  func = "valuerefract";

  globals = {};

  // TODO: Define passes based on shader requirements
  // This effect was originally implemented as a WebGPU compute shader.
  // A render pass implementation needs to be created for GLSL/WebGL2 compatibility.
  passes = [
    {
      name: "main",
      type: "compute",
      program: "value_refract",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputBuffer: "outputColor"
      }
    }
  ];
}
