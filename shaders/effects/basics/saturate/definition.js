import { Effect } from '../../../src/runtime/effect.js';

export default class Sat extends Effect {
  name = "Sat";
  namespace = "basics";
  func = "saturation";

  globals = {
    "a": {
        "type": "float",
        "default": 1,
        "min": 0,
        "max": 10,
        "uniform": "a"
    }
};

  passes = [
    {
      name: "main",
      type: "render",
      program: "sat",
      inputs: {
      "tex0": "inputTex"
},
      outputs: {
        color: "outputColor"
      }
    }
  ];
}
