import { Effect } from '../../../src/runtime/effect.js';

/**
 * Normalize - GPGPU Implementation
 * 
 * Multi-pass GPGPU pipeline for image normalization:
 * 1. reduce: 16:1 pyramid reduction, compute per-block min/max RGB
 * 2. reduce_minmax: 16:1 reduction of min/max values  
 * 3. stats_final: Reduce to single global min/max
 * 4. apply: Normalize each pixel using global stats
 * 
 * For 800x600: 800/16=50, 600/16=38 → 50x38 → 4x3 → 1x1
 */
export default class Normalize extends Effect {
  name = "Normalize";
  namespace = "nm";
  func = "normalize";

  globals = {};

  textures = {
    // Pyramid reduction textures
    reduce1: { width: "6.25%", height: "6.25%", format: "rgba16f" },  // 1/16
    reduce2: { width: "0.4%", height: "0.4%", format: "rgba16f" },    // 1/256  
    stats: { width: 1, height: 1, format: "rgba16f" }                 // Final 1x1
  };

  passes = [
    {
      name: "reduce",
      type: "compute",  // GPGPU: pyramid reduction, per-block min/max
      program: "reduce",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputColor: "reduce1"
      }
    },
    {
      name: "reduce_minmax",
      type: "compute",  // GPGPU: second reduction of min/max values
      program: "reduce_minmax",
      inputs: {
        inputTex: "reduce1"
      },
      outputs: {
        outputColor: "reduce2"
      }
    },
    {
      name: "stats_final",
      type: "compute",  // GPGPU: final reduction to 1x1
      program: "stats_final",
      inputs: {
        inputTex: "reduce2"
      },
      outputs: {
        outputColor: "stats"
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
        outputColor: "outputColor"
      }
    }
  ];
}
