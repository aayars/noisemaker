import { Effect } from '../../../src/runtime/effect.js';

/**
 * Scanline Error
 * /shaders/effects/scanline_error/scanline_error.wgsl
 */
export default class ScanlineError extends Effect {
  name = "ScanlineError";
  namespace = "nm";
  func = "scanlineError";

    globals = {
    speed: {
      type: "float",
      default: 1,
      uniform: "speed",
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
      uniform: "timeOffset",
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
      uniform: "enabled",
      ui: {
        label: "Enabled",
        control: "checkbox"
      }
    }
    };

  passes = [
    {
      name: "main",
      program: "scanlineError",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        color: "outputColor"
      }
    }
  ];
}
