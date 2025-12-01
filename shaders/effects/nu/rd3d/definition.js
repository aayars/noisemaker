import { Effect } from '../../../src/runtime/effect.js';

export default class Rd3D extends Effect {
  name = "Rd3D";
  namespace = "nu";
  func = "rd3d";

  // Texture for caching 3D reaction-diffusion volume as 2D atlas
  // Size is volumeSize x (volumeSize * volumeSize) = volumeSize^3 voxels
  // Using 'global' prefix for automatic ping-pong double-buffering by pipeline
  textures = {
    // RD state buffer - 'global' prefix enables automatic double-buffering
    globalRdState: { 
      width: { param: 'volumeSize', default: 64 }, 
      height: { param: 'volumeSize', power: 2, default: 64 }, 
      format: "rgba16f" 
    },
  };

  // RD parameters plus 3D-specific controls
  globals = {
    "volumeSize": {
        "type": "int",
        "default": 32,
        "uniform": "volumeSize",
        "choices": {
            "16³": 16,
            "32³": 32,
            "64³": 64
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
        "min": 0,
        "max": 100,
        "uniform": "seed"
    },
    "iterations": {
      "type": "int",
      "default": 8,
      "uniform": "iterations",
      "min": 1,
      "max": 32,
      "ui": {
        "label": "iterations per frame",
        "control": "slider"
      }
    },
    "feed": {
      "type": "float",
      "default": 55,
      "uniform": "feed",
      "min": 10,
      "max": 110,
      "ui": {
        "label": "feed rate",
        "control": "slider"
      }
    },
    "kill": {
      "type": "float",
      "default": 62,
      "uniform": "kill",
      "min": 45,
      "max": 70,
      "ui": {
        "label": "kill rate",
        "control": "slider"
      }
    },
    "rate1": {
      "type": "float",
      "default": 100,
      "uniform": "rate1",
      "min": 50,
      "max": 120,
      "ui": {
        "label": "diffusion rate A",
        "control": "slider"
      }
    },
    "rate2": {
      "type": "float",
      "default": 50,
      "uniform": "rate2",
      "min": 20,
      "max": 80,
      "ui": {
        "label": "diffusion rate B",
        "control": "slider"
      }
    },
    "speed": {
      "type": "float",
      "default": 100,
      "uniform": "speed",
      "min": 10,
      "max": 200,
      "ui": {
        "label": "simulation speed",
        "control": "slider"
      }
    },
    "threshold": {
        "type": "float",
        "default": 0.25,
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
            "gradient": 1
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
      repeat: "iterations",
      inputs: {
        stateTex: "globalRdState",
        seedTex: "inputTex3d"
      },
      outputs: {
        color: "globalRdState"
      }
    },
    {
      name: "render",
      program: "rd3d",
      inputs: {
        volumeCache: "globalRdState"
      },
      outputs: {
        color: "outputTex"
      }
    }
  ];

  // Expose the RD state as the 3D output of this effect.
  outputTex3d = "globalRdState";
}
