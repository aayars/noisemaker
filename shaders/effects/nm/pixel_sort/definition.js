import { Effect } from '../../../src/runtime/effect.js';

/**
 * Pixel Sort - GPGPU Implementation
 * 
 * Multi-pass GPGPU pipeline using textures as data buffers:
 * 1. Prepare: Pad to square, rotate by angle, optionally invert for darkest
 * 2. Luminance: Compute per-pixel luminance → store in texture
 * 3. Find Brightest: Find brightest x per row → store in texture  
 * 4. Compute Rank: For each pixel, count brighter pixels → store rank
 * 5. Gather: Use ranks to gather sorted pixels with alignment
 * 6. Finalize: Rotate back, max blend with original
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
    luminance: { width: "100%", height: "100%", format: "rgba16f" },
    brightest: { width: "100%", height: "100%", format: "rgba16f" },
    rank: { width: "100%", height: "100%", format: "rgba16f" },
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
      uniforms: {
        resolution: "resolution",
        angled: "angled",
        darkest: "darkest"
      },
      outputs: {
        outputColor: "prepared"
      }
    },
    {
      name: "luminance",
      type: "render",
      program: "luminance",
      inputs: {
        inputTex: "prepared"
      },
      outputs: {
        outputColor: "luminance"
      }
    },
    {
      name: "find_brightest",
      type: "render",
      program: "find_brightest",
      inputs: {
        lumTex: "luminance"
      },
      outputs: {
        outputColor: "brightest"
      }
    },
    {
      name: "compute_rank",
      type: "render",
      program: "compute_rank",
      inputs: {
        lumTex: "luminance"
      },
      outputs: {
        outputColor: "rank"
      }
    },
    {
      name: "gather_sorted",
      type: "render",
      program: "gather_sorted",
      inputs: {
        preparedTex: "prepared",
        rankTex: "rank",
        brightestTex: "brightest"
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
      uniforms: {
        resolution: "resolution",
        angled: "angled",
        darkest: "darkest"
      },
      outputs: {
        outputColor: "outputColor"
      }
    }
  ];
}
