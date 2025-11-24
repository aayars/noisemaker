import { Effect } from '../../../src/runtime/effect.js';

export default class Solid extends Effect {
  name = "Solid";
  namespace = "basics";
  func = "solid";

  globals = {
    "r": {
        "type": "float",
        "default": 0,
        "min": 0,
        "max": 1,
        "uniform": "r"
    },
    "g": {
        "type": "float",
        "default": 0,
        "min": 0,
        "max": 1,
        "uniform": "g"
    },
    "b": {
        "type": "float",
        "default": 0,
        "min": 0,
        "max": 1,
        "uniform": "b"
    }
};

  passes = [
    {
      name: "main",
      type: "render",
      program: "solid",
      inputs: {},
      outputs: {
        color: "outputColor"
      }
    }
  ];
}
