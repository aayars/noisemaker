import { Effect } from '../../../src/runtime/effect.js';

export default class Poster extends Effect {
  name = "Poster";
  namespace = "basics";
  func = "poster";

  globals = {
    "levels": {
        "type": "float",
        "default": 3,
        "min": 1,
        "max": 256,
        "uniform": "levels"
    },
    "gamma": {
        "type": "float",
        "default": 0.6,
        "min": 0.01,
        "max": 10,
        "uniform": "gamma"
    }
};

  passes = [
    {
      name: "main",
      program: "poster",
      inputs: {
      "tex0": "inputTex"
},
      outputs: {
        color: "outputColor"
      }
    }
  ];
}
