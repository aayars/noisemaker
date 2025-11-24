import { Effect } from '../../../src/runtime/effect.js';

export default class Mod extends Effect {
  name = "Mod";
  namespace = "basics";
  func = "modulate";

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
        "default": 0.1,
        "min": 0,
        "max": 1,
        "uniform": "amount"
    }
};

  passes = [
    {
      name: "main",
      type: "render",
      program: "mod",
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
