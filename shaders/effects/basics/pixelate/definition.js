import { Effect } from '../../../src/runtime/effect.js';

export default class Pixelate extends Effect {
  name = "Pixelate";
  namespace = "basics";
  func = "pixelate";

  globals = {
    "x": {
        "type": "float",
        "default": 20,
        "min": 1,
        "max": 1000,
        "uniform": "x"
    },
    "y": {
        "type": "float",
        "default": 20,
        "min": 1,
        "max": 1000,
        "uniform": "y"
    }
};

  passes = [
    {
      name: "main",
      program: "pixelate",
      inputs: {
      "tex0": "inputTex"
},
      outputs: {
        color: "outputColor"
      }
    }
  ];
}
