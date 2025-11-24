import { Effect } from '../../../src/runtime/effect.js';

export default class ModRotate extends Effect {
  name = "ModRotate";
  namespace = "basics";
  func = "modulateRotate";

  globals = {
    "multiple": {
        "type": "float",
        "default": 1,
        "min": -10,
        "max": 10,
        "uniform": "multiple"
    },
    "offset": {
        "type": "float",
        "default": 0,
        "min": -3.14159,
        "max": 3.14159,
        "uniform": "offset"
    },
    "tex": {
        "type": "surface",
        "default": "inputTex",
        "ui": {
            "label": "source surface"
        }
    }
};

  passes = [
    {
      name: "main",
      type: "render",
      program: "modRotate",
      inputs: {
      "tex0": "inputTex",
      "tex1": "tex"
},
      outputs: {
        color: "outputColor"
      }
    }
  ];
}
