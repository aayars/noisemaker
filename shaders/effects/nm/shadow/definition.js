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
        uniform: "alpha",
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
      type: "compute",  // GPGPU: compute value map
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
      type: "compute",  // GPGPU: edge detection
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
      type: "compute",  // GPGPU: sharpen
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
