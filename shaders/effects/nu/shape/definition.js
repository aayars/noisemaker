import { Effect } from '../../../src/runtime/effect.js';

export default class Shape extends Effect {
  name = "Shape";
  namespace = "nu";
  func = "shape";

  // WGSL uniform packing layout - simplified (no palette)
  uniformLayout = {
    resolution: { slot: 0, components: 'xy' },
    time: { slot: 0, components: 'z' },
    seed: { slot: 0, components: 'w' },
    wrap: { slot: 1, components: 'x' },
    loopAOffset: { slot: 1, components: 'y' },
    loopBOffset: { slot: 1, components: 'z' },
    loopAScale: { slot: 1, components: 'w' },
    loopBScale: { slot: 2, components: 'x' },
    loopAAmp: { slot: 2, components: 'y' },
    loopBAmp: { slot: 2, components: 'z' }
  };

  globals = {
    loopAOffset: {
      type: "int",
      default: 40,
      uniform: "loopAOffset",
      choices: {
        "Shapes:": null,
        Circle: 10,
        Triangle: 20,
        Diamond: 30,
        Square: 40,
        Pentagon: 50,
        Hexagon: 60,
        Heptagon: 70,
        Octagon: 80,
        Nonagon: 90,
        Decagon: 100,
        Hendecagon: 110,
        Dodecagon: 120,
        "Directional:": null,
        "Horizontal Scan": 200,
        "Vertical Scan": 210,
        "Noise:": null,
        "Noise Constant": 300,
        "Noise Linear": 310,
        "Noise Hermite": 320,
        "Noise Catmull Rom 3x3": 330,
        "Noise Catmull Rom 4x4": 340,
        "Noise B Spline 3x3": 350,
        "Noise B Spline 4x4": 360,
        "Noise Simplex": 370,
        "Noise Sine": 380,
        "Misc:": null,
        Rings: 400,
        Sine: 410
      },
      ui: {
        label: "loop a",
        control: "dropdown"
      }
    },
    loopBOffset: {
      type: "int",
      default: 30,
      uniform: "loopBOffset",
      choices: {
        "Shapes:": null,
        Circle: 10,
        Triangle: 20,
        Diamond: 30,
        Square: 40,
        Pentagon: 50,
        Hexagon: 60,
        Heptagon: 70,
        Octagon: 80,
        Nonagon: 90,
        Decagon: 100,
        Hendecagon: 110,
        Dodecagon: 120,
        "Directional:": null,
        "Horizontal Scan": 200,
        "Vertical Scan": 210,
        "Noise:": null,
        "Noise Constant": 300,
        "Noise Linear": 310,
        "Noise Hermite": 320,
        "Noise Catmull Rom 3x3": 330,
        "Noise Catmull Rom 4x4": 340,
        "Noise B Spline 3x3": 350,
        "Noise B Spline 4x4": 360,
        "Noise Simplex": 370,
        "Noise Sine": 380,
        "Misc:": null,
        Rings: 400,
        Sine: 410
      },
      ui: {
        label: "loop b",
        control: "dropdown"
      }
    },
    loopAScale: {
      type: "float",
      default: 1,
      uniform: "loopAScale",
      min: 1,
      max: 100,
      ui: {
        label: "a scale",
        control: "slider"
      }
    },
    loopBScale: {
      type: "float",
      default: 1,
      uniform: "loopBScale",
      min: 1,
      max: 100,
      ui: {
        label: "b scale",
        control: "slider"
      }
    },
    loopAAmp: {
      type: "float",
      default: 50,
      uniform: "loopAAmp",
      min: -100,
      max: 100,
      ui: {
        label: "a power",
        control: "slider"
      }
    },
    loopBAmp: {
      type: "float",
      default: 50,
      uniform: "loopBAmp",
      min: -100,
      max: 100,
      ui: {
        label: "b power",
        control: "slider"
      }
    },
    seed: {
      type: "int",
      default: 1,
      uniform: "seed",
      min: 1,
      max: 100,
      ui: {
        label: "noise seed",
        control: "slider"
      }
    },
    wrap: {
      type: "boolean",
      default: true,
      uniform: "wrap",
      ui: {
        label: "wrap",
        control: "checkbox"
      }
    }
  };

  passes = [
    {
      name: "render",
      program: "shape",
      inputs: {},
      outputs: {
        fragColor: "outputTex"
      }
    }
  ];
}
