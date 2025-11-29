import { Effect } from '../../../src/runtime/effect.js';

/**
 * Simple Frame
 * /shaders/effects/simple_frame/simple_frame.wgsl
 */
export default class SimpleFrame extends Effect {
  name = "SimpleFrame";
  namespace = "nm";
  func = "simpleFrame";

  globals = {
    brightness: {
        type: "float",
        default: 0,
        uniform: "brightness",
        min: -1,
        max: 1,
        step: 0.01,
        ui: {
            label: "Brightness",
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
      program: "simpleFrame",
      inputs: {
        inputTex: "inputTex"
      },
      uniforms: {
        brightness: "brightness"
      },
      outputs: {
        fragColor: "outputTex"
      }
    }
  ];
}
