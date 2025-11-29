import { Effect } from '../../../src/runtime/effect.js';

export default class MediaPost extends Effect {
  name = "MediaPost";
  namespace = "nd";
  func = "mediaPost";

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
    source: {
      type: "int",
      default: 1,
      uniform: "source",
      choices: {
        Camera: 0,
        File: 1
      },
      ui: {
        label: "source",
        control: "dropdown"
      }
    },
    position: {
      type: "int",
      default: 4,
      uniform: "position",
      choices: {
        "Top Left": 0,
        "Top Center": 1,
        "Top Right": 2,
        "Mid Left": 3,
        "Mid Center": 4,
        "Mid Right": 5,
        "Bottom Left": 6,
        "Bottom Center": 7,
        "Bottom Right": 8
      },
      ui: {
        label: "position",
        control: "dropdown"
      }
    },
    tiling: {
      type: "int",
      default: 0,
      uniform: "tiling",
      choices: {
        None: 0,
        "Horiz And Vert": 1,
        "Horiz Only": 2,
        "Vert Only": 3
      },
      ui: {
        label: "tiling",
        control: "dropdown"
      }
    },
    scaleAmt: {
      type: "float",
      default: 100,
      uniform: "scaleAmt",
      min: 25,
      max: 2000,
      ui: {
        label: "scale %",
        control: "slider"
      }
    },
    rotation: {
      type: "int",
      default: 0,
      uniform: "rotation",
      min: -180,
      max: 180,
      ui: {
        label: "rotate",
        control: "slider"
      }
    },
    offsetX: {
      type: "float",
      default: 0,
      uniform: "offsetX",
      min: -100,
      max: 100,
      ui: {
        label: "offset x",
        control: "slider"
      }
    },
    offsetY: {
      type: "float",
      default: 0,
      uniform: "offsetY",
      min: -100,
      max: 100,
      ui: {
        label: "offset y",
        control: "slider"
      }
    },
    imageSize: {
      type: "vec2",
      default: [1280, 720],
      uniform: "imageSize",
      ui: {
        control: false
      }
    }
  };

  passes = [
    {
      name: "render",
      program: "mediaPost",
      inputs: {
        inputTex: "inputTex",
        imageTex: "inputTex"
      },

      outputs: {
        fragColor: "outputTex"
      }
    }
  ];
}
