import { Effect } from '../../../src/runtime/effect.js';

export default class G extends Effect {
  name = "G";
  namespace = "basics";
  func = "green";

  globals = {
    "scale": {
        "type": "float",
        "default": 1,
        "min": -10,
        "max": 10,
        "uniform": "scale"
    },
    "offset": {
        "type": "float",
        "default": 0,
        "min": -10,
        "max": 10,
        "uniform": "offset"
    }
};

  passes = [
    {
      name: "main",
      program: "g",
      inputs: {
      "tex0": "inputTex"
},
      outputs: {
        color: "outputTex"
      }
    }
  ];
}
