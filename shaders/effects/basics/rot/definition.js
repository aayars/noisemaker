import { Effect } from '../../../src/runtime/effect.js';

export default class Rot extends Effect {
  name = "Rot";
  namespace = "basics";
  func = "rot";

  globals = {
    "angle": {
        "type": "float",
        "default": 0,
        "min": -360,
        "max": 360,
        "uniform": "angle"
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
      program: "rot",
      inputs: {
      "tex0": "inputTex"
},
      outputs: {
        color: "outputTex"
      }
    }
  ];
}
