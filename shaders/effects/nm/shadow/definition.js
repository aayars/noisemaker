import { Effect } from '../../../src/runtime/effect.js';

/**
 * Shadow
 * /shaders/effects/shadow/shadow.wgsl
 */
export default class Shadow extends Effect {
  name = "Shadow";
  namespace = "nm";
  func = "shadow";

  globals = {
    alpha: {
        type: "float",
        default: 1,
        min: 0,
        max: 1,
        step: 0.01,
        ui: {
            label: "Alpha",
            control: "slider"
        }
    }
};

  textures = {
    shadowValueMap: { width: "100%", height: "100%", format: "rgba16f" },
    shadowSobel: { width: "100%", height: "100%", format: "rgba16f" },
    shadowSharpen: { width: "100%", height: "100%", format: "rgba16f" }
  };

  passes = [
    {
      name: "value-map",
      type: "render",
      program: "shadow_value_map",
      inputs: {
        input_texture: "inputTex"
      },
      outputs: {
        color: "shadowValueMap"
      }
    },
    {
      name: "sobel",
      type: "render",
      program: "shadow_sobel",
      inputs: {
        value_texture: "shadowValueMap"
      },
      outputs: {
        color: "shadowSobel"
      }
    },
    {
      name: "sharpen",
      type: "render",
      program: "shadow_sharpen",
      inputs: {
        gradient_texture: "shadowSobel"
      },
      outputs: {
        color: "shadowSharpen"
      }
    },
    {
      name: "blend",
      type: "render",
      program: "shadow_blend",
      inputs: {
        input_texture: "inputTex",
        sobel_texture: "shadowSobel",
        sharpen_texture: "shadowSharpen"
      },
      outputs: {
        color: "outputColor"
      }
    }
  ];
}
