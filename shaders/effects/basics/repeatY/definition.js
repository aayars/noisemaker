import { Effect } from '../../../src/runtime/effect.js';

export default class RepeatY extends Effect {
  name = "RepeatY";
  namespace = "basics";
  func = "repeatY";

  globals = {
    "y": {
        "type": "float",
        "default": 3,
        "min": 1,
        "max": 20,
        "uniform": "y"
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
      program: "repeatY",
      inputs: {
      "tex0": "inputTex"
},
      outputs: {
        color: "outputColor"
      }
    }
  ];
}
