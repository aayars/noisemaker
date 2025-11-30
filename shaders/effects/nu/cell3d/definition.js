import { Effect } from '../../../src/runtime/effect.js';

export default class Cell3D extends Effect {
  name = "Cell3D";
  namespace = "nu";
  func = "cell3d";

  // Track previous uniform values for dirty detection
  _prevScale = null;
  _prevSeed = null;
  _prevMetric = null;
  _prevCellVariation = null;
  _prevVolumeSize = null;
  _needsPrecompute = true;

  // Parameters analogous to nu/cell plus 3D threshold settings
  globals = {
    "volumeSize": {
        "type": "int",
        "default": 64,
        "uniform": "volumeSize",
        "choices": {
            "32³": 32,
            "64³": 64,
            "128³": 128
        },
        "ui": {
            "label": "volume resolution",
            "control": "dropdown"
        }
    },
    "filtering": {
        "type": "int",
        "default": 0,
        "uniform": "filtering",
        "choices": {
            "isosurface": 0,
            "voxel": 1
        },
        "ui": {
            "label": "filtering",
            "control": "dropdown"
        }
    },
    "metric": {
        "type": "int",
        "default": 0,
        "uniform": "metric",
        "choices": {
            "Euclidean": 0,
            "Manhattan": 1,
            "Chebyshev": 2
        },
        "ui": {
            "label": "distance metric",
            "control": "dropdown"
        }
    },
    "scale": {
        "type": "float",
        "default": 3,
        "min": 1,
        "max": 20,
        "uniform": "scale",
        "ui": {
            "label": "cell scale"
        }
    },
    "cellVariation": {
        "type": "float",
        "default": 50,
        "min": 0,
        "max": 100,
        "uniform": "cellVariation",
        "ui": {
            "label": "cell variation"
        }
    },
    "seed": {
        "type": "float",
        "default": 1,
        "min": 0,
        "max": 100,
        "uniform": "seed"
    },
    "threshold": {
        "type": "float",
        "default": 0.5,
        "min": 0,
        "max": 1,
        "uniform": "threshold",
        "ui": {
            "label": "surface threshold"
        }
    },
    "invert": {
        "type": "boolean",
        "default": false,
        "uniform": "invert",
        "ui": {
            "label": "invert threshold"
        }
    },
    "colorMode": {
        "type": "int",
        "default": 0,
        "uniform": "colorMode",
        "choices": {
            "mono": 0,
            "rgb": 1
        },
        "ui": {
            "label": "color mode",
            "control": "dropdown"
        }
    }
  };

  // Define the volume texture for caching cell noise
  // Size is volumeSize x (volumeSize * volumeSize) = volumeSize^3 voxels
  textures = {
    "volumeCache": {
      width: { param: 'volumeSize', default: 64 },
      height: { param: 'volumeSize', power: 2, default: 4096 },
      format: "rgba16f"
    },
    // Geometry buffer for MRT output (normals + depth)
    "geoBuffer": {
      width: "resolution",
      height: "resolution",
      format: "rgba16f"
    }
  };

  passes = [
    {
      name: "precompute",
      program: "precompute",
      inputs: {},
      outputs: {
        color: "volumeCache"
      },
      condition: "needsPrecompute"  // Only run when cell noise uniforms change
    },
    {
      name: "main",
      program: "cell3d",
      inputs: {
        volumeCache: "volumeCache"
      },
      drawBuffers: 2,
      outputs: {
        color: "outputTex",
        geoOut: "geoBuffer"
      }
    }
  ];

  // Expose geometry buffer for downstream 3D post-processing effects
  outputGeo = "geoBuffer";

  // Expose the volumeCache as the 3D output of this effect.
  // The volumeCache is a 2D atlas representation of the 3D volume (volumeSize x volumeSize^2).
  // Downstream effects using inputTex3d will receive this atlas and must use the same
  // atlas sampling convention (sampleVolumeAtlas function).
  outputTex3d = "volumeCache";

  /**
   * Check if cell-noise-affecting uniforms have changed
   */
  onUpdate(context) {
    const uniforms = context.uniforms || {};
    const scale = uniforms.scale ?? this.globals.scale.default;
    const seed = uniforms.seed ?? this.globals.seed.default;
    const metric = uniforms.metric ?? this.globals.metric.default;
    const cellVariation = uniforms.cellVariation ?? this.globals.cellVariation.default;
    const volumeSize = uniforms.volumeSize ?? this.globals.volumeSize.default;

    // Check for changes
    if (this._prevScale !== scale ||
        this._prevSeed !== seed ||
        this._prevMetric !== metric ||
        this._prevCellVariation !== cellVariation ||
        this._prevVolumeSize !== volumeSize) {
      this._needsPrecompute = true;
      this._prevScale = scale;
      this._prevSeed = seed;
      this._prevMetric = metric;
      this._prevCellVariation = cellVariation;
      this._prevVolumeSize = volumeSize;
    } else {
      this._needsPrecompute = false;
    }

    return { needsPrecompute: this._needsPrecompute };
  }
}
