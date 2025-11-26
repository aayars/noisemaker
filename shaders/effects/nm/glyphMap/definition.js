import { Effect } from '../../../src/runtime/effect.js';

/**
 * Glyph Map
 * /shaders/effects/glyph_map/glyph_map.wgsl
 */
export default class GlyphMap extends Effect {
  name = "GlyphMap";
  namespace = "nm";
  func = "glyphMap";

  globals = {
    colorize: {
        type: "boolean",
        default: true,
        uniform: "colorize",
        ui: {
            label: "Colorize",
            control: "checkbox"
        }
    },
    zoom: {
        type: "int",
        default: 1,
        uniform: "zoom",
        min: 1,
        max: 8,
        step: 1,
        ui: {
            label: "Zoom",
            control: "slider"
        }
    },
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

  // TODO: Define passes based on shader requirements
  // This effect was originally implemented as a WebGPU compute shader.
  // A render pass implementation needs to be created for GLSL/WebGL2 compatibility.
  passes = [
    {
      name: "main",
      program: "glyphMap",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputBuffer: "outputColor"
      }
    }
  ];
}
