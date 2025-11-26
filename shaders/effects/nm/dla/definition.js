import { Effect } from '../../../src/runtime/effect.js';

/**
 * DLA (Diffusion-Limited Aggregation)
 * /shaders/effects/dla/dla.wgsl
 */
export default class Dla extends Effect {
  name = "Dla";
  namespace = "nm";
  func = "dla";

  globals = {
    padding: {
        type: "float",
        default: 2,
        uniform: "padding",
        min: 1,
        max: 8,
        step: 0.5,
        ui: {
            label: "Padding",
            control: "slider"
        }
    },
    seed_density: {
        type: "float",
        default: 0.005,
        uniform: "seed_density",
        min: 0.001,
        max: 0.1,
        step: 0.001,
        ui: {
            label: "Seed Density",
            control: "slider"
        }
    },
    density: {
        type: "float",
        default: 0.2,
        uniform: "density",
        min: 0.01,
        max: 0.8,
        step: 0.01,
        ui: {
            label: "Walker Density",
            control: "slider"
        }
    },
    speed: {
        type: "float",
        default: 1,
        uniform: "speed",
        min: 0.1,
        max: 4,
        step: 0.1,
        ui: {
            label: "Speed",
            control: "slider"
        }
    },
    alpha: {
        type: "float",
        default: 0.75,
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

  // Agent state texture: 256x256 agents = 65536 walkers
  // Each pixel stores: xy = position, z = seed, w = stuck flag
  textures = {
    global_grid_state: { width: "100%", height: "100%", format: "rgba16f" },
    global_agent_state: { width: 256, height: 256, format: "rgba16f" }
  };

  passes = [
    {
      name: "decay_grid",
      type: "compute",  // GPGPU: grid state update
      program: "init_from_prev",
      inputs: {
        gridTex: "global_grid_state"
      },
      outputs: {
        dlaOutColor: "global_grid_state"
      }
    },
    {
      name: "simulate_agents",
      type: "compute",  // GPGPU: agent simulation
      program: "agent_walk",
      inputs: {
        agentTex: "global_agent_state",
        gridTex: "global_grid_state"
      },
      outputs: {
        dlaOutColor: "global_agent_state"
      }
    },
    {
      name: "deposit_agents",
      type: "render",
      program: "save_cluster",
      drawMode: "points",
      count: 65536,  // 256x256 agents
      blend: ["ONE", "ONE"],
      inputs: {
        agentTex: "global_agent_state"
      },
      outputs: {
        dlaOutColor: "global_grid_state"
      }
    },
    {
      name: "final_blend",
      type: "render",
      program: "final_blend",
      inputs: {
        gridTex: "global_grid_state",
        inputTex: "inputTex"
      },
      outputs: {
        dlaOutColor: "outputColor"
      }
    }
  ];
}
