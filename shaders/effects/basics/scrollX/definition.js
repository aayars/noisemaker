import { Effect } from '../../../src/runtime/effect.js';

export default class ScrollX extends Effect {
  name = "ScrollX";
  namespace = "basics";
  func = "scrollX";

  globals = {
    "x": {
        "type": "float",
        "default": 0,
        "min": -10,
        "max": 10,
        "uniform": "x"
    },
    "speed": {
        "type": "float",
        "default": 0,
        "min": -10,
        "max": 10,
        "uniform": "speed"
    }
};

  passes = [
    {
      name: "main",
      type: "render",
      program: "scrollX",
      inputs: {
      "tex0": "inputTex"
},
      outputs: {
        color: "outputColor"
      }
    }
  ];
}
