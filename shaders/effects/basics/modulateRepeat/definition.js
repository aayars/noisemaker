import { Effect } from '../../../src/runtime/effect.js';

export default class ModRepeat extends Effect {
  name = "ModRepeat";
  namespace = "basics";
  func = "modulateRepeat";

  globals = {
    "repeatX": {
        "type": "float",
        "default": 3,
        "min": 1,
        "max": 20,
        "uniform": "repeatX"
    },
    "repeatY": {
        "type": "float",
        "default": 3,
        "min": 1,
        "max": 20,
        "uniform": "repeatY"
    },
    "offsetX": {
        "type": "float",
        "default": 0,
        "min": -1,
        "max": 1,
        "uniform": "offsetX"
    },
    "offsetY": {
        "type": "float",
        "default": 0,
        "min": -1,
        "max": 1,
        "uniform": "offsetY"
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
      program: "modRepeat",
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
