import { Effect } from '../../../src/runtime/effect.js';

export default class ModRepeatY extends Effect {
  name = "ModRepeatY";
  namespace = "basics";
  func = "modulateRepeatY";

  globals = {
    "repeatY": {
        "type": "float",
        "default": 3,
        "min": 1,
        "max": 20,
        "uniform": "repeatY"
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
      type: "render",
      program: "modRepeatY",
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
