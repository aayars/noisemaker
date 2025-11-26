import { Effect } from '../../../src/runtime/effect.js';

export default class ModScale extends Effect {
  name = "ModScale";
  namespace = "basics";
  func = "modulateScale";

  globals = {
    "multiple": {
        "type": "float",
        "default": 1,
        "min": 0.1,
        "max": 20,
        "uniform": "multiple"
    },
    "offset": {
        "type": "float",
        "default": 0,
        "min": -1,
        "max": 1,
        "uniform": "offset"
    },
    "amount": {
        "type": "float",
        "default": 0.1,
        "min": 0,
        "max": 1,
        "uniform": "amount"
    },
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
      program: "modScale",
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
