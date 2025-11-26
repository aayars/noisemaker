import { Effect } from '../../../src/runtime/effect.js';
import { stdEnums } from '../../../src/lang/std_enums.js';

const paletteChoices = {};
for (const [key, val] of Object.entries(stdEnums.palette)) {
  paletteChoices[key] = val.value;
}

export default class Shapes3D extends Effect {
  name = "Shapes3d";
  namespace = "nd";
  func = "shapes_3d";

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
    shapeA: {
      type: "int",
      default: 30,
      uniform: "shapeA",
      choices: {
        "Capsule Horiz": 70,
        "Capsule Vert": 60,
        Cube: 10,
        "Cylinder Horiz": 50,
        "Cylinder Vert": 40,
        Octahedron: 80,
        Sphere: 20,
        "Torus Horiz": 31,
        "Torus Vert": 30
      },
      ui: {
        label: "shape a",
        control: "dropdown"
      }
    },
    shapeB: {
      type: "int",
      default: 10,
      uniform: "shapeB",
      choices: {
        "Capsule Horiz": 70,
        "Capsule Vert": 60,
        Cube: 10,
        "Cylinder Horiz": 50,
        "Cylinder Vert": 40,
        Octahedron: 80,
        Sphere: 20,
        "Torus Horiz": 31,
        "Torus Vert": 30
      },
      ui: {
        label: "shape b",
        control: "dropdown"
      }
    },
    shapeAScale: {
      type: "float",
      default: 64,
      uniform: "shapeAScale",
      min: 1,
      max: 100,
      ui: {
        label: "a scale",
        control: "slider"
      }
    },
    shapeBScale: {
      type: "float",
      default: 27,
      uniform: "shapeBScale",
      min: 1,
      max: 100,
      ui: {
        label: "b scale",
        control: "slider"
      }
    },
    shapeAThickness: {
      type: "float",
      default: 5,
      uniform: "shapeAThickness",
      min: 1,
      max: 50,
      ui: {
        label: "a thickness",
        control: "slider"
      }
    },
    shapeBThickness: {
      type: "float",
      default: 5,
      uniform: "shapeBThickness",
      min: 1,
      max: 50,
      ui: {
        label: "b thickness",
        control: "slider"
      }
    },
    blendMode: {
      type: "int",
      default: 10,
      uniform: "blendMode",
      choices: {
        Intersect: null,
        Max: 40,
        "Smooth Max": 20,
        Union: null,
        Min: 30,
        "Smooth Min": 10,
        Subtract: null,
        "A B": 51,
        "B A": 50,
        "Smooth A B": 26,
        "Smooth B A": 25
      },
      ui: {
        label: "blend",
        control: "dropdown"
      }
    },
    smoothness: {
      type: "float",
      default: 1,
      uniform: "smoothness",
      min: 1,
      max: 100,
      ui: {
        label: "smoothness",
        control: "slider"
      }
    },
    spin: {
      type: "float",
      default: 0,
      uniform: "spin",
      min: -180,
      max: 180,
      ui: {
        label: "spin",
        control: "slider"
      }
    },
    flip: {
      type: "float",
      default: 0,
      uniform: "flip",
      min: -180,
      max: 180,
      ui: {
        label: "flip",
        control: "slider"
      }
    },
    spinSpeed: {
      type: "float",
      default: 2,
      uniform: "spinSpeed",
      min: -10,
      max: 10,
      ui: {
        label: "spin speed",
        control: "slider"
      }
    },
    flipSpeed: {
      type: "float",
      default: 2,
      uniform: "flipSpeed",
      min: -10,
      max: 10,
      ui: {
        label: "flip speed",
        control: "slider"
      }
    },
    cameraDist: {
      type: "float",
      default: 8,
      uniform: "cameraDist",
      min: 5,
      max: 20,
      ui: {
        label: "cam distance",
        control: "slider"
      }
    },
    backgroundColor: {
      type: "vec3",
      default: [1.0, 1.0, 1.0],
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
    colorMode: {
      type: "int",
      default: 10,
      uniform: "colorMode",
      choices: {
        Depth: 0,
        Diffuse: 1,
        Palette: 10
      },
      ui: {
        label: "color mode",
        control: "dropdown"
      }
    },
    source: {
      type: "int",
      default: 0,
      uniform: "source",
      choices: {
        None: 0,
        Input: 3
      },
      ui: {
        label: "tex source",
        control: "dropdown"
      }
    },
    palette: {
      type: "palette",
      default: 40,
      uniform: "palette",
      choices: paletteChoices,
      ui: {
        label: "palette",
        control: "dropdown"
      }
    },
    cyclePalette: {
      type: "int",
      default: 1,
      uniform: "cyclePalette",
      choices: {
        Off: 0,
        Forward: 1,
        Backward: -1
      },
      ui: {
        label: "cycle palette",
        control: "dropdown"
      }
    },
    rotatePalette: {
      type: "float",
      default: 0,
      uniform: "rotatePalette",
      min: 0,
      max: 100,
      ui: {
        label: "rotate palette",
        control: "slider"
      }
    },
    repeatPalette: {
      type: "int",
      default: 1,
      uniform: "repeatPalette",
      min: 1,
      max: 5,
      ui: {
        label: "repeat palette",
        control: "slider"
      }
    },
    wrap: {
      type: "int",
      default: 1,
      uniform: "wrap",
      choices: {
        Clamp: 2,
        Mirror: 0,
        Repeat: 1
      },
      ui: {
        label: "wrap",
        control: "dropdown"
      }
    },
    paletteMode: {
      type: "int",
      default: 0,
      uniform: "paletteMode",
      ui: {
        control: false
      }
    },
    paletteOffset: {
      type: "vec3",
      default: [0.83, 0.6, 0.63],
      uniform: "paletteOffset",
      ui: {
        label: "palette offset",
        control: "slider"
      }
    },
    paletteAmp: {
      type: "vec3",
      default: [0.5, 0.5, 0.5],
      uniform: "paletteAmp",
      ui: {
        label: "palette amplitude",
        control: "slider"
      }
    },
    paletteFreq: {
      type: "vec3",
      default: [1, 1, 1],
      uniform: "paletteFreq",
      ui: {
        label: "palette frequency",
        control: "slider"
      }
    },
    palettePhase: {
      type: "vec3",
      default: [0.3, 0.1, 0],
      uniform: "palettePhase",
      ui: {
        label: "palette phase",
        control: "slider"
      }
    },
    repetition: {
      type: "boolean",
      default: false,
      uniform: "repetition",
      ui: {
        label: "repeat",
        control: "checkbox"
      }
    },
    animation: {
      type: "int",
      default: 1,
      uniform: "animation",
      choices: {
        "Rotate Scene": 0,
        "Rotate Shape": 1
      },
      ui: {
        label: "rotation",
        control: "dropdown"
      }
    },
    flythroughSpeed: {
      type: "float",
      default: 0,
      uniform: "flythroughSpeed",
      min: -10,
      max: 10,
      ui: {
        label: "flythrough",
        control: "slider"
      }
    },
    spacing: {
      type: "int",
      default: 10,
      uniform: "spacing",
      min: 5,
      max: 20,
      ui: {
        label: "spacing",
        control: "slider"
      }
    }
  };

  passes = [
    {
      name: "render",
      type: "render",
      program: "shapes-3d",
      inputs: {
              inputTex: "inputTex"
            }
,
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
