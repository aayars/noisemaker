import { Effect } from '../../../src/runtime/effect.js';

export default class Lum extends Effect {
  name = "Lum";
  namespace = "basics";
  func = "luma";

  globals = {
    "threshold": {
        "type": "float",
        "default": 0.5,
        "min": 0,
        "max": 1,
        "uniform": "threshold"
    },
    "tolerance": {
        "type": "float",
        "default": 0.1,
        "min": 0,
        "max": 1,
        "uniform": "tolerance"
    }
};

  passes = [
    {
      name: "main",
      type: "render",
      program: "lum",
      inputs: {
      "tex0": "inputTex"
},
      outputs: {
        color: "outputColor"
      }
    }
  ];
}
