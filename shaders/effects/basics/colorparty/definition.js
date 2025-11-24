import { Effect } from '../../../src/runtime/effect.js';

export default class Colorparty extends Effect {
  name = "Colorparty";
  namespace = "basics";
  func = "colorparty";

  globals = {
    "amount": {
        "type": "float",
        "default": 0.005,
        "min": -10,
        "max": 10,
        "uniform": "amount"
    }
};

  passes = [
    {
      name: "main",
      type: "render",
      program: "colorparty",
      inputs: {
      "tex0": "inputTex"
},
      outputs: {
        color: "outputColor"
      }
    }
  ];
}
