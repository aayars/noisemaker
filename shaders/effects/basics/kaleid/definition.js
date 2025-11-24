import { Effect } from '../../../src/runtime/effect.js';

export default class Kaleid extends Effect {
  name = "Kaleid";
  namespace = "basics";
  func = "kaleid";

  globals = {
    "n": {
        "type": "float",
        "default": 3,
        "min": 1,
        "max": 20,
        "uniform": "n"
    }
};

  passes = [
    {
      name: "main",
      type: "render",
      program: "kaleid",
      inputs: {
      "tex0": "inputTex"
},
      outputs: {
        color: "outputColor"
      }
    }
  ];
}
