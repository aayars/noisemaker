#version 300 es
precision highp float;

uniform sampler2D agentTex;
uniform sampler2D gridTex;
uniform float time;
uniform int frame;
uniform vec2 resolution;

out vec4 fragColor;

// Random functions
float hash12(vec2 p) {
	vec3 p3  = fract(vec3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void main() {
    // Only process first 32x32 pixels
    ivec2 coord = ivec2(gl_FragCoord.xy);
    if (coord.x >= 32 || coord.y >= 32) {
        fragColor = vec4(0.0);
        return;
    }

    vec2 agentDims = vec2(textureSize(agentTex, 0));
    vec2 uv = (gl_FragCoord.xy - 0.5) / agentDims;
    vec4 agent = texture(agentTex, uv);
    vec2 pos = agent.xy;
    float status = agent.z; // 0 = moving, 1 = stuck
    float seed = agent.w;

    if (frame == 0) {
        // Initialize
        seed = hash12(uv * 100.0 + vec2(time));
        pos = vec2(hash12(vec2(seed, 1.0)), hash12(vec2(seed, 2.0)));
        status = 0.0;
    } else {
        // Update
        if (status > 0.5) {
            // Respawn
            seed = hash12(vec2(seed, time));
            pos = vec2(hash12(vec2(seed, 1.0)), hash12(vec2(seed, 2.0)));
            status = 0.0;
        } else {
            // Move
            float angle = hash12(vec2(seed, time)) * 6.283185;
            float speed = 2.0 / max(resolution.x, resolution.y); // Speed
            vec2 dir = vec2(cos(angle), sin(angle));
            vec2 nextPos = pos + dir * speed;
            
            // Wrap
            nextPos = fract(nextPos);

            // Check grid
            float gridVal = texture(gridTex, nextPos).r;
            if (gridVal > 0.1) {
                status = 1.0;
                // Keep position to stick
            } else {
                pos = nextPos;
            }
        }
    }

    fragColor = vec4(pos, status, seed);
}
