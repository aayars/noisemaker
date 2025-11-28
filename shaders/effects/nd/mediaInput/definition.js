import { Effect } from '../../../src/runtime/effect.js';

export default class MediaInput extends Effect {
  name = "MediaInput";
  namespace = "nd";
  func = "mediaInput";


  // WGSL uniform packing layout - maps uniform names to vec4 slots/components
  uniformLayout = {
        resolution: { slot: 0, components: 'xy' },
    time: { slot: 0, components: 'z' },
    seed: { slot: 0, components: 'w' },
    posIndex: { slot: 1, components: 'x' },
    rotation: { slot: 1, components: 'y' },
    scaleAmt: { slot: 1, components: 'z' },
    offsetX: { slot: 1, components: 'w' },
    offsetY: { slot: 2, components: 'x' },
    tiling: { slot: 2, components: 'y' },
    flip: { slot: 2, components: 'z' },
    backgroundOpacity: { slot: 2, components: 'w' },
    backgroundColor: { slot: 3, components: 'xyz' },
    imageSize: { slot: 4, components: 'xy' }
  };
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
    file: {
      type: "file",
      default: null,
      uniform: "file",
      ui: {
        label: "media file",
        control: "slider"
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
    flip: {
      type: "int",
      default: 0,
      uniform: "flip",
      choices: {
        None: 0,
        "Flip:": null,
        All: 1,
        Horizontal: 2,
        Vertical: 3,
        "Mirror:": null,
        "Left → Right": 11,
        "Left ← Right": 12,
        "Up → Down": 13,
        "Up ← Down": 14,
        "L → R / U → D": 15,
        "L → R / U ← D": 16,
        "L ← R / U → D": 17,
        "L ← R / U ← D": 18
      },
      ui: {
        label: "flip/mirror",
        control: "dropdown"
      }
    },
    scaleAmt: {
      type: "float",
      default: 100,
      uniform: "scaleAmt",
      min: 25,
      max: 400,
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
    backgroundColor: {
      type: "vec3",
      default: [0.0, 0.0, 0.0],
      uniform: "backgroundColor",
      ui: {
        label: "bkg color",
        control: "color"
      }
    },
    backgroundOpacity: {
      type: "float",
      default: 0,
      uniform: "backgroundOpacity",
      min: 0,
      max: 100,
      ui: {
        label: "bkg opacity",
        control: "slider"
      }
    },
    imageSize: {
      type: "vec2",
      default: [1024, 1024],
      uniform: "imageSize",
      ui: {
        label: "image size",
        control: "slider"
      }
    }
  };

  passes = [
    {
      name: "render",
      program: "mediaInput",
      inputs: {
        imageTex: "imageTex"
      },

      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
