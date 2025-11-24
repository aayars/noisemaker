import { Effect } from '../../../src/runtime/effect.js';

export default class Add extends Effect {
  name = "Add";
  namespace = "basics";
  func = "add";

  globals = {
    "tex": {
        "type": "surface",
        "default": "o1",
        "ui": {
            "label": "source surface"
        }
    },
    "amount": {
        "type": "float",
        "default": 1,
        "min": 0,
        "max": 1,
        "uniform": "amount"
    }
};

  passes = [
    {
      name: "main",
      type: "render",
      program: "add",
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
