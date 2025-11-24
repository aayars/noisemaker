import { Effect } from '../../../src/runtime/effect.js';

export default class WgslMixerDemo extends Effect {
  name = "WgslMixerDemo";
  namespace = "nd";
  func = "wgsl_mixer_demo";

  globals = {
    mixAmt: {
      type: "float",
      default: 0,
      min: 0,
      max: 100,
      ui: {
        label: "mix",
        control: "slider"
      }
    }
  };

  passes = [
    {
      name: "render",
      type: "render",
      program: "wgsl-mixer-demo",
      inputs: {
              tex0: "inputTex",
              tex1: "tex"
            }
,
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
