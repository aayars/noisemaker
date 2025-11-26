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
  func = "erosionWorms";

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
    xyBlend: {
      type: "boolean",
      default: false,
      uniform: "xyBlend",
      ui: {
        label: "XY Blend",
        control: "checkbox"
      }
    },
    wormLifetime: {
      type: "float",
      default: 30,
      uniform: "wormLifetime",
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
      program: "agent",
      drawBuffers: 3,
      inputs: {
        stateTex1: "globalErosionState1",
        stateTex2: "globalErosionState2",
        stateTex3: "globalErosionState3",
        mixerTex: "inputTex"
      },
      outputs: {
        outState1: "globalErosionState1",
        outState2: "globalErosionState2",
        outState3: "globalErosionState3"
      }
    },
    {
      name: "diffuse",
      program: "diffuse",
      inputs: {
        sourceTex: "globalErosionTrail"
      },
      outputs: {
        fragColor: "globalErosionTrail"
      }
    },
    {
      name: "deposit",
      program: "deposit",
      drawMode: "points",
      count: 262144,
      blend: true,
      inputs: {
        stateTex1: "globalErosionState1",
        stateTex2: "globalErosionState2"
      },
      outputs: {
        fragColor: "globalErosionTrail"
      }
    },
    {
      name: "blend",
      program: "blend",
      inputs: {
        mixerTex: "inputTex",
        trailTex: "globalErosionTrail"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
