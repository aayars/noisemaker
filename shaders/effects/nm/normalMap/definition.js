import { Effect } from '../../../src/runtime/effect.js';

/**
 * Normal Map
 * /shaders/effects/normal_map/normal_map.wgsl
 */
export default class NormalMap extends Effect {
  name = "NormalMap";
  namespace = "nm";
  func = "normalMap";

  globals = {};

  // TODO: Define passes based on shader requirements
  // This effect was originally implemented as a WebGPU compute shader.
  // A render pass implementation needs to be created for GLSL/WebGL2 compatibility.
  passes = [
    {
      name: "main",
      program: "normalMap",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputBuffer: "outputColor"
      }
    }
  ];
}
