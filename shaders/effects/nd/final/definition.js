import { Effect } from '../../../src/runtime/effect.js';

export default class Final extends Effect {
  name = "Final";
  namespace = "nd";
  func = "final";

  globals = {
    enabled: {
      type: "boolean",
      default: false,
      uniform: "enabled",
      ui: {
        label: "enabled",
        control: "checkbox"
      }
    },
    brightness: {
      type: "float",
      default: 0,
      uniform: "brightness",
      min: -100,
      max: 100,
      ui: {
        label: "brightness",
        control: "slider"
      }
    },
    contrast: {
      type: "float",
      default: 50,
      uniform: "contrast",
      min: 0,
      max: 100,
      ui: {
        label: "contrast",
        control: "slider"
      }
    },
    saturation: {
      type: "float",
      default: 0,
      uniform: "saturation",
      min: -100,
      max: 100,
      ui: {
        label: "saturation",
        control: "slider"
      }
    },
    hueRotation: {
      type: "float",
      default: 0,
      uniform: "hueRotation",
      min: 0,
      max: 360,
      ui: {
        label: "hue rotate",
        control: "slider"
      }
    },
    hueRange: {
      type: "float",
      default: 100,
      uniform: "hueRange",
      min: 0,
      max: 200,
      ui: {
        label: "hue range",
        control: "slider"
      }
    },
    invert: {
      type: "boolean",
      default: false,
      uniform: "invert",
      ui: {
        label: "invert",
        control: "checkbox"
      }
    },
    antialias: {
      type: "boolean",
      default: true,
      uniform: "antialias",
      ui: {
        label: "antialias",
        control: "checkbox"
      }
    }
  };

  passes = [
    {
      name: "render",
      type: "render",
      program: "final",
      inputs: {
        postTex: "inputTex"
      },

      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
