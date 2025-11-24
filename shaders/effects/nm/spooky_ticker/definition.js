import { Effect } from '../../../src/runtime/effect.js';

/**
 * Spooky Ticker
 * /shaders/effects/spooky_ticker/spooky_ticker.wgsl
 */
export default class SpookyTicker extends Effect {
  name = "SpookyTicker";
  namespace = "nm";
  func = "spookyticker";

  globals = {};

  passes = [
    {
      name: "main",
      type: "render",
      program: "spooky_ticker",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
