import { Effect } from '../../../src/runtime/effect.js';

/**
 * CRT
 * /shaders/effects/crt/crt.wgsl
 */
export default class Crt extends Effect {
  name = "Crt";
  namespace = "nm";
  func = "crt";

  globals = {
    speed: {
      type: "float",
      default: 1.0,
      uniform: "speed",
      min: 0.0,
      max: 5.0,
      step: 0.1,
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
      program: "crt",
      inputs: {
        input_texture: "inputTex"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
