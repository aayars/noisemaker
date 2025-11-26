import { Effect } from '../../../src/runtime/effect.js';

export default class Prev extends Effect {
  name = "Prev";
  namespace = "basics";
  func = "prev";

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
      program: "prev",
      inputs: {
      "tex0": "tex"
},
      outputs: {
        color: "outputColor"
      }
    }
  ];
}
