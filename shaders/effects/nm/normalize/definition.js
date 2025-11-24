import { Effect } from '../../../src/runtime/effect.js';

/**
 * Normalize
 * /shaders/effects/normalize/apply.wgsl
 */
export default class Normalize extends Effect {
  name = "Normalize";
  namespace = "nm";
  func = "normalize";

  globals = {};

  textures = {
    stats: { width: 1, height: 1, format: "rgba32f" }
  };

  passes = [
    {
      name: "stats",
      type: "render",
      program: "stats",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        fragColor: "stats"
      }
    },
    {
      name: "apply",
      type: "render",
      program: "apply",
      inputs: {
        inputTex: "inputTex",
        statsTex: "stats"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
