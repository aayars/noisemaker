import { Effect } from '../../../src/runtime/effect.js';

/**
 * Stray Hair
 * /shaders/effects/stray_hair/stray_hair.wgsl
 */
export default class StrayHair extends Effect {
  name = "StrayHair";
  namespace = "nm";
  func = "strayhair";

  globals = {
    seed: {
        type: "number",
        default: 0,
        min: 0,
        max: 1000,
        step: 1,
        ui: {
            label: "Seed",
            control: "slider"
        }
    }
};

  passes = [
    {
      name: "main",
      type: "render",
      program: "stray_hair",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
