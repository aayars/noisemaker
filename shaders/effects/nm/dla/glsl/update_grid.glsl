#version 300 es
precision highp float;

uniform sampler2D agentTex;
uniform sampler2D gridTex;
uniform int frame;
uniform vec2 resolution;

out vec4 fragColor;

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5) / resolution;
    vec4 currentGrid = texture(gridTex, uv);
    float val = currentGrid.r;

    if (frame == 0) {
        // Initialize seeds
        // Center seed
        vec2 center = vec2(0.5);
        // Use aspect ratio to make it a circle
        float aspect = resolution.x / resolution.y;
        vec2 p = uv;
        p.x *= aspect;
        center.x *= aspect;
        
        if (distance(p, center) < 0.01) {
            val = 1.0;
        } else {
            val = 0.0;
        }
    } else {
        // Gather from agents
        // Loop over 32x32 agents
        for (int y = 0; y < 32; y++) {
            for (int x = 0; x < 32; x++) {
                vec4 agent = texelFetch(agentTex, ivec2(x, y), 0);
                vec2 agentPos = agent.xy;
                float status = agent.z;
                
                if (status > 0.5) {
                    // Agent is stuck. Check if it's at this pixel.
                    // Distance check in pixels
                    vec2 pixelPos = uv * resolution;
                    vec2 agentPixelPos = agentPos * resolution;
                    
                    if (distance(pixelPos, agentPixelPos) < 1.5) {
                        val = 1.0;
                    }
                }
            }
        }
    }

    fragColor = vec4(val, val, val, 1.0);
}
