import { Effect } from '../../../src/runtime/effect.js';

export default class Bright extends Effect {
  name = "Bright";
  namespace = "basics";
  func = "brightness";

  globals = {
    "a": {
        "type": "float",
        "default": 0,
        "min": -1,
        "max": 1,
        "uniform": "a"
    }
};

  passes = [
    {
      name: "main",
      type: "render",
      program: "bright",
      inputs: {
      "tex0": "inputTex"
},
      outputs: {
        color: "outputColor"
      }
    }
  ];
}
