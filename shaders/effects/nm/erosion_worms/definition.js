import { Effect } from '../../../src/runtime/effect.js';

/**
 * Erosion Worms
 * /shaders/effects/erosion_worms/erosion_worms.wgsl
 */
export default class ErosionWorms extends Effect {
  name = "ErosionWorms";
  namespace = "nm";
  func = "erosionworms";

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
        default: 100,
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

  // TODO: Define passes based on shader requirements
  // This effect was originally implemented as a WebGPU compute shader.
  // A render pass implementation needs to be created for GLSL/WebGL2 compatibility.
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
      blend: true, // Additive default
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
            
            // Map ID to texture coordinate
            // Assuming agentTex is same size as resolution
            int x = id % width;
            int y = id / width;
            
            if (y >= height) {
                gl_Position = vec4(-2.0, -2.0, 0.0, 1.0); // Discard
                return;
            }
            
            vec4 agent = texelFetch(agentTex, ivec2(x, y), 0);
            vec2 pos = agent.xy;
            
            // Map 0..1 to -1..1
            gl_Position = vec4(pos * 2.0 - 1.0, 0.0, 1.0);
            gl_PointSize = 1.0;
        }`,
        fragment: `#version 300 es
        precision highp float;
        out vec4 fragColor;
        void main() {
            fragColor = vec4(0.1, 0.1, 0.1, 1.0); // Trail intensity
        }`,
        vertexWgsl: `
        struct VertexOutput {
            @builtin(position) position: vec4<f32>,
            @location(0) color: vec4<f32>,
        }
        
        @group(0) @binding(0) var agentTex: texture_2d<f32>;
        
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
            
            // Use subtle gray for trails
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
        agentTex: "global_agent_state"
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
        outputBuffer: "outputColor"
      }
    }
  ];
}
