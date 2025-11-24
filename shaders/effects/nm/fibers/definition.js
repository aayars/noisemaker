import { Effect } from '../../../src/runtime/effect.js';

/**
 * Fibers
 * /shaders/effects/fibers/fibers.wgsl
 */
export default class Fibers extends Effect {
  name = "Fibers";
  namespace = "nm";
  func = "fibers";

  globals = {
    speed: {
      type: "float",
      default: 1.0,
      min: 0.0,
      max: 5.0,
      step: 0.1,
      ui: { label: "Speed", control: "slider" }
    },
    seed: {
      type: "float",
      default: 0.0,
      min: 0.0,
      max: 100.0,
      step: 1.0,
      ui: { label: "Seed", control: "slider" }
    },
    mask_scale: {
      type: "float",
      default: 1.0,
      min: 0.1,
      max: 5.0,
      step: 0.1,
      ui: { label: "Mask Scale", control: "slider" }
    },
    // Worm params
    density: {
        type: "float",
        default: 5,
        min: 1,
        max: 100,
        step: 1,
        ui: { label: "Density", control: "slider" }
    },
    stride: {
        type: "float",
        default: 1,
        min: 0.1,
        max: 10,
        step: 0.1,
        ui: { label: "Stride", control: "slider" }
    },
    worm_lifetime: {
        type: "float",
        default: 30,
        min: 0,
        max: 60,
        step: 1,
        ui: { label: "Lifetime", control: "slider" }
    }
  };

  passes = [
    {
      name: "update_agents",
      type: "render",
      program: "update_agents",
      inputs: {
        agentTex: "global_agent_state",
        inputTex: "inputTex"
      },
      outputs: {
        outAgents: "global_agent_state"
      }
    },
    {
      name: "fade_trails",
      type: "render",
      program: "fade_trails",
      inputs: {
        trailTex: "global_trail_state",
        inputTex: "inputTex"
      },
      outputs: {
        outTrails: "global_trail_state"
      }
    },
    {
      name: "draw_agents",
      type: "render",
      program: "draw_agents",
      drawMode: "points",
      blend: true,
      count: 262144, // 512x512 agents
      programSpec: {
        vertex: `#version 300 es
        precision highp float;
        uniform sampler2D agentTex;
        uniform vec2 resolution;
        
        void main() {
            int id = gl_VertexID;
            int width = int(resolution.x);
            int height = int(resolution.y);
            
            int x = id % width;
            int y = id / width;
            
            if (y >= height) {
                gl_Position = vec4(-2.0, -2.0, 0.0, 1.0);
                return;
            }
            
            vec4 agent = texelFetch(agentTex, ivec2(x, y), 0);
            vec2 pos = agent.xy;
            
            gl_Position = vec4(pos * 2.0 - 1.0, 0.0, 1.0);
            gl_PointSize = 1.0;
        }`,
        fragment: `#version 300 es
        precision highp float;
        out vec4 fragColor;
        void main() {
            fragColor = vec4(0.1, 0.1, 0.1, 1.0);
        }`
      },
      inputs: {
        agentTex: "global_agent_state"
      },
      outputs: {
        outTrails: "global_trail_state"
      }
    },
    {
      name: "render",
      type: "render",
      program: "fibers",
      inputs: {
        input_texture: "inputTex",
        worm_texture: "global_trail_state"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
