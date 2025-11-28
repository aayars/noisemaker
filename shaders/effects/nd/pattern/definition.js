import { Effect } from '../../../src/runtime/effect.js';

export default class Pattern extends Effect {
  name = "Pattern";
  namespace = "nd";
  func = "pattern";


  // WGSL uniform packing layout - maps uniform names to vec4 slots/components
  uniformLayout = {
        resolution: { slot: 0, components: 'xy' },
    time: { slot: 0, components: 'z' },
    seed: { slot: 0, components: 'w' },
    patternType: { slot: 1, components: 'x' },
    scale: { slot: 1, components: 'y' },
    skewAmt: { slot: 1, components: 'z' },
    rotation: { slot: 1, components: 'w' },
    lineWidth: { slot: 2, components: 'x' },
    animation: { slot: 2, components: 'y' },
    speed: { slot: 2, components: 'z' },
    sharpness: { slot: 2, components: 'w' },
    color1: { slot: 3, components: 'xyz' },
    color2: { slot: 4, components: 'xyz' }
  };
  globals = {
    patternType: {
      type: "int",
      default: 1,
      uniform: "patternType",
      choices: {
        Checkers: 0,
        Dots: 1,
        Grid: 2,
        Hearts: 3,
        Hexagons: 4,
        Rings: 5,
        Squares: 6,
        Stripes: 7,
        Waves: 8,
        Zigzag: 9,
        "Truchet Lines": 10,
        "Truchet Curves": 11
      },
      ui: {
        label: "pattern",
        control: "dropdown"
      }
    },
    scale: {
      type: "float",
      default: 80,
      uniform: "scale",
      min: 1,
      max: 100,
      ui: {
        label: "scale",
        control: "slider"
      }
    },
    skewAmt: {
      type: "float",
      default: 0,
      uniform: "skewAmt",
      min: -100,
      max: 100,
      ui: {
        label: "skew",
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
    lineWidth: {
      type: "float",
      default: 100,
      uniform: "lineWidth",
      min: 1,
      max: 100,
      ui: {
        label: "width",
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
        label: "truchet seed",
        control: "slider"
      }
    },
    animation: {
      type: "int",
      default: 0,
      uniform: "animation",
      choices: {
        None: 0,
        "Pan With Rotation": 1,
        "Pan Left": 2,
        "Pan Right": 3,
        "Pan Up": 4,
        "Pan Down": 5,
        "Rotate Cw": 6,
        "Rotate Ccw": 7
      },
      ui: {
        label: "animation",
        control: "dropdown"
      }
    },
    speed: {
      type: "int",
      default: 1,
      uniform: "speed",
      min: 0,
      max: 10,
      ui: {
        label: "speed",
        control: "slider"
      }
    },
    sharpness: {
      type: "float",
      default: 100,
      uniform: "sharpness",
      min: 0,
      max: 100,
      ui: {
        label: "sharpness",
        control: "slider"
      }
    },
    color1: {
      type: "vec3",
      default: [1.0, 0.9176470588235294, 0.19215686274509805],
      uniform: "color1",
      ui: {
        label: "color 1",
        control: "color"
      }
    },
    color2: {
      type: "vec3",
      default: [0.0, 0.0, 0.0],
      uniform: "color2",
      ui: {
        label: "color 2",
        control: "color"
      }
    }
  };

  passes = [
    {
      name: "render",
      program: "pattern",
      inputs: {
      },

      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
