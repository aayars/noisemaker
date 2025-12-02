import { Effect } from '../../../src/runtime/effect.js';

export default class Shape3D extends Effect {
  name = "Shape3D";
  namespace = "nu";
  func = "shape3d";

  // Texture for caching 3D shape volume as 2D atlas
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

  // 3D polyhedral shapes with threshold-based isosurfaces
  globals = {
    volumeSize: {
      type: "int",
      default: 64,
      uniform: "volumeSize",
      choices: {
        size32: 32,
        size64: 64,
        size128: 128
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
    loopAOffset: {
      type: "int",
      default: 40,
      uniform: "loopAOffset",
      choices: {
        "Platonic Solids:": null,
        tetrahedron: 10,
        cube: 20,
        octahedron: 30,
        dodecahedron: 40,
        icosahedron: 50,
        "Other Primitives:": null,
        sphere: 100,
        torus: 110,
        cylinder: 120,
        cone: 130,
        capsule: 140
      },
      ui: {
        label: "loop a",
        control: "dropdown"
      }
    },
    loopBOffset: {
      type: "int",
      default: 30,
      uniform: "loopBOffset",
      choices: {
        "Platonic Solids:": null,
        tetrahedron: 10,
        cube: 20,
        octahedron: 30,
        dodecahedron: 40,
        icosahedron: 50,
        "Other Primitives:": null,
        sphere: 100,
        torus: 110,
        cylinder: 120,
        cone: 130,
        capsule: 140
      },
      ui: {
        label: "loop b",
        control: "dropdown"
      }
    },
    loopAScale: {
      type: "float",
      default: 1,
      uniform: "loopAScale",
      min: 1,
      max: 100,
      ui: {
        label: "a scale",
        control: "slider"
      }
    },
    loopBScale: {
      type: "float",
      default: 1,
      uniform: "loopBScale",
      min: 1,
      max: 100,
      ui: {
        label: "b scale",
        control: "slider"
      }
    },
    loopAAmp: {
      type: "float",
      default: 50,
      uniform: "loopAAmp",
      min: -100,
      max: 100,
      ui: {
        label: "a power",
        control: "slider"
      }
    },
    loopBAmp: {
      type: "float",
      default: 50,
      uniform: "loopBAmp",
      min: -100,
      max: 100,
      ui: {
        label: "b power",
        control: "slider"
      }
    },
    seed: {
      type: "int",
      default: 1,
      uniform: "seed",
      min: 1,
      max: 100,
      ui: {
        label: "noise seed",
        control: "slider"
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
    colorMode: {
      type: "int",
      default: 0,
      uniform: "colorMode",
      choices: {
        "mono": 0,
        "rgb": 1
      },
      ui: {
        label: "color mode",
        control: "dropdown"
      }
    },
    orbitSpeed: {
      type: "int",
      default: 1,
      min: -5,
      max: 5,
      uniform: "orbitSpeed",
      ui: {
        label: "orbit speed"
      }
    },
    bgColor: {
      type: "vec3",
      default: [0.02, 0.02, 0.02],
      uniform: "bgColor",
      ui: {
        label: "background color",
        control: "color"
      }
    },
    bgAlpha: {
      type: "float",
      default: 1.0,
      min: 0,
      max: 1,
      uniform: "bgAlpha",
      ui: {
        label: "background alpha"
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
      program: "shape3d",
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
  // The volumeCache is a 2D atlas representation of the 3D volume (volumeSize x volumeSize^2).
  // Downstream effects using inputTex3d will receive this atlas and must use the same
  // atlas sampling convention (sampleVolumeAtlas function).
  outputTex3d = "volumeCache";
}
