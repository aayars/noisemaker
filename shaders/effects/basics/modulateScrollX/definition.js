import { Effect } from '../../../src/runtime/effect.js';

export default class ModScrollX extends Effect {
  name = "ModScrollX";
  namespace = "basics";
  func = "modulateScrollX";

  globals = {
    "scrollX": {
        "type": "float",
        "default": 0.5,
        "min": -10,
        "max": 10,
        "uniform": "scrollX"
    },
    "speed": {
        "type": "float",
        "default": 0,
        "min": -10,
        "max": 10,
        "uniform": "speed"
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
      program: "modScrollX",
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
