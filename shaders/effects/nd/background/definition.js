import { Effect } from '../../../src/runtime/effect.js';

export default class Background extends Effect {
  name = "Background";
  namespace = "nd";
  func = "background";

  globals = {
    backgroundType: {
      type: "int",
      default: 10,
      uniform: "backgroundType",
      choices: {
        "Solid": 0,
        "Horizontal 1->2": 10,
        "Horizontal 2->1": 11,
        "Vertical 1->2": 20,
        "Vertical 2->1": 21,
        "Radial 1->2": 30,
        "Radial 2->1": 31
      },
      ui: { label: "Type", control: "dropdown" }
    },
    rotation: {
      type: "float",
      default: 0,
      uniform: "rotation",
      min: -180,
      max: 180,
      ui: { label: "Rotation", control: "slider" }
    },
    opacity: {
      type: "float",
      default: 100,
      uniform: "opacity",
      min: 0,
      max: 100,
      ui: { label: "Opacity", control: "slider" }
    },
    color1: {
      type: "vec4",
      default: [0, 0, 0, 1],
      uniform: "color1",
      ui: { label: "Color 1", control: "color" }
    },
    color2: {
      type: "vec4",
      default: [1, 1, 1, 1],
      uniform: "color2",
      ui: { label: "Color 2", control: "color" }
    }
  };

  passes = [
    {
      name: "render",
      program: "background",
      outputs: {
        fragColor: "outputTex"
      }
    }
  ];
}
