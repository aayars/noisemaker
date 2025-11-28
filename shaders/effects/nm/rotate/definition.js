import { Effect } from '../../../src/runtime/effect.js';

/**
 * Rotate
 * /shaders/effects/rotate/rotate.wgsl
 */
export default class Rotate extends Effect {
  name = "Rotate";
  namespace = "nm";
  func = "rotate";

  globals = {
    angle: {
        type: "float",
        default: 0,
        uniform: "angle",
        min: -180,
        max: 180,
        step: 1,
        ui: {
            label: "Angle",
            control: "slider"
        }
    }
};

  passes = [
    {
      name: "main",
      program: "rotate",
      inputs: {
        inputTex: "inputTex"
      },
      uniforms: {
        angle: "angle"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
