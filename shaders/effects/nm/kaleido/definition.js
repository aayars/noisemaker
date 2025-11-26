import { Effect } from '../../../src/runtime/effect.js';

/**
 * Kaleido
 * /shaders/effects/kaleido/kaleido.wgsl
 */
export default class Kaleido extends Effect {
  name = "Kaleido";
  namespace = "nm";
  func = "kaleido";

  globals = {
    sides: {
        type: "int",
        default: 6,
        uniform: "sides",
        min: 2,
        max: 32,
        step: 1,
        ui: {
            label: "Sides",
            control: "slider"
        }
    },
    sdf_sides: {
        type: "int",
        default: 5,
        uniform: "sdf_sides",
        min: 0,
        max: 12,
        step: 1,
        ui: {
            label: "SDF Sides",
            control: "slider"
        }
    },
    blend_edges: {
        type: "boolean",
        default: true,
        uniform: "blend_edges",
        ui: {
            label: "Blend Edges",
            control: "checkbox"
        }
    },
    point_freq: {
        type: "int",
        default: 1,
        uniform: "point_freq",
        min: 1,
        max: 32,
        step: 1,
        ui: {
            label: "Point Frequency",
            control: "slider"
        }
    },
    point_generations: {
        type: "int",
        default: 1,
        uniform: "point_generations",
        min: 1,
        max: 5,
        step: 1,
        ui: {
            label: "Generations",
            control: "slider"
        }
    },
    point_distrib: {
        type: "enum",
        default: 0,
        uniform: "point_distrib",
        ui: {
            label: "Distribution"
        }
    },
    point_drift: {
        type: "float",
        default: 0,
        uniform: "point_drift",
        min: 0,
        max: 1,
        step: 0.01,
        ui: {
            label: "Point Drift",
            control: "slider"
        }
    },
    point_corners: {
        type: "boolean",
        default: false,
        uniform: "point_corners",
        ui: {
            label: "Include Corners",
            control: "checkbox"
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
      program: "kaleido",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        outputBuffer: "outputColor"
      }
    }
  ];
}
