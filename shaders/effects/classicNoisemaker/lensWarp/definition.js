import { Effect } from '../../../src/runtime/effect.js';

/**
 * Lens Warp
 * /shaders/effects/lens_warp/lens_warp.wgsl
 */
export default class LensWarp extends Effect {
  name = "LensWarp";
  namespace = "classicNoisemaker";
  func = "lensWarp";

  globals = {
    displacement: {
        type: "float",
        default: 0.0625,
        uniform: "displacement",
        min: 0,
        max: 0.5,
        step: 0.0025,
        ui: {
            label: "Displacement",
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
      program: "lensWarp",
      inputs: {
        inputTex: "inputTex"
      },
      uniforms: {
        displacement: "displacement"
      },
      outputs: {
        outputBuffer: "outputTex"
      }
    }
  ];
}
