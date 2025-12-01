import { Effect } from '../../../src/runtime/effect.js';

export default class Ca3D extends Effect {
  name = "Ca3D";
  namespace = "nu";
  func = "ca3d";

  // Texture for caching 3D cellular automata volume as 2D atlas
  // Size is volumeSize x (volumeSize * volumeSize) = volumeSize^3 voxels
  // Using 'global' prefix for automatic ping-pong double-buffering by pipeline
  textures = {
    // CA state buffer - 'global' prefix enables automatic double-buffering
    globalCaState: { 
      width: { param: 'volumeSize', default: 32 }, 
      height: { param: 'volumeSize', power: 2, default: 1024 }, 
      format: "rgba16f" 
    },
  };

  // CA parameters plus 3D-specific controls
  globals = {
    "volumeSize": {
        "type": "int",
        "default": 32,
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
    "seed": {
        "type": "float",
        "default": 1,
        "min": 1,
        "max": 100,
        "uniform": "seed",
        "ui": {
            "label": "seed"
        }
    },
    "resetState": {
        "type": "boolean",
        "default": false,
        "uniform": "resetState",
        "ui": {
            "control": "button",
            "buttonLabel": "reset",
            "category": "control"
        }
    },
    "ruleIndex": {
        "type": "int",
        "default": 0,
        "uniform": "ruleIndex",
        "choices": {
            "rule445M": 0,
            "rule678": 1,
            "amoeba": 2,
            "builder1": 3,
            "builder2": 4,
            "clouds": 5,
            "crystalGrowth": 6,
            "diamoeba": 7,
            "pyroclastic": 8,
            "slowDecay": 9,
            "spikeyGrowth": 10
        },
        "ui": {
            "label": "rules",
            "control": "dropdown"
        }
    },
    "neighborMode": {
        "type": "int",
        "default": 0,
        "uniform": "neighborMode",
        "choices": {
            "moore": 0,
            "vonNeumann": 1
        },
        "ui": {
            "label": "neighborhood",
            "control": "dropdown"
        }
    },
    "speed": {
        "type": "float",
        "default": 1,
        "min": 0.1,
        "max": 10,
        "uniform": "speed",
        "ui": {
            "label": "speed",
            "control": "slider"
        }
    },
    "density": {
        "type": "float",
        "default": 50,
        "min": 1,
        "max": 100,
        "uniform": "density",
        "ui": {
            "label": "initial density %",
            "control": "slider"
        }
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
            "age": 1
        },
        "ui": {
            "label": "color mode",
            "control": "dropdown"
        }
    },
    "orbitSpeed": {
        "type": "int",
        "default": 1,
        "min": -5,
        "max": 5,
        "uniform": "orbitSpeed",
        "ui": {
            "label": "orbit speed"
        }
    },
    "bgColor": {
        "type": "vec3",
        "default": [0.02, 0.02, 0.02],
        "uniform": "bgColor",
        "ui": {
            "label": "background color",
            "control": "color"
        }
    },
    "bgAlpha": {
        "type": "float",
        "default": 1.0,
        "min": 0,
        "max": 1,
        "uniform": "bgAlpha",
        "ui": {
            "label": "background alpha"
        }
    },
    "weight": {
        "type": "float",
        "default": 0,
        "min": 0,
        "max": 100,
        "uniform": "weight",
        "ui": {
            "label": "input weight",
            "control": "slider"
        }
    }
  };

  passes = [
    {
      name: "simulate",
      program: "simulate",
      inputs: {
        stateTex: "globalCaState",
        seedTex: "inputTex3d"
      },
      outputs: {
        color: "globalCaState"
      }
    },
    {
      name: "render",
      program: "ca3d",
      inputs: {
        volumeCache: "globalCaState"
      },
      outputs: {
        color: "outputTex"
      }
    }
  ];

  // Expose the CA state as the 3D output of this effect.
  outputTex3d = "globalCaState";
}
