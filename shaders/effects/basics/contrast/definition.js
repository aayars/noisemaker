import { Effect } from '../../../src/runtime/effect.js';

export default class Cont extends Effect {
  name = "Cont";
  namespace = "basics";
  func = "contrast";

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
      program: "cont",
      inputs: {
      "tex0": "inputTex"
},
      outputs: {
        color: "outputColor"
      }
    }
  ];
}
