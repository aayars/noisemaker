import { Effect } from '../../../src/runtime/effect.js';

export default class ModHue extends Effect {
  name = "ModHue";
  namespace = "basics";
  func = "modulateHue";

  globals = {
    "tex": {
        "type": "surface",
        "default": "inputTex",
        "ui": {
            "label": "source surface"
        }
    },
    "amount": {
        "type": "float",
        "default": 0.1,
        "min": -1,
        "max": 1,
        "uniform": "amount"
    }
};

  passes = [
    {
      name: "main",
      program: "modHue",
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
