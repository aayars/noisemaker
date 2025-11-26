import { Effect } from '../../../src/runtime/effect.js';

/**
 * Reindex
 * WebGL port of the Noisemaker reindex effect.
 */
export default class Reindex extends Effect {
  name = "Reindex";
  namespace = "nm";
  func = "reindex";

  globals = {
    displacement: {
        type: "float",
        default: 0.5,
        min: 0,
        max: 2,
        step: 0.01,
        uniform: "uDisplacement",
        ui: {
            label: "Displacement",
            control: "slider"
        }
    }
  };

  textures = {
    statsTiles: {
      format: "rgba16f"
    },
    globalStats: {
      width: 1,
      height: 1,
      format: "rgba16f"
    }
  };

  passes = [
    {
      name: "stats",
      type: "compute",  // GPGPU: compute per-tile stats
      program: "nm_reindex_stats",
      inputs: {
        input_texture: "inputTex"
      },
      outputs: {
        color: "statsTiles"
      }
    },
    {
      name: "reduce",
      type: "compute",  // GPGPU: reduce to global stats
      program: "nm_reindex_reduce",
      inputs: {
        stats_texture: "statsTiles"
      },
      outputs: {
        color: "globalStats"
      }
    },
    {
      name: "apply",
      type: "render",
      program: "nm_reindex_apply",
      inputs: {
        input_texture: "inputTex",
        stats_texture: "globalStats"
      },
      outputs: {
        color: "outputColor"
      }
    }
  ];
}
