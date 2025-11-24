import { Effect } from '../../../src/runtime/effect.js';

export default class Mask extends Effect {
  name = "Mask";
  namespace = "basics";
  func = "mask";

  globals = {
    "tex": {
        "type": "surface",
        "default": "o1",
        "ui": {
            "label": "source surface"
        }
    }
};

  passes = [
    {
      name: "main",
      type: "render",
      program: "mask",
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
