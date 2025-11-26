import { Effect } from '../../../src/runtime/effect.js';

export default class FeedbackMixer extends Effect {
  name = "FeedbackMixer";
  namespace = "nd";
  func = "feedback_mixer";

  globals = {
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
    feedback: {
      type: "float",
      default: 50,
      uniform: "feedback",
      min: 0,
      max: 100,
      ui: {
        label: "feedback",
        control: "slider"
      }
    },
    mixAmt: {
      type: "float",
      default: 0,
      uniform: "mixAmt",
      min: -100,
      max: 100,
      ui: {
        label: "mix",
        control: "slider"
      }
    },
    scaleAmt: {
      type: "float",
      default: 100,
      uniform: "scaleAmt",
      min: 75,
      max: 200,
      ui: {
        label: "scale %",
        control: "slider"
      }
    },
    rotation: {
      type: "int",
      default: 0,
      uniform: "rotation",
      min: -180,
      max: 180,
      ui: {
        label: "rotate",
        control: "slider"
      }
    }
  };

  passes = [
    {
      name: "render",
      type: "render",
      program: "feedback-mixer",
      inputs: {
              tex0: "inputTex",
              tex1: "tex",
              selfTex: "selfTex"
            }
,
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
