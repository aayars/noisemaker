import { Effect } from '../../../src/runtime/effect.js';

/**
 * Glowing Edges
 * /shaders/effects/glowing_edges/glowing_edges.wgsl
 */
export default class GlowingEdges extends Effect {
  name = "GlowingEdges";
  namespace = "nm";
  func = "glowingedges";

  globals = {
    sobel_metric: {
        type: "enum",
        default: 1,
        uniform: "sobel_metric",
        ui: {
            label: "Sobel Metric"
        }
    },
    alpha: {
        type: "float",
        default: 1,
        uniform: "alpha",
        min: 0,
        max: 1,
        step: 0.05,
        ui: {
            label: "Alpha",
            control: "slider"
        }
    }
};

  // TODO: Define passes based on shader requirements
  // This effect was originally implemented as a WebGPU compute shader.
  // A render pass implementation needs to be created for GLSL/WebGL2 compatibility.
  passes = [
    {
      name: "main",
      type: "compute",
      program: "glowing_edges",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputBuffer: "outputColor"
      }
    }
  ];
}
