import { Effect } from '../../../src/runtime/effect.js';

export default class Layer extends Effect {
  name = "Layer";
  namespace = "basics";
  func = "layer";

  globals = {
    "tex": {
        "type": "surface",
        "default": "inputTex",
        uniform: "tex",
        "ui": {
            "label": "layer source"
        }
    }
};

  passes = [
    {
      name: "main",
      program: "layer",
      inputs: {
      "tex0": "inputTex",
      "tex1": "tex"
},
      outputs: {
        color: "outputTex"
      }
    }
  ];
}
