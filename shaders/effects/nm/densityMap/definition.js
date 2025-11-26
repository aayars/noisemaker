import { Effect } from '../../../src/runtime/effect.js';

/**
 * Density Map
 * /shaders/effects/density_map/density_map.wgsl
 */
export default class DensityMap extends Effect {
  name = "DensityMap";
  namespace = "nm";
  func = "densityMap";

  globals = {};

  // TODO: Define passes based on shader requirements
  // This effect was originally implemented as a WebGPU compute shader.
  // A render pass implementation needs to be created for GLSL/WebGL2 compatibility.
  passes = [
    {
      name: "reduce1",
      program: "reduce1",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        fragColor: "minmax1"
      }
    },
    {
      name: "reduce2",
      program: "reduce2",
      inputs: {
        inputTex: "minmax1"
      },
      outputs: {
        fragColor: "minmaxGlobal"
      }
    },
    {
      name: "apply",
      program: "densityMap",
      inputs: {
        inputTex: "inputTex",
        minmaxTexture: "minmaxGlobal"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
