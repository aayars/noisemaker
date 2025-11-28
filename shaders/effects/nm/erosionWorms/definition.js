import { Effect } from '../../../src/runtime/effect.js';

/**
 * Erosion Worms - Agent-based gradient-descent flow field effect
 * 
 * Architecture (GPGPU via render passes):
 * - Uses fragment shaders with MRT for agent simulation
 * - `global`-prefixed textures get automatic ping-pong (read previous, write current)
 * - Trail accumulation via point-sprite deposit pass
 * - Multi-pass: init -> agent -> deposit -> diffuse -> blend
 * 
 * Agent format: [x, y, x_dir, y_dir] [r, g, b, inertia] [age, 0, 0, 0]
 * Stored across 3 state textures using MRT
 * Agent count: 256x256 = 65536 agents
 * 
 * Trail flow: 
 *   init: copy previous TrailA with decay → TrailB (preserves accumulation)
 *   deposit: add agent points to TrailB (additive)
 *   diffuse: blur TrailB → TrailA (swaps for next frame)
 *   blend: combine TrailA with input
 */
export default class ErosionWorms extends Effect {
  name = "ErosionWorms";
  namespace = "nm";
  func = "erosionWorms";
  
  // State textures with `global` prefix for automatic ping-pong
  // Agent state: 256x256 = 65536 agents
  // Trail: Two textures for proper ping-pong within frame
  textures = {
    globalErosionState1: { width: 256, height: 256, format: "rgba16f" },
    globalErosionState2: { width: 256, height: 256, format: "rgba16f" },
    globalErosionState3: { width: 256, height: 256, format: "rgba16f" },
    globalErosionTrailA: { width: "100%", height: "100%", format: "rgba16f" },
    globalErosionTrailB: { width: "100%", height: "100%", format: "rgba16f" }
  };

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
    // Pass 0: Copy previous trail with decay to preserve accumulation
    // TrailA (previous frame via ping-pong) → TrailB
    {
      name: "initFromPrev",
      program: "initFromPrev",
      inputs: {
        prevTrailTex: "globalErosionTrailA"
      },
      outputs: {
        fragColor: "globalErosionTrailB"
      }
    },
    // Pass 1: Update agent state (position, direction, color, age)
    // MRT outputs to 3 state textures simultaneously
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
    // Pass 2: Deposit agent trails as point sprites onto TrailB (additive)
    {
      name: "deposit",
      program: "deposit",
      drawMode: "points",
      count: 65536,  // 256x256 agents
      blend: ["one", "one"],  // Additive blending onto faded trail
      inputs: {
        stateTex1: "globalErosionState1",
        stateTex2: "globalErosionState2"
      },
      outputs: {
        fragColor: "globalErosionTrailB"
      }
    },
    // Pass 3: Diffuse/blur TrailB → TrailA (sets up next frame's ping-pong)
    {
      name: "diffuse",
      program: "diffuse",
      inputs: {
        sourceTex: "globalErosionTrailB"
      },
      outputs: {
        fragColor: "globalErosionTrailA"
      }
    },
    // Pass 4: Final composite with input
    {
      name: "blend",
      program: "blend",
      inputs: {
        inputTex: "inputTex",
        trailTex: "globalErosionTrailA"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
