import { Effect } from '../../../src/runtime/effect.js';

export default class ScrollY extends Effect {
  name = "ScrollY";
  namespace = "basics";
  func = "scrollY";

  globals = {
    "y": {
        "type": "float",
        "default": 0,
        "min": -10,
        "max": 10,
        "uniform": "y"
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
      program: "scrollY",
      inputs: {
      "tex0": "inputTex"
},
      outputs: {
        color: "outputColor"
      }
    }
  ];
}
