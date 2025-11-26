import { Effect } from '../../../src/runtime/effect.js';

export default class Diff extends Effect {
  name = "Diff";
  namespace = "basics";
  func = "diff";

  globals = {
    "tex": {
        "type": "surface",
        "default": "inputTex",
        uniform: "tex",
        "ui": {
            "label": "source surface"
        }
    }
};

  passes = [
    {
      name: "main",
      type: "render",
      program: "diff",
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
