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
    sdfSides: {
        type: "int",
        default: 5,
        uniform: "sdfSides",
        min: 0,
        max: 12,
        step: 1,
        ui: {
            label: "SDF Sides",
            control: "slider"
        }
    },
    blendEdges: {
        type: "boolean",
        default: true,
        uniform: "blendEdges",
        ui: {
            label: "Blend Edges",
            control: "checkbox"
        }
    },
    pointFreq: {
        type: "int",
        default: 1,
        uniform: "pointFreq",
        min: 1,
        max: 32,
        step: 1,
        ui: {
            label: "Point Frequency",
            control: "slider"
        }
    },
    pointGenerations: {
        type: "int",
        default: 1,
        uniform: "pointGenerations",
        min: 1,
        max: 5,
        step: 1,
        ui: {
            label: "Generations",
            control: "slider"
        }
    },
    pointDistrib: {
        type: "enum",
        default: 0,
        uniform: "pointDistrib",
        ui: {
            label: "Distribution"
        }
    },
    pointDrift: {
        type: "float",
        default: 0,
        uniform: "pointDrift",
        min: 0,
        max: 1,
        step: 0.01,
        ui: {
            label: "Point Drift",
            control: "slider"
        }
    },
    pointCorners: {
        type: "boolean",
        default: false,
        uniform: "pointCorners",
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
