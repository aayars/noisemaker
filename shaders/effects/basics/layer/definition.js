import { Effect } from '../../../src/runtime/effect.js';

export default class Layer extends Effect {
  name = "Layer";
  namespace = "basics";
  func = "layer";

  globals = {
    "tex": {
        "type": "surface",
        "default": "inputTex",
        "ui": {
            "label": "layer source"
        }
    }
};

  passes = [
    {
      name: "main",
      type: "render",
      program: "layer",
      inputs: {
      "tex0": "inputTex",
      "tex1": "tex"
},
      outputs: {
        color: "outputColor"
      }
    }
  ];
}
