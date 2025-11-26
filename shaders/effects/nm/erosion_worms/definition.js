import { Effect } from '../../../src/runtime/effect.js';

/**
 * Erosion Worms - Agent-based gradient-descent flow field effect
 * 
 * Architecture (GPGPU via render passes):
 * - Uses fragment shaders with MRT for agent simulation
 * - Global surfaces for agent state (position/dir, color/inertia, age) with ping-pong
 * - Trail accumulation via point-sprite deposit pass
 * - Multi-pass: agent_move -> deposit -> diffuse -> blend
 * 
 * Agent format: [x, y, x_dir, y_dir] [r, g, b, inertia] [age, 0, 0, 0]
 * Stored across 3 state textures using MRT
 */
export default class ErosionWorms extends Effect {
  name = "ErosionWorms";
  namespace = "nm";
  func = "erosion_worms";

  globals = {
    density: {
      type: "float",
      default: 5,
      uniform: "density",
      min: 1,
      max: 100,
      step: 1,
      ui: {
        label: "Density",
        control: "slider"
      }
    },
    stride: {
      type: "float",
      default: 1,
      uniform: "stride",
      min: 0.1,
      max: 10,
      step: 0.1,
      ui: {
        label: "Stride",
        control: "slider"
      }
    },
    quantize: {
      type: "boolean",
      default: false,
      uniform: "quantize",
      ui: {
        label: "Quantize",
        control: "checkbox"
      }
    },
    intensity: {
      type: "float",
      default: 90,
      uniform: "intensity",
      min: 0,
      max: 100,
      step: 1,
      ui: {
        label: "Trail Persistence",
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
    xy_blend: {
      type: "boolean",
      default: false,
      uniform: "xy_blend",
      ui: {
        label: "XY Blend",
        control: "checkbox"
      }
    },
    worm_lifetime: {
      type: "float",
      default: 30,
      uniform: "worm_lifetime",
      min: 0,
      max: 60,
      step: 1,
      ui: {
        label: "Lifetime",
        control: "slider"
      }
    },
    inputIntensity: {
      type: "float",
      default: 0,
      uniform: "inputIntensity",
      min: 0,
      max: 100,
      step: 1,
      ui: {
        label: "Input Intensity",
        control: "slider"
      }
    }
  };

  passes = [
    {
      name: "agent",
      type: "compute",
      program: "agent",
      drawBuffers: 3,
      inputs: {
        stateTex1: "global_erosion_state1",
        stateTex2: "global_erosion_state2",
        stateTex3: "global_erosion_state3",
        mixerTex: "inputTex"
      },
      outputs: {
        outState1: "global_erosion_state1",
        outState2: "global_erosion_state2",
        outState3: "global_erosion_state3"
      }
    },
    {
      name: "diffuse",
      type: "compute",
      program: "diffuse",
      inputs: {
        sourceTex: "global_erosion_trail"
      },
      outputs: {
        fragColor: "global_erosion_trail"
      }
    },
    {
      name: "deposit",
      type: "render",
      program: "deposit",
      drawMode: "points",
      count: 262144,
      blend: true,
      inputs: {
        stateTex1: "global_erosion_state1",
        stateTex2: "global_erosion_state2"
      },
      outputs: {
        fragColor: "global_erosion_trail"
      }
    },
    {
      name: "blend",
      type: "compute",
      program: "blend",
      inputs: {
        mixerTex: "inputTex",
        trailTex: "global_erosion_trail"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
