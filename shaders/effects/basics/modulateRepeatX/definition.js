import { Effect } from '../../../src/runtime/effect.js';

export default class ModRepeatX extends Effect {
  name = "ModRepeatX";
  namespace = "basics";
  func = "modulateRepeatX";

  globals = {
    "repeatX": {
        "type": "float",
        "default": 3,
        "min": 1,
        "max": 20,
        "uniform": "repeatX"
    },
    "offsetX": {
        "type": "float",
        "default": 0,
        "min": -1,
        "max": 1,
        "uniform": "offsetX"
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
      program: "modRepeatX",
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
