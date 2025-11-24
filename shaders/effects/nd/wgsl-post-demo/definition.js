import { Effect } from '../../../src/runtime/effect.js';

export default class WgslPostDemo extends Effect {
  name = "WgslPostDemo";
  namespace = "nd";
  func = "wgsl_post_demo";

  globals = {
    brightness: {
      type: "int",
      default: 0,
      min: -100,
      max: 100,
      ui: {
        label: "brightness",
        control: "slider"
      }
    },
    contrast: {
      type: "int",
      default: 0,
      min: -100,
      max: 100,
      ui: {
        label: "contrast",
        control: "slider"
      }
    },
    hue: {
      type: "int",
      default: 0,
      min: 0,
      max: 360,
      ui: {
        label: "hue",
        control: "slider"
      }
    },
    saturation: {
      type: "int",
      default: 0,
      min: -100,
      max: 100,
      ui: {
        label: "saturation",
        control: "slider"
      }
    }
  };

  passes = [
    {
      name: "render",
      type: "render",
      program: "wgsl-post-demo",
      inputs: {
        srcTex: "inputTex"
      },

      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
