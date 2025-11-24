import { Effect } from '../../../src/runtime/effect.js';

export default class Inv extends Effect {
  name = "Inv";
  namespace = "basics";
  func = "invert";

  globals = {
    "a": {
        "type": "float",
        "default": 1,
        "min": 0,
        "max": 1,
        "uniform": "a"
    }
};

  passes = [
    {
      name: "main",
      type: "render",
      program: "inv",
      inputs: {
      "tex0": "inputTex"
},
      outputs: {
        color: "outputColor"
      }
    }
  ];
}
