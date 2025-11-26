import { Effect } from '../../../src/runtime/effect.js';

/**
 * Voronoi
 * /shaders/effects/voronoi/voronoi.wgsl
 */
export default class Voronoi extends Effect {
  name = "Voronoi";
  namespace = "nm";
  func = "voronoi";

  globals = {
    diagram_type: {
        type: "integer",
        default: 1,
        uniform: "diagram_type",
        min: 0,
        max: 7,
        step: 1,
        ui: {
            label: "Diagram Type",
            control: "slider"
        }
    },
    nth: {
        type: "integer",
        default: 0,
        uniform: "nth",
        min: -4,
        max: 4,
        step: 1,
        ui: {
            label: "Nth Neighbor",
            control: "slider"
        }
    },
    dist_metric: {
        type: "integer",
        default: 1,
        uniform: "dist_metric",
        min: 1,
        max: 4,
        step: 1,
        ui: {
            label: "Distance Metric",
            control: "slider"
        }
    },
    sdf_sides: {
        type: "integer",
        default: 3,
        uniform: "sdf_sides",
        min: 3,
        max: 24,
        step: 1,
        ui: {
            label: "SDF Sides",
            control: "slider"
        }
    },
    alpha: {
        type: "float",
        default: 1,
        uniform: "alpha",
        min: 0,
        max: 1,
        step: 0.01,
        ui: {
            label: "Alpha",
            control: "slider"
        }
    },
    with_refract: {
        type: "float",
        default: 0,
        uniform: "with_refract",
        min: 0,
        max: 2,
        step: 0.01,
        ui: {
            label: "Refract",
            control: "slider"
        }
    },
    inverse: {
        type: "boolean",
        default: false,
        uniform: "inverse",
        ui: {
            label: "Inverse",
            control: "checkbox"
        }
    },
    ridges_hint: {
        type: "boolean",
        default: false,
        uniform: "ridges_hint",
        ui: {
            label: "Ridges Hint",
            control: "checkbox"
        }
    },
    refract_y_from_offset: {
        type: "boolean",
        default: true,
        uniform: "refract_y_from_offset",
        ui: {
            label: "Refract Offset",
            control: "checkbox"
        }
    },
    point_freq: {
        type: "integer",
        default: 3,
        uniform: "point_freq",
        min: 1,
        max: 10,
        step: 1,
        ui: {
            label: "Point Frequency",
            control: "slider"
        }
    },
    point_generations: {
        type: "integer",
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
        type: "integer",
        default: 0,
        uniform: "point_distrib",
        min: 0,
        max: 9,
        step: 1,
        ui: {
            label: "Distribution",
            control: "slider"
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
    },
    downsample: {
        type: "boolean",
        default: true,
        uniform: "downsample",
        ui: {
            label: "Downsample",
            control: "checkbox"
        }
    }
};

  passes = [
    {
      name: "main",
      type: "render",
      program: "voronoi",
      inputs: {
        inputTex: "inputTex"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
