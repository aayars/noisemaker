import { Effect } from '../../../src/runtime/effect.js';

export default class Sum extends Effect {
  name = "Sum";
  namespace = "basics";
  func = "sum";

  globals = {
    "scale": {
        "type": "float",
        "default": 1,
        "min": -10,
        "max": 10,
        "uniform": "scale"
    }
};

  passes = [
    {
      name: "main",
      program: "sum",
      inputs: {
      "tex0": "inputTex"
},
      outputs: {
        color: "outputColor"
      }
    }
  ];
}
