import { Effect } from '../../../src/runtime/effect.js';

/**
 * ValueRefract - noise-driven refraction distortion
 */
export default class ValueRefract extends Effect {
  name = "ValueRefract";
  namespace = "nm";
  func = "valuerefract";

  globals = {
    displacement: {
      type: "float",
      default: 0.5,
      min: 0,
      max: 2,
      step: 0.01,
      ui: {
        label: "Displacement",
        control: "slider"
      }
    },
    frequency: {
      type: "float",
      default: 4.0,
      min: 0.1,
      max: 20,
      step: 0.1,
      ui: {
        label: "Frequency",
        control: "slider"
      }
    }
  };

  passes = [
    {
      name: "main",
      type: "render",
      program: "value_refract",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
