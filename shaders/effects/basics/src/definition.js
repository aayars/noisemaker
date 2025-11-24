import { Effect } from '../../../src/runtime/effect.js';

export default class Src extends Effect {
  name = "Src";
  namespace = "basics";
  func = "src";

  globals = {
    "tex": {
        "type": "surface",
        "default": "inputTex",
        "ui": {
            "label": "source surface"
        }
    }
};

  passes = [
    {
      name: "main",
      type: "render",
      program: "src",
      inputs: {
      "tex0": "tex"
},
      outputs: {
        color: "outputColor"
      }
    }
  ];
}
