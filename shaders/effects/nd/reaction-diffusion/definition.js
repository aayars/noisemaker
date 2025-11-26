import { Effect } from '../../../src/runtime/effect.js';

export default class ReactionDiffusion extends Effect {
  name = "ReactionDiffusion";
  namespace = "nd";
  func = "reaction_diffusion";

  globals = {
    seed: {
      type: "int",
      default: 1,
      uniform: "seed",
      min: 1,
      max: 100,
      ui: {
        label: "seed",
        control: "slider"
      }
    },
    sourceF: {
      type: "int",
      default: 0,
      uniform: "sourceF",
      choices: {
        Slider: 0,
        "Slider + Input": 6,
        Brightness: 1,
        Darkness: 2,
        Red: 3,
        Green: 4,
        Blue: 5
      },
      ui: {
        label: "feed source",
        control: "dropdown"
      }
    },
    feed: {
      type: "float",
      default: 18,
      uniform: "feed",
      min: 10,
      max: 110,
      ui: {
        label: "feed value",
        control: "slider"
      }
    },
    sourceK: {
      type: "int",
      default: 0,
      uniform: "sourceK",
      choices: {
        Slider: 0,
        "Slider + Input": 6,
        Brightness: 1,
        Darkness: 2,
        Red: 3,
        Green: 4,
        Blue: 5
      },
      ui: {
        label: "kill source",
        control: "dropdown"
      }
    },
    kill: {
      type: "float",
      default: 51,
      uniform: "kill",
      min: 45,
      max: 70,
      ui: {
        label: "kill value",
        control: "slider"
      }
    },
    sourceR1: {
      type: "int",
      default: 0,
      uniform: "sourceR1",
      choices: {
        Slider: 0,
        "Slider + Input": 6,
        Brightness: 1,
        Darkness: 2,
        Red: 3,
        Green: 4,
        Blue: 5
      },
      ui: {
        label: "rate 1 source",
        control: "dropdown"
      }
    },
    rate1: {
      type: "float",
      default: 111,
      uniform: "rate1",
      min: 50,
      max: 120,
      ui: {
        label: "rate 1 value",
        control: "slider"
      }
    },
    sourceR2: {
      type: "int",
      default: 0,
      uniform: "sourceR2",
      choices: {
        Slider: 0,
        "Slider + Input": 6,
        Brightness: 1,
        Darkness: 2,
        Red: 3,
        Green: 4,
        Blue: 5
      },
      ui: {
        label: "rate 2 source",
        control: "dropdown"
      }
    },
    rate2: {
      type: "float",
      default: 24,
      uniform: "rate2",
      min: 20,
      max: 50,
      ui: {
        label: "rate 2 value",
        control: "slider"
      }
    },
    weight: {
      type: "float",
      default: 50,
      uniform: "weight",
      min: 0,
      max: 100,
      ui: {
        label: "input weight",
        control: "slider"
      }
    },
    speed: {
      type: "float",
      default: 100,
      uniform: "speed",
      min: 10,
      max: 145,
      ui: {
        label: "speed",
        control: "slider"
      }
    },
    zoom: {
      type: "int",
      default: 8,
      uniform: "zoom",
      choices: {
        "1x": 1,
        "2x": 2,
        "4x": 4,
        "8x": 8,
        "16x": 16
      },
      ui: {
        label: "zoom",
        control: "dropdown"
      }
    },
    smoothing: {
      type: "int",
      default: 1,
      uniform: "smoothing",
      choices: {
        Constant: 0,
        Linear: 1,
        Hermite: 2,
        "Catmull Rom 3x3": 3,
        "Catmull Rom 4x4": 4,
        "B Spline 3x3": 5,
        "B Spline 4x4": 6
      },
      ui: {
        label: "smoothing",
        control: "dropdown"
      }
    }
  };

  passes = [
    {
      name: "simulate",
      type: "render",
      program: "reaction-diffusion-fb",
      inputs: {
        bufTex: "global_reaction_diffusion_state",
        inputTex: "inputTex"
      },
      outputs: {
        fragColor: "global_reaction_diffusion_state"
      }
    },
    {
      name: "render",
      type: "render",
      program: "reaction-diffusion",
      inputs: {
        fbTex: "global_reaction_diffusion_state"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
