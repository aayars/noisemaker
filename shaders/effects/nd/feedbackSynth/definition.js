import { Effect } from '../../../src/runtime/effect.js';

export default class FeedbackSynth extends Effect {
  name = "FeedbackSynth";
  namespace = "nd";
  func = "feedbackSynth";

  // No internal textures needed - use inputTex/outputTex for feedback
  textures = {};

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
    },
    translateX: {
      type: "float",
      default: 0,
      uniform: "translateX",
      min: -100,
      max: 100,
      ui: {
        label: "translate x",
        control: "slider"
      }
    },
    translateY: {
      type: "float",
      default: 0,
      uniform: "translateY",
      min: -100,
      max: 100,
      ui: {
        label: "translate y",
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
    hueRotation: {
      type: "float",
      default: 0,
      uniform: "hueRotation",
      min: -180,
      max: 180,
      ui: {
        label: "hue rotate",
        control: "slider"
      }
    },
    intensity: {
      type: "float",
      default: 0,
      uniform: "intensity",
      min: -100,
      max: 100,
      ui: {
        label: "intensity",
        control: "slider"
      }
    },
    distortion: {
      type: "float",
      default: 0,
      uniform: "distortion",
      min: -100,
      max: 100,
      ui: {
        label: "lens",
        control: "slider"
      }
    },
    aberrationAmt: {
      type: "float",
      default: 0,
      uniform: "aberrationAmt",
      min: 0,
      max: 100,
      ui: {
        label: "aberration",
        control: "slider"
      }
    },
    aspectLens: {
      type: "boolean",
      default: false,
      uniform: "aspectLens",
      ui: {
        label: "1:1 aspect",
        control: "checkbox"
      }
    }
  };

  passes = [
    {
      name: "render",
      program: "feedbackSynth",
      inputs: {
        selfTex: "selfTex"
      },
      outputs: {
        fragColor: "outputTex"
      }
    }
  ];
}
