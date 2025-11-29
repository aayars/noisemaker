import { Effect } from '../../../src/runtime/effect.js';

export default class Src extends Effect {
  name = "Src";
  namespace = "basics";
  func = "src";

  globals = {
    "tex": {
        "type": "surface",
        "default": "inputTex",
        uniform: "tex",
        "ui": {
            "label": "source surface"
        }
    }
};

  passes = [
    {
      name: "main",
      program: "src",
      inputs: {
      "tex0": "tex"
},
      outputs: {
        color: "outputTex"
      }
    }
  ];
}
