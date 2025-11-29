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
        uniform: "alpha",
        min: 0,
        max: 1,
        step: 0.01,
        ui: {
            label: "Alpha",
            control: "slider"
        }
    },
    speed: {
        type: "float",
        default: 1.0,
        uniform: "speed",
        min: 0,
        max: 5,
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
      program: "snow",
      inputs: {
        inputTex: "inputTex"
      },
      uniforms: {
        alpha: "alpha",
        speed: "speed"
      },
      outputs: {
        fragColor: "outputTex"
      }
    }
  ];
}
