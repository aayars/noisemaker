import { Effect } from '../../../src/runtime/effect.js';

export default class Osc extends Effect {
  name = "Osc";
  namespace = "basics";
  func = "osc";

  globals = {
    "freq": {
        "type": "float",
        "default": 10,
        "min": 0,
      "max": 1000,
      "step": 1,
        "uniform": "freq"
    },
    "sync": {
        "type": "float",
        "default": 0.1,
        "min": 0,
      "max": 10,
      "step": 0.25,
        "uniform": "sync"
    },
    "amp": {
        "type": "float",
        "default": 1,
        "min": 0,
      "max": 10,
      "step": 0.5,
        "uniform": "amp"
    }
};

  passes = [
    {
      name: "main",
      program: "osc",
      inputs: {},
      outputs: {
        color: "outputColor"
      }
    }
  ];
}
