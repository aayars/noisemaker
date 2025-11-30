import { Effect } from '../../../src/runtime/effect.js';

/**
 * nu/aberration - Chromatic aberration effect
 */
export default class Aberration extends Effect {
  name = "Aberration";
  namespace = "nu";
  func = "aberration";

  globals = {
    displacement: {
      type: "float",
      default: 0.02,
      uniform: "aberrationDisplacement",
      min: 0,
      max: 0.1,
      step: 0.001,
      ui: {
        label: "Displacement",
        control: "slider"
      }
    },
    speed: {
      type: "float",
      default: 0.2,
      uniform: "aberrationSpeed",
      min: 0,
      max: 2,
      step: 0.01,
      ui: {
        label: "Speed",
        control: "slider"
      }
    }
  };

  passes = [
    {
      name: "render",
      program: "aberration",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        fragColor: "outputTex"
      }
    }
  ];
}
