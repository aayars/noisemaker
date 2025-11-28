import { Effect } from '../../../src/runtime/effect.js';

/**
 * On-Screen Display
 * /shaders/effects/on_screen_display/on_screen_display.wgsl
 */
export default class OnScreenDisplay extends Effect {
  name = "OnScreenDisplay";
  namespace = "nm";
  func = "onScreenDisplay";

  globals = {};

  passes = [
    {
      name: "main",
      program: "onScreenDisplay",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
