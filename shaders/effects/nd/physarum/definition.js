import { Effect } from '../../../src/runtime/effect.js';

export default class Physarum extends Effect {
  name = "Physarum";
  namespace = "nd";
  func = "physarum";

  globals = {
    zoom: {
      type: "int",
      default: 1,
      uniform: "zoom",
      choices: {
        x1: 1,
        x2: 2,
        x4: 4,
        x8: 8,
        x16: 16,
        x32: 32,
        x64: 64
      },
      ui: {
        label: "zoom",
        type: "option",
        category: "transform"
      }
    },
    deltaTime: {
      type: "float",
      default: 0.016,
      uniform: "deltaTime",
      ui: {
        control: false
      }
    },
    moveSpeed: {
      type: "float",
      default: 1.7800000000000011,
      uniform: "moveSpeed",
      min: 0.05,
      max: 3,
      ui: {
        label: "move speed",
        type: "float",
        step: 0.01,
        category: "agents"
      }
    },
    turnSpeed: {
      type: "float",
      default: 1,
      uniform: "turnSpeed",
      min: 0,
      max: 3.14159,
      ui: {
        label: "turn speed",
        type: "float",
        step: 0.01,
        category: "agents"
      }
    },
    sensorAngle: {
      type: "float",
      default: 1.2599999999999971,
      uniform: "sensorAngle",
      min: 0.1,
      max: 1.5,
      ui: {
        label: "sensor angle",
        type: "float",
        step: 0.01,
        category: "agents"
      }
    },
    sensorDistance: {
      type: "float",
      default: 30.700000000000003,
      uniform: "sensorDistance",
      min: 2,
      max: 32,
      ui: {
        label: "sensor distance",
        type: "float",
        step: 0.1,
        category: "agents"
      }
    },
    decay: {
      type: "float",
      default: 0.1,
      uniform: "decay",
      min: 0,
      max: 0.1,
      ui: {
        label: "decay",
        type: "float",
        step: 0.001,
        category: "chemistry"
      }
    },
    diffusion: {
      type: "float",
      default: 0.25,
      uniform: "diffusion",
      min: 0,
      max: 1,
      ui: {
        label: "diffusion",
        type: "float",
        step: 0.01,
        category: "chemistry"
      }
    },
    intensity: {
      type: "float",
      default: 75,
      uniform: "intensity",
      min: 0,
      max: 100,
      step: 1,
      ui: {
        label: "intensity",
        type: "float",
        category: "input"
      }
    },
    depositAmount: {
      type: "float",
      default: 0.05,
      uniform: "depositAmount",
      min: 0,
      max: 0.05,
      ui: {
        label: "deposit",
        type: "float",
        step: 0.001,
        category: "chemistry"
      }
    },
    lifetime: {
      type: "float",
      default: 10.998912608250976,
      uniform: "lifetime",
      min: 0,
      max: 60,
      ui: {
        label: "lifetime",
        type: "float",
        step: 1,
        category: "agents"
      }
    },
    weight: {
      type: "float",
      default: 0,
      uniform: "weight",
      min: 0,
      max: 100,
      ui: {
        label: "input weight",
        type: "float",
        category: "input"
      }
    },
    inputIntensity: {
      type: "float",
      default: 0,
      uniform: "inputIntensity",
      min: 0,
      max: 100,
      step: 1,
      ui: {
        label: "input intensity",
        type: "float",
        category: "input"
      }
    },
    colorMode: {
      type: "int",
      default: 0,
      uniform: "colorMode",
      choices: {
        "mono": 0,
        "palette": 1
      },
      ui: {
        label: "color mode",
        type: "option",
        category: "color"
      }
    },
    palette: {
      type: "palette",
      default: "sproingtime",
      uniform: "palette",
      requires: {
        "colorMode": 1
      },
      ui: {
        label: "palette",
        type: "palette",
        category: "palette",
        requires: {
          "colorMode": 1
        }
      }
    },
    paletteMode: {
      type: "int",
      default: 3,
      uniform: "paletteMode",
      choices: {
        "hsv": 1,
        "oklab": 2,
        "rgb": 3,
        "off": 4
      },
      ui: {
        control: false
      }
    },
    paletteOffset: {
      type: "vec3",
      default: [0.56, 0.69, 0.32],
      uniform: "paletteOffset",
      ui: {
        control: false
      }
    },
    paletteAmp: {
      type: "vec3",
      default: [0.9, 0.43, 0.34],
      uniform: "paletteAmp",
      ui: {
        control: false
      }
    },
    paletteFreq: {
      type: "vec3",
      default: [1, 1, 1],
      uniform: "paletteFreq",
      ui: {
        control: false
      }
    },
    palettePhase: {
      type: "vec3",
      default: [0.03, 0.8, 0.4],
      uniform: "palettePhase",
      ui: {
        control: false
      }
    },
    cyclePalette: {
      type: "int",
      default: -1,
      uniform: "cyclePalette",
      choices: {
        "off": 0,
        "forward": 1,
        "backward": -1
      },
      requires: {
        "colorMode": 1
      },
      ui: {
        label: "cycle palette",
        type: "option",
        category: "palette",
        requires: {
          "colorMode": 1
        }
      }
    },
    rotatePalette: {
      type: "float",
      default: 34.168161218985915,
      uniform: "rotatePalette",
      min: 0,
      max: 100,
      requires: {
        "colorMode": 1
      },
      ui: {
        label: "rotate palette",
        type: "float",
        category: "palette",
        requires: {
          "colorMode": 1
        }
      }
    },
    repeatPalette: {
      type: "int",
      default: 1,
      uniform: "repeatPalette",
      min: 1,
      max: 5,
      requires: {
        "colorMode": 1
      },
      ui: {
        label: "repeat palette",
        type: "int",
        category: "palette",
        requires: {
          "colorMode": 1
        }
      }
    },
    spawnPattern: {
      type: "int",
      default: 1,
      uniform: "spawnPattern",
      choices: {
        "random": 0,
        "clusters": 1,
        "ring": 2,
        "spiral": 3
      },
      ui: {
        label: "pattern",
        type: "option",
        category: "state"
      }
    },
    resetState: {
      type: "button",
      default: false,
      uniform: "resetState",
      ui: {
        label: "state",
        type: "button",
        buttonLabel: "reset",
        category: "util"
      }
    }
  };

  passes = [
    {
      name: "agent",
      program: "agent",
      inputs: {
        stateTex: "globalPhysarumState",
        bufTex: "globalPhysarumTrail",
        inputTex: "inputTex"
      },
      outputs: {
        fragColor: "globalPhysarumState"
      },
      uniforms: {
        spawnPattern: "spawnPattern"
      }
    },
    {
      name: "diffuse",
      program: "diffuse",
      inputs: {
        sourceTex: "globalPhysarumTrail"
      },
      outputs: {
        fragColor: "globalPhysarumTrail"
      }
    },
    {
      name: "deposit",
      program: "deposit",
      drawMode: "points",
      count: 1000000,
      blend: true,
      inputs: {
        stateTex: "globalPhysarumState",
        inputTex: "inputTex"
      },
      outputs: {
        fragColor: "globalPhysarumTrail"
      }
    },
    {
      name: "render",
      program: "physarum",
      inputs: {
        bufTex: "globalPhysarumTrail",
        inputTex: "inputTex"
      },
      outputs: {
        fragColor: "outputTex"
      }
    }
  ];
}
