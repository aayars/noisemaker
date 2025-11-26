import { Effect } from '../../../src/runtime/effect.js';

export default class Worms extends Effect {
  name = "Worms";
  namespace = "nd";
  func = "worms_nd";

  globals = {
    channelCount: {
      type: "float",
      default: 4,
      uniform: "channelCount",
      ui: {
        label: "channels",
        control: "slider"
      }
    },
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
        label: "behavior",
        control: "dropdown"
      }
    },
    density: {
      type: "int",
      default: 20,
      uniform: "density",
      min: 1,
      max: 100,
      step: 1,
      ui: {
        label: "density",
        control: "slider"
      }
    },
    stride: {
      type: "int",
      default: 1,
      uniform: "stride",
      min: 1,
      max: 100,
      step: 1,
      ui: {
        label: "stride",
        control: "slider"
      }
    },
    padding1: {
      type: "float",
      default: 0,
      ui: {
        label: "padding behavior stride",
        control: "slider"
      }
    },
    strideDeviation: {
      type: "float",
      default: 0.05,
      uniform: "strideDeviation",
      ui: {
        label: "stride deviation",
        control: "slider"
      }
    },
    padding_alpha: {
      type: "float",
      default: 1.0,
      ui: {
        label: "padding alpha",
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
        label: "kink",
        control: "slider"
      }
    },
    quantize: {
      type: "boolean",
      default: false,
      uniform: "quantize",
      ui: {
        label: "quantize",
        control: "checkbox"
      }
    },
    padding_speed: {
      type: "float",
      default: 0,
      ui: {
        label: "padding speed",
        control: "slider"
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
        label: "intensity",
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
        label: "input intensity",
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
        label: "lifetime",
        control: "slider"
      }
    },
    resetState: {
      type: "button",
      default: false,
      uniform: "resetState",
      ui: { label: "state" }
    }
  };

  passes = [
    {
      name: "update_agents",
      type: "render",
      program: "worms-agent",
      inputs: {
        agentTex: "global_worms_agent_state",
        inputTex: "inputTex"
      },
      outputs: {
        agentOut: "global_worms_agent_state"
      }
    },
    {
      name: "fade_trails",
      type: "render",
      program: "worms-fade",
      inputs: {
        trailTex: "global_worms_trail_state",
        inputTex: "inputTex"
      },
      outputs: {
        outTrails: "global_worms_trail_state"
      }
    },
    {
      name: "draw_agents",
      type: "render",
      program: "worms-draw",
      drawMode: "points",
      blend: true,
      count: 262144,
      programSpec: {
        vertex: `#version 300 es
        precision highp float;
        uniform sampler2D agentTex;
        uniform sampler2D inputTex;
        uniform vec2 resolution;
        
        out vec4 v_color;
        
        void main() {
            int id = gl_VertexID;
            ivec2 texSize = textureSize(agentTex, 0);
            int width = texSize.x;
            int height = texSize.y;
            
            int x = id % width;
            int y = id / width;
            
            if (y >= height) {
                gl_Position = vec4(-2.0, -2.0, 0.0, 1.0);
                v_color = vec4(0.0);
                return;
            }
            
            // Agent format: [pos.x, pos.y, heading_norm, age_norm]
            vec4 agent = texelFetch(agentTex, ivec2(x, y), 0);
            vec2 pos = agent.xy; // normalized 0-1
            
            // Use a subtle gray trail color (like erosion_worms)
            vec3 trailColor = vec3(0.1, 0.1, 0.1);
            
            // Map 0..1 to clip space -1..1
            vec2 clipPos = pos * 2.0 - 1.0;
            
            gl_Position = vec4(clipPos, 0.0, 1.0);
            gl_PointSize = 1.0;
            v_color = vec4(trailColor, 1.0);
        }`,
        fragment: `#version 300 es
        precision highp float;
        in vec4 v_color;
        out vec4 fragColor;
        void main() {
            fragColor = v_color;
        }`,
        vertexWgsl: `
        struct VertexOutput {
            @builtin(position) position: vec4<f32>,
            @location(0) color: vec4<f32>,
        }
        
        @group(0) @binding(0) var agentTex: texture_2d<f32>;
        @group(0) @binding(1) var inputTex: texture_2d<f32>;
        @group(0) @binding(2) var inputSampler: sampler;
        
        @vertex
        fn vs_main(@builtin(vertex_index) vertexIndex: u32) -> VertexOutput {
            var output: VertexOutput;
            
            let texSize = textureDimensions(agentTex, 0);
            let width = i32(texSize.x);
            let height = i32(texSize.y);
            
            let id = i32(vertexIndex);
            let x = id % width;
            let y = id / width;
            
            if (y >= height) {
                output.position = vec4<f32>(-2.0, -2.0, 0.0, 1.0);
                output.color = vec4<f32>(0.0);
                return output;
            }
            
            // Agent format: [pos.x, pos.y, heading_norm, age_norm]
            let agent = textureLoad(agentTex, vec2<i32>(x, y), 0);
            let pos = agent.xy; // normalized 0-1
            
            // Sample color from input texture at agent position
            let inputColor = textureSampleLevel(inputTex, inputSampler, pos, 0.0);
            
            // Use subtle gray for trails (matching GLSL version)
            let trailColor = vec3<f32>(0.1, 0.1, 0.1);
            
            // Map 0..1 to clip space -1..1
            let clipPos = pos * 2.0 - 1.0;
            
            output.position = vec4<f32>(clipPos, 0.0, 1.0);
            output.color = vec4<f32>(trailColor, 1.0);
            return output;
        }`,
        wgsl: `
        struct FragmentInput {
            @builtin(position) position: vec4<f32>,
            @location(0) color: vec4<f32>,
        }
        
        @fragment
        fn main(input: FragmentInput) -> @location(0) vec4<f32> {
            return input.color;
        }`
      },
      inputs: {
        agentTex: "global_worms_agent_state",
        inputTex: "inputTex"
      },
      outputs: {
        outTrails: "global_worms_trail_state"
      }
    },
    {
      name: "render",
      type: "render",
      program: "worms",
      inputs: {
        mixerTex: "inputTex",
        wormsTex: "global_worms_trail_state"
      },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
