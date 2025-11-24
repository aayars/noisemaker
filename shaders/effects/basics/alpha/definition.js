import { Effect } from '../../../src/runtime/effect.js';

export default class A extends Effect {
  name = "A";
  namespace = "basics";
  func = "alpha";

  globals = {
    "scale": {
        "type": "float",
        "default": 1,
        "min": -10,
        "max": 10,
        "uniform": "scale"
    },
    "offset": {
        "type": "float",
        "default": 0,
        "min": -10,
        "max": 10,
        "uniform": "offset"
    }
};

  passes = [
    {
      name: "main",
      type: "render",
      program: "a",
      inputs: {
      "tex0": "inputTex"
},
      outputs: {
        color: "outputColor"
      }
    }
  ];
}
