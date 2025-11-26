import { Effect } from '../../../src/runtime/effect.js';

/**
 * Spooky Ticker
 * /shaders/effects/spooky_ticker/spooky_ticker.wgsl
 */
export default class SpookyTicker extends Effect {
  name = "SpookyTicker";
  namespace = "nm";
  func = "spookyTicker";

  globals = {};

  passes = [
    {
      name: "main",
      program: "spookyTicker",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        color: "outputColor"
      }
    }
  ];
}
