import { Effect } from '../../../src/runtime/effect.js';

export default class Shift extends Effect {
  name = "Shift";
  namespace = "basics";
  func = "shift";

  globals = {
    "r": {
        "type": "float",
        "default": 0.5,
        "min": -1,
      "max": 1,
        "uniform": "r"
    },
    "g": {
        "type": "float",
        "default": 0,
        "min": -1,
      "max": 1,
        "uniform": "g"
    },
    "b": {
        "type": "float",
        "default": 0,
        "min": -1,
      "max": 1,
        "uniform": "b"
    },
    "a": {
        "type": "float",
        "default": 0,
        "min": -1,
      "max": 1,
        "uniform": "a"
    }
};

  passes = [
    {
      name: "main",
      type: "render",
      program: "shift",
      inputs: {
      "tex0": "inputTex"
},
      outputs: {
        color: "outputColor"
      }
    }
  ];
}
