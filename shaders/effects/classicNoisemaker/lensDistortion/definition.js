import { Effect } from '../../../src/runtime/effect.js';

/**
 * Lens Distortion
 * /shaders/effects/lens_distortion/lens_distortion.wgsl
 */
export default class LensDistortion extends Effect {
  name = "LensDistortion";
  namespace = "classicNoisemaker";
  func = "lensDistortion";

  globals = {
    displacement: {
        type: "float",
        default: 1,
        uniform: "displacement",
        min: -2,
        max: 2,
        step: 0.01,
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
      program: "lensDistortion",
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
