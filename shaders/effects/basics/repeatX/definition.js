import { Effect } from '../../../src/runtime/effect.js';

export default class RepeatX extends Effect {
  name = "RepeatX";
  namespace = "basics";
  func = "repeatX";

  globals = {
    "x": {
        "type": "float",
        "default": 3,
        "min": 1,
        "max": 20,
        "uniform": "x"
    },
    "offset": {
        "type": "float",
        "default": 0,
        "min": -1,
        "max": 1,
        "uniform": "offset"
    }
};

  passes = [
    {
      name: "main",
      type: "render",
      program: "repeatX",
      inputs: {
      "tex0": "inputTex"
},
      outputs: {
        color: "outputColor"
      }
    }
  ];
}
