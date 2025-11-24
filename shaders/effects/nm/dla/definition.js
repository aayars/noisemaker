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
        min: 0,
        max: 1,
        step: 0.05,
        ui: {
            label: "Alpha",
            control: "slider"
        }
    }
};

  passes = [
    {
      name: "decay_grid",
      type: "render",
      program: "init_from_prev",
      inputs: {
        gridTex: "global_grid_state"
      },
      outputs: {
        outGrid: "global_grid_state"
      }
    },
    {
      name: "simulate_agents",
      type: "render",
      program: "agent_walk",
      inputs: {
        agentTex: "global_agent_state",
        gridTex: "global_grid_state"
      },
      outputs: {
        outAgents: "global_agent_state"
      }
    },
    {
      name: "deposit_agents",
      type: "render",
      program: "save_cluster",
      drawMode: "points",
      count: "auto",
      blend: ["ONE", "ONE"],
      programSpec: {
        vertex: `#version 300 es
        precision highp float;
        uniform sampler2D agentTex;
        out float v_weight;

        ivec2 decodeIndex(int index, ivec2 dims) {
            int x = index % dims.x;
            int y = index / dims.x;
            return ivec2(x, y);
        }

        void main() {
            ivec2 dims = textureSize(agentTex, 0);
            ivec2 coord = decodeIndex(gl_VertexID, dims);
            vec2 uv = (vec2(coord) + 0.5) / vec2(dims);
            vec4 state = texture(agentTex, uv);
            float weight = clamp(state.w, 0.0, 1.0);
            v_weight = weight;
            if (weight < 0.5) {
                gl_Position = vec4(-2.0, -2.0, 0.0, 1.0);
                gl_PointSize = 1.0;
                return;
            }

            vec2 clip = state.xy * 2.0 - 1.0;
            gl_Position = vec4(clip, 0.0, 1.0);
            gl_PointSize = 4.5;
        }`,
        fragment: `#version 300 es
        precision highp float;
        in float v_weight;
        layout(location = 0) out vec4 dlaOutColor;
        uniform float alpha;

        float falloff(vec2 coord) {
          vec2 centered = coord * 2.0 - 1.0;
          float d = dot(centered, centered);
          return clamp(1.0 - d, 0.0, 1.0);
        }

        void main() {
          if (v_weight < 0.5) {
            discard;
          }
          float shape = falloff(gl_PointCoord);
          float energy = v_weight * shape * clamp(alpha + 0.1, 0.0, 1.2);
          vec3 tint = vec3(1.0, 0.25, 0.9);
          dlaOutColor = vec4(tint * energy, energy);
        }`
      },
      inputs: {
        agentTex: "global_agent_state"
      },
      outputs: {
        outGrid: "global_grid_state"
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
        outputBuffer: "outputColor"
      }
    }
  ];
}
