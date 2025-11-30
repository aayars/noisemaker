import { Effect } from '../../../src/runtime/effect.js';

export default class Noise3D extends Effect {
  name = "Noise3D";
  namespace = "nu";
  func = "noise3d";

  // Texture for caching 3D noise volume as 2D atlas
  // Size is volumeSize x (volumeSize * volumeSize) = volumeSize^3 voxels
  textures = {
    volumeCache: { 
      width: { param: 'volumeSize', default: 64 }, 
      height: { param: 'volumeSize', power: 2, default: 4096 }, 
      format: "rgba16f" 
    },
    // Geometry buffer for MRT output (normals + depth)
    geoBuffer: {
      width: "resolution",
      height: "resolution",
      format: "rgba16f"
    }
  };

  // Same parameters as nu/noise plus 3D-specific threshold
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
    "scale": {
        "type": "float",
        "default": 3,
        "min": 0,
        "max": 100,
        "uniform": "scale"
    },
    "octaves": {
        "type": "int",
        "default": 1,
        "min": 1,
        "max": 6,
        "uniform": "octaves"
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
    },
    "ridges": {
        "type": "boolean",
        "default": false,
        "uniform": "ridged"
    },
    "seed": {
        "type": "float",
        "default": 0,
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
    }
  };

  passes = [
    {
      name: "precompute",
      program: "precompute",
      condition: "needsPrecompute",
      inputs: {},
      outputs: {
        color: "volumeCache"
      }
    },
    {
      name: "main",
      program: "noise3d",
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
}
