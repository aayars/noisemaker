import { Effect } from '../../../src/runtime/effect.js';

export default class Text extends Effect {
  name = "Text";
  namespace = "nd";
  func = "text_nd";

  globals = {
    seed: {
      type: "int",
      default: 1,
      min: 1,
      max: 100,
      ui: {
        label: "seed",
        control: "slider"
      }
    },
    glyphUV1: {
      type: "vec2",
      default: [0, 0],
      ui: {
        label: "glyph uv1",
        control: "slider"
      }
    },
    glyphUV2: {
      type: "vec2",
      default: [1, 1],
      ui: {
        label: "glyph uv2",
        control: "slider"
      }
    },
    font: {
      type: "string",
      default: "sans-serif",
      choices: {
        Cursive: "cursive",
        Fantasy: "fantasy",
        Monospace: "monospace",
        Nunito: "Nunito",
        "Sans Serif": "sans-serif",
        Serif: "serif",
        Vcr: "vcr"
      },
      ui: {
        label: "font",
        control: "dropdown"
      }
    },
    text: {
      type: "text",
      default: "hello world",
      ui: {
        label: "text",
        control: "slider"
      }
    },
    position: {
      type: "int",
      default: 4,
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
    color: {
      type: "vec4",
      default: [1.0, 1.0, 1.0, 1.0],
      ui: {
        label: "text color",
        control: "color"
      }
    },
    size: {
      type: "float",
      default: 200,
      min: 10,
      max: 1500,
      ui: {
        label: "scale",
        control: "slider"
      }
    },
    rotation: {
      type: "int",
      default: 0,
      min: -180,
      max: 180,
      ui: {
        label: "rotate",
        control: "slider"
      }
    },
    offsetX: {
      type: "int",
      default: 0,
      min: -100,
      max: 100,
      ui: {
        label: "offset x",
        control: "slider"
      }
    },
    offsetY: {
      type: "int",
      default: 0,
      min: -100,
      max: 100,
      ui: {
        label: "offset y",
        control: "slider"
      }
    },
    backgroundColor: {
      type: "vec4",
      default: [0.0, 0.0, 0.0, 1.0],
      ui: {
        label: "bkg color",
        control: "color"
      }
    },
    backgroundOpacity: {
      type: "float",
      default: 100,
      min: 0,
      max: 100,
      ui: {
        label: "bkg opacity",
        control: "slider"
      }
    }
  };

  passes = [
    {
      name: "render",
      type: "render",
      program: "text",
      inputs: {
        textTex: "inputTex"
      },

      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
