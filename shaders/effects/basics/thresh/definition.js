import { Effect } from '../../../src/runtime/effect.js';

export default class Thresh extends Effect {
  name = "Thresh";
  namespace = "nd";
  func = "thresh";

  globals = {
    "level": {
        "type": "float",
        "default": 0.5,
        "min": 0,
        "max": 1,
        "uniform": "level"
    },
    "sharpness": {
        "type": "float",
        "default": 0.5,
        "min": 0,
        "max": 1,
        "uniform": "sharpness"
    }
};

  passes = [
    {
      name: "main",
      type: "render",
      program: "thresh",
      inputs: {
      "tex0": "inputTex"
},
      outputs: {
        color: "outputColor"
      }
    }
  ];
}
