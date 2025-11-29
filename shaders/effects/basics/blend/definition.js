import { Effect } from '../../../src/runtime/effect.js';

export default class Blend extends Effect {
  name = "Blend";
  namespace = "basics";
  func = "blend";

  globals = {
    "tex": {
        "type": "surface",
        "default": "inputTex",
        "ui": {
            "label": "source surface"
        }
    },
    "amount": {
        "type": "float",
        "default": 0.5,
        "min": 0,
        "max": 1,
        "uniform": "amount"
    }
};

  passes = [
    {
      name: "main",
      program: "blend",
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
