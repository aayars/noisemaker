import { Effect } from '../../../src/runtime/effect.js';

export default class Text extends Effect {
  name = "Text";
  namespace = "nd";
  func = "text";


  // WGSL uniform packing layout - maps uniform names to vec4 slots/components
  uniformLayout = {
        resolution: { slot: 0, components: 'xy' },
    glyphUV1: { slot: 1, components: 'xy' },
    glyphUV2: { slot: 1, components: 'zw' },
    scale: { slot: 2, components: 'x' },
    offset: { slot: 2, components: 'yz' },
    color: { slot: 3, components: 'xyz' }
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
    glyphUV1: {
      type: "vec2",
      default: [0, 0],
      uniform: "glyphUV1",
      ui: {
        label: "glyph uv1",
        control: "slider"
      }
    },
    glyphUV2: {
      type: "vec2",
      default: [1, 1],
      uniform: "glyphUV2",
      ui: {
        label: "glyph uv2",
        control: "slider"
      }
    },
    font: {
      type: "string",
      default: "sansSerif",
      uniform: "font",
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
      uniform: "text",
      ui: {
        label: "text",
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
    color: {
      type: "vec3",
      default: [1.0, 1.0, 1.0],
      uniform: "color",
      ui: {
        label: "text color",
        control: "color"
      }
    },
    size: {
      type: "float",
      default: 200,
      uniform: "size",
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
      uniform: "rotation",
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
      uniform: "offsetX",
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
      uniform: "offsetY",
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
      uniform: "backgroundColor",
      ui: {
        label: "bkg color",
        control: "color"
      }
    },
    backgroundOpacity: {
      type: "float",
      default: 100,
      uniform: "backgroundOpacity",
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
      program: "text",
      inputs: {
        textTex: "inputTex"
      },

      outputs: {
        fragColor: "outputTex"
      }
    }
  ];
}
