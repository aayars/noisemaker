import { Effect } from '../../../src/runtime/effect.js';

/**
 * Pixel Sort
 * /shaders/effects/pixel_sort/pixel_sort.wgsl
 */
export default class PixelSort extends Effect {
  name = "PixelSort";
  namespace = "nm";
  func = "pixelsort";

  globals = {
    angled: {
        type: "float",
        default: 0,
        min: -180,
        max: 180,
        step: 1,
        ui: {
            label: "Angle",
            control: "slider"
        }
    },
    darkest: {
        type: "boolean",
        default: false,
        ui: {
            label: "Darkest First",
            control: "checkbox"
        }
    }
};

  textures = {
    prepared: { width: "100%", height: "100%", format: "rgba16f" },
    stats: { width: 1, height: "100%", format: "rgba16f" },
    histogram: { width: 256, height: "100%", format: "rgba16f" },
    cumulative: { width: 256, height: "100%", format: "rgba16f" },
    sorted: { width: "100%", height: "100%", format: "rgba16f" }
  };

  passes = [
    {
      name: "prepare",
      type: "render",
      program: "prepare",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputColor: "prepared"
      }
    },
    {
      name: "stats",
      type: "render",
      program: "stats",
      inputs: {
        inputTex: "prepared"
      },
      outputs: {
        outputColor: "stats"
      }
    },
    {
      name: "histogram_clear",
      type: "render",
      program: "clear",
      inputs: {},
      outputs: {
        outputColor: "histogram"
      }
    },
    {
      name: "histogram_r",
      type: "render",
      program: "histogram",
      drawMode: "points",
      count: "input",
      blend: ["ONE", "ONE"],
      uniforms: { channel: 0 },
      inputs: {
        inputTex: "prepared"
      },
      outputs: {
        outputColor: "histogram"
      }
    },
    {
      name: "histogram_g",
      type: "render",
      program: "histogram",
      drawMode: "points",
      count: "input",
      blend: ["ONE", "ONE"],
      uniforms: { channel: 1 },
      inputs: {
        inputTex: "prepared"
      },
      outputs: {
        outputColor: "histogram"
      }
    },
    {
      name: "histogram_b",
      type: "render",
      program: "histogram",
      drawMode: "points",
      count: "input",
      blend: ["ONE", "ONE"],
      uniforms: { channel: 2 },
      inputs: {
        inputTex: "prepared"
      },
      outputs: {
        outputColor: "histogram"
      }
    },
    {
      name: "histogram_a",
      type: "render",
      program: "histogram",
      drawMode: "points",
      count: "input",
      blend: ["ONE", "ONE"],
      uniforms: { channel: 3 },
      inputs: {
        inputTex: "prepared"
      },
      outputs: {
        outputColor: "histogram"
      }
    },
    {
      name: "cumulative",
      type: "render",
      program: "cumulative",
      inputs: {
        inputTex: "histogram"
      },
      outputs: {
        outputColor: "cumulative"
      }
    },
    {
      name: "resolve",
      type: "render",
      program: "resolve",
      inputs: {
        inputTex: "prepared",
        statsTex: "stats",
        cumulativeTex: "cumulative"
      },
      outputs: {
        outputColor: "sorted"
      }
    },
    {
      name: "finalize",
      type: "render",
      program: "finalize",
      inputs: {
        inputTex: "sorted",
        originalTex: "inputTex"
      },
      outputs: {
        outputColor: "outputColor"
      }
    }
  ];
}
