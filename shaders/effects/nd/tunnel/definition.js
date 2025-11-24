import { Effect } from '../../../src/runtime/effect.js';

export default class Tunnel extends Effect {
  name = "Tunnel";
  namespace = "nd";
  func = "tunnel";

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
    distortionType: {
      type: "int",
      default: 0,
      choices: {
        Circle: 0,
        Triangle: 1,
        "Rounded Square": 2,
        Square: 3,
        Hexagon: 4,
        Octagon: 5
      },
      ui: {
        label: "type",
        control: "dropdown"
      }
    },
    flip: {
      type: "int",
      default: 0,
      choices: {
        None: 0,
        "Flip:": null,
        All: 1,
        Horizontal: 2,
        Vertical: 3,
        "Mirror:": null,
        "Left → Right": 11,
        "Left ← Right": 12,
        "Up → Down": 13,
        "Up ← Down": 14,
        "L → R / U → D": 15,
        "L → R / U ← D": 16,
        "L ← R / U → D": 17,
        "L ← R / U ← D": 18
      },
      ui: {
        label: "flip/mirror",
        control: "dropdown"
      }
    },
    speed: {
      type: "int",
      default: 1,
      min: -5,
      max: 5,
      ui: {
        label: "speed",
        control: "slider"
      }
    },
    rotation: {
      type: "int",
      default: 0,
      min: -5,
      max: 5,
      ui: {
        label: "rotation",
        control: "slider"
      }
    },
    center: {
      type: "float",
      default: -5,
      min: -5,
      max: 5,
      ui: {
        label: "center",
        control: "slider"
      }
    },
    scale: {
      type: "float",
      default: 0,
      min: -5,
      max: 5,
      ui: {
        label: "scale",
        control: "slider"
      }
    },
    aspectLens: {
      type: "boolean",
      default: true,
      ui: {
        label: "1:1 aspect",
        control: "checkbox"
      }
    }
  };

  passes = [
    {
      name: "render",
      type: "render",
      program: "tunnel",
      inputs: {
        inputTex: "inputTex"
      },

      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
