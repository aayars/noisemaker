#version 300 es
precision highp float;

uniform sampler2D agentTex;
uniform sampler2D inputTex;
uniform float time;
uniform int frame;
uniform vec2 resolution;

// Params
uniform float density;
uniform float stride;
uniform float wormLifetime;

out vec4 fragColor;

// Random functions
float hash12(vec2 p) {
	vec3 p3  = fract(vec3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void main() {
    vec2 agentDims = vec2(textureSize(agentTex, 0));
    vec2 uv = (gl_FragCoord.xy - 0.5) / agentDims;
    vec4 agent = texture(agentTex, uv);
    vec2 pos = agent.xy;
    vec2 dir = agent.zw; // Direction
    
    if (frame == 0) {
        // Initialize
        float seed = hash12(uv * 100.0 + vec2(time));
        pos = vec2(hash12(vec2(seed, 1.0)), hash12(vec2(seed, 2.0)));
        float angle = hash12(vec2(seed, 3.0)) * 6.283185;
        dir = vec2(cos(angle), sin(angle));
    } else {
        // Move
        // Sample gradient from inputTex
        // Simple gradient estimation
        vec2 texel = 1.0 / resolution;
        float l = texture(inputTex, pos).r; // Luminance
        float lx = texture(inputTex, pos + vec2(texel.x, 0.0)).r;
        float ly = texture(inputTex, pos + vec2(0.0, texel.y)).r;
        vec2 grad = vec2(lx - l, ly - l);
        
        // Rotate direction based on gradient?
        // Or just move?
        // Erosion worms usually turn towards gradient or away?
        // Let's just move straight for now + some noise
        
        float angle = atan(dir.y, dir.x);
        // Add some noise
        float noise = hash12(pos * 100.0 + vec2(time)) - 0.5;
        angle += noise * 0.5;
        
        // Turn based on gradient
        // angle += grad.x * 10.0; // Simple steering
        
        dir = vec2(cos(angle), sin(angle));
        
        float speed = stride / max(resolution.x, resolution.y);
        pos += dir * speed;
        
        // Wrap
        pos = fract(pos);
    }

    fragColor = vec4(pos, dir);
}
