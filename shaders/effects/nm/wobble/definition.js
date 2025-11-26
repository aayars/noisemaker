import { Effect } from '../../../src/runtime/effect.js';

/**
 * Wobble - offsets the entire frame using noise-driven jitter
 */
export default class Wobble extends Effect {
  name = "Wobble";
  namespace = "nm";
  func = "wobble";

  globals = {
    speed: {
      type: "float",
      default: 1.0,
      uniform: "speed",
      min: 0,
      max: 5,
      step: 0.1,
      ui: {
        label: "Speed",
        control: "slider"
      }
    }
  };

  passes = [
    {
      name: "main",
      type: "render",
      program: "wobble",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
