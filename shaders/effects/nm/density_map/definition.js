import { Effect } from '../../../src/runtime/effect.js';

/**
 * Density Map
 * /shaders/effects/density_map/density_map.wgsl
 */
export default class DensityMap extends Effect {
  name = "DensityMap";
  namespace = "nm";
  func = "densitymap";

  globals = {};

  // TODO: Define passes based on shader requirements
  // This effect was originally implemented as a WebGPU compute shader.
  // A render pass implementation needs to be created for GLSL/WebGL2 compatibility.
  passes = [
    {
      name: "reduce_1",
      type: "compute",  // GPGPU: min/max reduction pass 1
      program: "reduce_1",
      inputs: {
        input_texture: "inputTex"
      },
      outputs: {
        fragColor: "minmax_1"
      }
    },
    {
      name: "reduce_2",
      type: "compute",  // GPGPU: min/max reduction pass 2
      program: "reduce_2",
      inputs: {
        input_texture: "minmax_1"
      },
      outputs: {
        fragColor: "minmax_global"
      }
    },
    {
      name: "apply",
      type: "render",
      program: "density_map",
      inputs: {
        input_texture: "inputTex",
        minmax_texture: "minmax_global"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
