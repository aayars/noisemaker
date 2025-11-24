import { Effect } from '../../../src/runtime/effect.js';

/**
 * VHS - bad VHS tracking effect
 */
export default class Vhs extends Effect {
  name = "Vhs";
  namespace = "nm";
  func = "vhs";

  globals = {
    speed: {
      type: "float",
      default: 1.0,
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
      program: "vhs",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
