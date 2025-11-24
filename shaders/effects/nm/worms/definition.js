import { Effect } from '../../../src/runtime/effect.js';

/**
 * Worms
 * /shaders/effects/worms/worms.wgsl
 */
export default class Worms extends Effect {
  name = "Worms";
  namespace = "nm";
  func = "worms";

  globals = {
    behavior: {
        type: "integer",
        default: 1,
        min: 1,
        max: 10,
        step: 1,
        ui: {
            label: "Behavior",
            control: "slider"
        }
    },
    density: {
        type: "integer",
        default: 20,
        min: 1,
        max: 100,
        step: 1,
        ui: {
            label: "Density",
            control: "slider"
        }
    },
    stride: {
        type: "integer",
        default: 10,
        min: 1,
        max: 100,
        step: 1,
        ui: {
            label: "Stride",
            control: "slider"
        }
    },
    kink: {
        type: "float",
        default: 1,
        min: 0,
        max: 10,
        step: 0.1,
        ui: {
            label: "Kink",
            control: "slider"
        }
    },
    strideDeviation: {
        type: "float",
        default: 0.05,
        min: 0,
        max: 0.5,
        step: 0.01,
        ui: {
            label: "Stride Deviation",
            control: "slider"
        }
    },
    quantize: {
        type: "boolean",
        default: false,
        ui: {
            label: "Quantize",
            control: "checkbox"
        }
    },
    intensity: {
        type: "float",
        default: 90,
        min: 0,
        max: 100,
        step: 1,
        ui: {
            label: "Trail Intensity",
            control: "slider"
        }
    },
    inputIntensity: {
        type: "float",
        default: 100,
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
        trailTex: "global_trail_state"
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
      count: 128, // MAX_WORMS
      programSpec: {
        vertex: `#version 300 es
        precision highp float;
        uniform sampler2D agentTex;
        uniform sampler2D inputTex;
        uniform vec2 resolution;
        
        out vec4 v_color;
        
        void main() {
            int id = gl_VertexID;
            int width = int(resolution.x);
            
            int x = id % width;
            int y = id / width;
            
            vec4 agent = texelFetch(agentTex, ivec2(x, y), 0);
            vec2 pos = agent.xy;
            
            v_color = texture(inputTex, pos);
            
            gl_Position = vec4(pos * 2.0 - 1.0, 0.0, 1.0);
            gl_PointSize = 2.0;
        }`,
        fragment: `#version 300 es
        precision highp float;
        in vec4 v_color;
        out vec4 fragColor;
        void main() {
            fragColor = v_color;
        }`
      },
      inputs: {
        agentTex: "global_agent_state",
        inputTex: "inputTex"
      },
      outputs: {
        outTrails: "global_trail_state"
      }
    },
    {
      name: "render",
      type: "render",
      program: "render",
      inputs: {
        trailTex: "global_trail_state",
        inputTex: "inputTex"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
