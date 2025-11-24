import { Effect } from '../../../src/runtime/effect.js';

export default class Repeat extends Effect {
  name = "Repeat";
  namespace = "basics";
  func = "repeat";

  globals = {
    "x": {
        "type": "float",
        "default": 3,
        "min": 1,
        "max": 20,
        "uniform": "x"
    },
    "y": {
        "type": "float",
        "default": 3,
        "min": 1,
        "max": 20,
        "uniform": "y"
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
    }
};

  passes = [
    {
      name: "main",
      type: "render",
      program: "repeat",
      inputs: {
      "tex0": "inputTex"
},
      outputs: {
        color: "outputColor"
      }
    }
  ];
}
