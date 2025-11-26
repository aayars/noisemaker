import { Effect } from '../../../src/runtime/effect.js';

export default class DepthOfField extends Effect {
  name = "DepthOfField";
  namespace = "nd";
  func = "depthOfField";

  globals = {
    tex: {
      type: "surface",
      default: "inputTex",
      ui: {
        label: "depth map"
      }
    },
    seed: {
      type: "int",
      default: 1,
      uniform: "seed",
      min: 1,
      max: 100,
      ui: {
        label: "seed",
        control: "slider"
      }
    },
    focalDistance: {
      type: "float",
      default: 50,
      uniform: "focalDistance",
      min: 1,
      max: 100,
      ui: {
        label: "focal dist",
        control: "slider"
      }
    },
    aperture: {
      type: "float",
      default: 4,
      uniform: "aperture",
      min: 1,
      max: 10,
      ui: {
        label: "aperture",
        control: "slider"
      }
    },
    sampleBias: {
      type: "float",
      default: 10,
      uniform: "sampleBias",
      min: 2,
      max: 20,
      ui: {
        label: "sample bias",
        control: "slider"
      }
    },
    depthSource: {
      type: "int",
      default: 1,
      uniform: "depthSource",
      choices: {
        "inputTex": 0,
        "tex": 1
      },
      ui: {
        label: "depth source",
        control: "dropdown"
      }
    }
  };

  passes = [
    {
      name: "render",
      program: "depthOfField",
      inputs: {
              tex0: "inputTex",
              tex1: "tex"
            }
,
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
