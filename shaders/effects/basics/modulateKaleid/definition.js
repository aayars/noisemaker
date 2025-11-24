import { Effect } from '../../../src/runtime/effect.js';

export default class ModKaleid extends Effect {
  name = "ModKaleid";
  namespace = "basics";
  func = "modulateKaleid";

  globals = {
    "tex": {
        "type": "surface",
        "default": "o1",
        "ui": {
            "label": "source surface"
        }
    },
    "n": {
        "type": "float",
        "default": 3,
        "min": 1,
        "max": 20,
        "uniform": "n"
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
      program: "modKaleid",
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
