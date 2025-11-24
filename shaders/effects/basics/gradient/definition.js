import { Effect } from '../../../src/runtime/effect.js';

export default class Gradient extends Effect {
  name = "Gradient";
  namespace = "basics";
  func = "gradient";

  globals = {
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
      program: "gradient",
      inputs: {},
      outputs: {
        color: "outputColor"
      }
    }
  ];
}
