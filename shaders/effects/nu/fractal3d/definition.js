import { Effect } from '../../../src/runtime/effect.js';

/**
 * nu/fractal3d - 3D fractal volume renderer
 * Renders 3D fractals (Mandelbulb, Mandelcube) using precomputed volume caching
 * and raymarching visualization, similar to nu/noise3d and nu/shape3d.
 */
export default class Fractal3D extends Effect {
  name = "Fractal3D";
  namespace = "nu";
  func = "fractal3d";

  // Texture for caching 3D fractal volume as 2D atlas
  // Size is volumeSize x (volumeSize * volumeSize) = volumeSize^3 voxels
  textures = {
    volumeCache: { 
      width: { param: 'volumeSize', default: 64 }, 
      height: { param: 'volumeSize', power: 2, default: 4096 }, 
      format: "rgba16f" 
    },
    // Geometry buffer for downstream 3D post-processing
    // RGB = world-space normal, A = linear depth
    geoBuffer: {
      width: "resolution",
      height: "resolution",
      format: "rgba16f"
    }
  };

  globals = {
    volumeSize: {
      type: "int",
      default: 64,
      uniform: "volumeSize",
      choices: {
        "32³": 32,
        "64³": 64,
        "128³": 128
      },
      ui: {
        label: "volume resolution",
        control: "dropdown"
      }
    },
    filtering: {
      type: "int",
      default: 0,
      uniform: "filtering",
      choices: {
        "isosurface": 0,
        "voxel": 1
      },
      ui: {
        label: "filtering",
        control: "dropdown"
      }
    },
    fractalType: {
      type: "int",
      default: 0,
      uniform: "fractalType",
      choices: {
        "Mandelbulb": 0,
        "Mandelcube": 1,
        "Julia Bulb": 2,
        "Julia Cube": 3
      },
      ui: {
        label: "type",
        control: "dropdown"
      }
    },
    power: {
      type: "float",
      default: 8,
      min: 2,
      max: 16,
      uniform: "power",
      ui: {
        label: "power",
        control: "slider"
      }
    },
    iterations: {
      type: "int",
      default: 10,
      min: 1,
      max: 20,
      uniform: "iterations",
      ui: {
        label: "iterations",
        control: "slider"
      }
    },
    bailout: {
      type: "float",
      default: 2,
      min: 1,
      max: 8,
      uniform: "bailout",
      ui: {
        label: "bailout",
        control: "slider"
      }
    },
    juliaX: {
      type: "float",
      default: 0,
      min: -100,
      max: 100,
      uniform: "juliaX",
      ui: {
        label: "julia X",
        control: "slider"
      }
    },
    juliaY: {
      type: "float",
      default: 0,
      min: -100,
      max: 100,
      uniform: "juliaY",
      ui: {
        label: "julia Y",
        control: "slider"
      }
    },
    juliaZ: {
      type: "float",
      default: 0,
      min: -100,
      max: 100,
      uniform: "juliaZ",
      ui: {
        label: "julia Z",
        control: "slider"
      }
    },
    colorMode: {
      type: "int",
      default: 0,
      uniform: "colorMode",
      choices: {
        "mono": 0,
        "orbit trap": 1,
        "iteration": 2
      },
      ui: {
        label: "color mode",
        control: "dropdown"
      }
    },
    threshold: {
      type: "float",
      default: 0.5,
      min: 0,
      max: 1,
      uniform: "threshold",
      ui: {
        label: "surface threshold"
      }
    },
    invert: {
      type: "boolean",
      default: false,
      uniform: "invert",
      ui: {
        label: "invert threshold"
      }
    },
    seed: {
      type: "float",
      default: 0,
      min: 0,
      max: 100,
      uniform: "seed"
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
      program: "fractal3d",
      drawBuffers: 2,
      inputs: {
        volumeCache: "volumeCache"
      },
      outputs: {
        color: "outputTex",
        geoOut: "geoBuffer"
      }
    }
  ];

  // Geometry buffer output for downstream 3D-aware effects (normals + depth)
  outputGeo = "geoBuffer";

  // Expose the volumeCache as the 3D output of this effect.
  outputTex3d = "volumeCache";
}
