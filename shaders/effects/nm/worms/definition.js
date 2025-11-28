import { Effect } from '../../../src/runtime/effect.js';

/**
 * Worms - Agent-based flow field effect with temporal accumulation
 * 
 * Architecture (GPGPU via render passes):
 * - Uses fragment shaders with MRT for agent simulation
 * - Global surfaces for agent state (position/dir, color, age) with ping-pong
 * - Trail accumulation via point-sprite deposit pass
 * - Multi-pass: agent -> deposit -> diffuse -> blend
 * 
 * Agent format: [x, y, rot, stride] [r, g, b, seed] [age, behavior, 0, 0]
 * Stored across 3 state textures using MRT
 */
export default class Worms extends Effect {
  name = "Worms";
  namespace = "nm";
  func = "worms";

  globals = {
    behavior: {
      type: "int",
      default: 1,
      uniform: "behavior",
      choices: {
        None: 0,
        Obedient: 1,
        Crosshatch: 2,
        Unruly: 3,
        Chaotic: 4,
        "Random Mix": 5,
        Meandering: 10
      },
      ui: {
        label: "Behavior",
        control: "dropdown"
      }
    },
    density: {
      type: "float",
      default: 20,
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
    strideDeviation: {
      type: "float",
      default: 0.05,
      uniform: "strideDeviation",
      min: 0,
      max: 0.5,
      step: 0.01,
      ui: {
        label: "Stride Deviation",
        control: "slider"
      }
    },
    kink: {
      type: "float",
      default: 1,
      uniform: "kink",
      min: 0,
      max: 10,
      step: 0.1,
      ui: {
        label: "Kink",
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
    inputIntensity: {
      type: "float",
      default: 100,
      uniform: "inputIntensity",
      min: 0,
      max: 100,
      step: 1,
      ui: {
        label: "Input Intensity",
        control: "slider"
      }
    },
    lifetime: {
      type: "float",
      default: 30,
      uniform: "lifetime",
      min: 0,
      max: 60,
      step: 1,
      ui: {
        label: "Lifetime",
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
        stateTex1: "globalWormsState1",
        stateTex2: "globalWormsState2",
        stateTex3: "globalWormsState3",
        mixerTex: "inputTex"
      },
      uniforms: {
        behavior: "behavior",
        density: "density",
        stride: "stride",
        strideDeviation: "strideDeviation",
        kink: "kink",
        quantize: "quantize",
        lifetime: "lifetime"
      },
      outputs: {
        outState1: "globalWormsState1",
        outState2: "globalWormsState2",
        outState3: "globalWormsState3"
      }
    },
    {
      name: "diffuse",
      program: "diffuse",
      inputs: {
        sourceTex: "globalWormsTrail"
      },
      uniforms: {
        intensity: "intensity"
      },
      outputs: {
        fragColor: "globalWormsTrail"
      }
    },
    {
      name: "deposit",
      program: "deposit",
      drawMode: "points",
      count: 262144,
      blend: true,
      inputs: {
        stateTex1: "globalWormsState1",
        stateTex2: "globalWormsState2"
      },
      outputs: {
        fragColor: "globalWormsTrail"
      }
    },
    {
      name: "blend",
      program: "blend",
      inputs: {
        mixerTex: "inputTex",
        trailTex: "globalWormsTrail"
      },
      uniforms: {
        inputIntensity: "inputIntensity"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
