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

  // TODO: Define passes based on shader requirements
  // This effect was originally implemented as a WebGPU compute shader.
  // A render pass implementation needs to be created for GLSL/WebGL2 compatibility.
  passes = [
    {
      name: "main",
      type: "compute",
      program: "spooky_ticker",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputBuffer: "outputColor"
      }
    }
  ];
}
