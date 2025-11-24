import { Effect } from '../../../src/runtime/effect.js';

/**
 * Scanline Error
 * /shaders/effects/scanline_error/scanline_error.wgsl
 */
export default class ScanlineError extends Effect {
  name = "ScanlineError";
  namespace = "nm";
  func = "scanlineerror";

    globals = {
    speed: {
      type: "float",
      default: 1,
      min: 0,
      max: 5,
      step: 0.1,
      ui: {
        label: "Speed",
        control: "slider"
      }
    },
    timeOffset: {
      type: "float",
      default: 0,
      min: -10,
      max: 10,
      step: 0.01,
      ui: {
        label: "Time Offset",
        control: "slider"
      }
    },
    enabled: {
      type: "boolean",
      default: true,
      ui: {
        label: "Enabled",
        control: "checkbox"
      }
    }
    };

  // TODO: Define passes based on shader requirements
  // This effect was originally implemented as a WebGPU compute shader.
  // A render pass implementation needs to be created for GLSL/WebGL2 compatibility.
  passes = [
    {
      name: "main",
      type: "render",
      program: "scanline_error",
      inputs: {
        input_texture: "inputTex"
      },
      outputs: {
        color: "outputColor"
      }
    }
  ];
}
