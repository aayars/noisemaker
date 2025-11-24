import { Effect } from '../../../src/runtime/effect.js';

export default class DepthOfField extends Effect {
  name = "DepthOfField";
  namespace = "nd";
  func = "depth_of_field";

  globals = {
    seed: {
      type: "int",
      default: 1,
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
      type: "render",
      program: "depth-of-field",
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
