import { Effect } from '../../../src/runtime/effect.js';

export default class ModPixelate extends Effect {
  name = "ModPixelate";
  namespace = "basics";
  func = "modulatePixelate";

  globals = {
    "pixelX": {
        "type": "float",
        "default": 20,
        "min": 1,
        "max": 1000,
        "uniform": "pixelX"
    },
    "pixelY": {
        "type": "float",
        "default": 20,
        "min": 1,
        "max": 1000,
        "uniform": "pixelY"
    },
    "amount": {
        "type": "float",
        "default": 0.1,
        "min": 0,
        "max": 1,
        "uniform": "amount"
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
      program: "modPixelate",
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
