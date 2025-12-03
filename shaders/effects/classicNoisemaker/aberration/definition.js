import { Effect } from '../../../src/runtime/effect.js';

/**
 * Aberration
 * /shaders/effects/aberration/aberration.wgsl
 */
export default class Aberration extends Effect {
  name = "Aberration";
  namespace = "classicNoisemaker";
  func = "aberration";

  globals = {
    displacement: {
        type: "float",
        default: 0.02,
        uniform: "displacement",
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
        uniform: "speed",
        min: 0,
        max: 2.0,
        step: 0.01,
        ui: {
            label: "Speed",
            control: "slider"
        }
    }
};

  passes = [
    {
      name: "main",
      program: "aberration",
      inputs: {
        inputTex: "inputTex"
      },
      uniforms: {
        displacement: "displacement",
        speed: "speed"
      },
      outputs: {
        fragColor: "outputTex"
      }
    }
  ];
}
