import { Effect } from '../../../src/runtime/effect.js';

export default class Cell extends Effect {
  name = "Cell";
  namespace = "nu";
  func = "cell";

  // WGSL uniform packing layout - maps uniform names to vec4 slots/components
  uniformLayout = {
    resolution: { slot: 0, components: 'xy' },
    time: { slot: 0, components: 'z' },
    seed: { slot: 0, components: 'w' },
    metric: { slot: 1, components: 'x' },
    scale: { slot: 1, components: 'y' },
    cellScale: { slot: 1, components: 'z' },
    cellSmooth: { slot: 1, components: 'w' },
    cellVariation: { slot: 2, components: 'x' },
    loopAmp: { slot: 2, components: 'y' },
    texSource: { slot: 2, components: 'z' },
    texInfluence: { slot: 2, components: 'w' },
    texIntensity: { slot: 3, components: 'x' }
  };

  globals = {
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
        Triangle: 6
      },
      ui: {
        label: "metric",
        control: "dropdown"
      }
    },
    scale: {
      type: "float",
      default: 75,
      uniform: "scale",
      min: 1,
      max: 100,
      ui: {
        label: "noise scale",
        control: "slider"
      }
    },
    cellScale: {
      type: "float",
      default: 87,
      uniform: "cellScale",
      min: 1,
      max: 100,
      ui: {
        label: "cell scale",
        control: "slider"
      }
    },
    cellSmooth: {
      type: "float",
      default: 11,
      uniform: "cellSmooth",
      min: 0,
      max: 100,
      ui: {
        label: "cell smooth",
        control: "slider"
      }
    },
    cellVariation: {
      type: "float",
      default: 50,
      uniform: "cellVariation",
      min: 0,
      max: 100,
      ui: {
        label: "cell variation",
        control: "slider"
      }
    },
    loopAmp: {
      type: "int",
      default: 1,
      uniform: "loopAmp",
      min: 0,
      max: 5,
      ui: {
        label: "speed",
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
    texSource: {
      type: "int",
      default: 0,
      uniform: "texSource",
      choices: {
        None: 0,
        Input: 3
      },
      ui: {
        label: "tex source",
        control: "dropdown"
      }
    },
    texInfluence: {
      type: "int",
      default: 1,
      uniform: "texInfluence",
      choices: {
        Warp: null,
        "Cell Scale": 1,
        "Noise Scale": 2,
        Combine: null,
        Add: 10,
        Divide: 11,
        Min: 12,
        Max: 13,
        Mod: 14,
        Multiply: 15,
        Subtract: 16
      },
      ui: {
        label: "influence",
        control: "dropdown"
      }
    },
    texIntensity: {
      type: "float",
      default: 100,
      uniform: "texIntensity",
      min: 0,
      max: 100,
      ui: {
        label: "intensity",
        control: "slider"
      }
    }
  };

  passes = [
    {
      name: "render",
      program: "cell",
      inputs: {
      },

      outputs: {
        fragColor: "outputTex"
      }
    }
  ];
}
