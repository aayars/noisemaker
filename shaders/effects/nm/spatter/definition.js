import { Effect } from '../../../src/runtime/effect.js';

/**
 * Spatter
 * /shaders/effects/spatter/spatter.wgsl
 */
export default class Spatter extends Effect {
  name = "Spatter";
  namespace = "nm";
  func = "spatter";

  globals = {
    color: {
        type: "boolean",
        default: true,
        uniform: "color",
        ui: {
            label: "Color",
            control: "checkbox"
        }
    }
};

  passes = [
    {
      name: "main",
      type: "render",
      program: "spatter",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
