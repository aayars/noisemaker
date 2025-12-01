import { Effect } from '../../../src/runtime/effect.js';

export default class HardLight extends Effect {
  name = "Hard Light";
  namespace = "nu";
  func = "hardLight";

  globals = {
    tex: {
      type: "surface",
      default: "inputTex",
      ui: { label: "source B" }
    },
    mixAmt: {
      type: "float",
      default: 0,
      uniform: "mixAmt",
      min: -100,
      max: 100,
      ui: { label: "mix", control: "slider" }
    }
  };

  passes = [
    {
      name: "render",
      program: "hardLight",
      inputs: { tex0: "inputTex", tex1: "tex" },
      outputs: { fragColor: "outputTex" }
    }
  ];
}
