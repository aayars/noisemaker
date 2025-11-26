import { Effect } from '../../../src/runtime/effect.js';

/**
 * Color Map
 * /shaders/effects/color_map/color_map.wgsl
 */
export default class ColorMap extends Effect {
  name = "ColorMap";
  namespace = "nm";
  func = "colormap";

  globals = {
    displacement: {
        type: "float",
        default: 0.5,
        uniform: "displacement",
        min: 0,
        max: 1,
        step: 0.01,
        ui: {
            label: "Displacement",
            control: "slider"
        }
    },
    horizontal: {
        type: "boolean",
        default: false,
        uniform: "horizontal",
        ui: {
            label: "Horizontal",
            control: "checkbox"
        }
    }
  };

  passes = [
    {
      name: "reduce_1",
      type: "render",
      program: "reduce_1",
      inputs: {
        input_texture: "inputTex"
      },
      outputs: {
        fragColor: "reduceTex1"
      }
    },
    {
      name: "reduce_2",
      type: "render",
      program: "reduce_2",
      inputs: {
        reduceTex1: "reduceTex1"
      },
      outputs: {
        fragColor: "statsTex"
      }
    },
    {
      name: "render",
      type: "render",
      program: "color_map_render",
      inputs: {
        input_texture: "inputTex",
        clut_texture: "tex",
        statsTex: "statsTex"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}