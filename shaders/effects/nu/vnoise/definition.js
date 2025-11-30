import { Effect } from '../../../src/runtime/effect.js';

export default class VNoise extends Effect {
  name = "VNoise";
  namespace = "nu";
  func = "vnoise";

  // WGSL uniform packing layout - maps uniform names to vec4 slots/components
  // Simplified: removed palette-related uniforms and hsv uniforms
  uniformLayout = {
    resolution: { slot: 0, components: 'xy' },
    time: { slot: 0, components: 'z' },
    aspectRatio: { slot: 0, components: 'w' },
    xScale: { slot: 1, components: 'x' },
    yScale: { slot: 1, components: 'y' },
    seed: { slot: 1, components: 'z' },
    loopScale: { slot: 1, components: 'w' },
    loopAmp: { slot: 2, components: 'x' },
    loopOffset: { slot: 2, components: 'y' },
    noiseType: { slot: 2, components: 'z' },
    octaves: { slot: 2, components: 'w' },
    ridges: { slot: 3, components: 'x' },
    wrap: { slot: 3, components: 'y' },
    refractMode: { slot: 3, components: 'z' },
    refractAmt: { slot: 3, components: 'w' },
    kaleido: { slot: 4, components: 'x' },
    metric: { slot: 4, components: 'y' },
    colorMode: { slot: 4, components: 'z' }
  };

  globals = {
    aspect: {
      type: "float",
      default: null,
      uniform: "aspect",
      ui: {
        label: "aspect",
        control: "slider"
      }
    },
    noiseType: {
      type: "int",
      default: 10,
      uniform: "noiseType",
      choices: {
        Constant: 0,
        Linear: 1,
        Hermite: 2,
        "Catmull Rom 3x3": 3,
        "Catmull Rom 4x4": 4,
        "B Spline 3x3": 5,
        "B Spline 4x4": 6,
        Simplex: 10,
        Sine: 11
      },
      ui: {
        label: "noise type",
        control: "dropdown"
      }
    },
    octaves: {
      type: "int",
      default: 2,
      uniform: "octaves",
      min: 1,
      max: 8,
      ui: {
        label: "octaves",
        control: "slider"
      }
    },
    xScale: {
      type: "float",
      default: 75,
      uniform: "xScale",
      min: 1,
      max: 100,
      ui: {
        label: "horiz scale",
        control: "slider"
      }
    },
    yScale: {
      type: "float",
      default: 75,
      uniform: "yScale",
      min: 1,
      max: 100,
      ui: {
        label: "vert scale",
        control: "slider"
      }
    },
    ridges: {
      type: "boolean",
      default: false,
      uniform: "ridges",
      ui: {
        label: "ridges",
        control: "checkbox"
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
    },
    refractMode: {
      type: "int",
      default: 2,
      uniform: "refractMode",
      choices: {
        Color: 0,
        Topology: 1,
        "Color + Topology": 2
      },
      ui: {
        label: "refract mode",
        control: "dropdown"
      }
    },
    refractAmt: {
      type: "float",
      default: 0,
      uniform: "refractAmt",
      min: 0,
      max: 100,
      ui: {
        label: "refract",
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
        label: "seed",
        control: "slider"
      }
    },
    loopOffset: {
      type: "int",
      default: 300,
      uniform: "loopOffset",
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
        "Misc:": null,
        Noise: 300,
        Rings: 400,
        Sine: 410
      },
      ui: {
        label: "loop offset",
        control: "dropdown"
      }
    },
    loopScale: {
      type: "float",
      default: 75,
      uniform: "loopScale",
      min: 1,
      max: 100,
      ui: {
        label: "loop scale",
        control: "slider"
      }
    },
    loopAmp: {
      type: "float",
      default: 25,
      uniform: "loopAmp",
      min: -100,
      max: 100,
      ui: {
        label: "loop power",
        control: "slider"
      }
    },
    kaleido: {
      type: "int",
      default: 1,
      uniform: "kaleido",
      min: 1,
      max: 32,
      ui: {
        label: "kaleido sides",
        control: "slider"
      }
    },
    metric: {
      type: "int",
      default: 0,
      uniform: "metric",
      choices: {
        Circle: 0,
        Diamond: 1,
        Hexagon: 2,
        Octagon: 3,
        Square: 4,
        Triangle: 5
      },
      ui: {
        label: "kaleido shape",
        control: "dropdown"
      }
    },
    colorMode: {
      type: "int",
      default: 0,
      uniform: "colorMode",
      choices: {
        Mono: 0,
        RGB: 1
      },
      ui: {
        label: "color mode",
        control: "dropdown"
      }
    }
  };

  passes = [
    {
      name: "render",
      program: "vnoise",
      inputs: {
      },

      outputs: {
        fragColor: "outputTex"
      }
    }
  ];
}
