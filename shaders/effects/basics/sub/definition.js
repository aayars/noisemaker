import { Effect } from '../../../src/runtime/effect.js';

export default class Sub extends Effect {
  name = "Sub";
  namespace = "basics";
  func = "sub";

  globals = {
    "amount": {
        "type": "float",
        "default": 1,
        "min": 0,
        "max": 1,
        "uniform": "amount"
    },
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
      program: "sub",
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
