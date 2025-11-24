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
uniform float kink;
uniform float worm_lifetime;
uniform bool quantize;

out vec4 fragColor;

const float TAU = 6.28318530717958647692;

// Helper functions
float oklab_l(vec3 rgb) {
    // Simplified luma for now
    return dot(rgb, vec3(0.299, 0.587, 0.114));
}

float value_map_component(vec4 texel) {
    return oklab_l(texel.rgb);
}

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
    float angle = agent.z;
    float wstride = agent.w;
    
    if (frame == 0) {
        // Initialize
        float seed = hash12(uv * 100.0 + vec2(time));
        pos = vec2(hash12(vec2(seed, 1.0)), hash12(vec2(seed, 2.0)));
        angle = hash12(vec2(seed, 3.0)) * TAU;
        wstride = stride / max(resolution.x, resolution.y); // Normalize stride
    } else {
        // Move
        vec4 texel = texture(inputTex, pos);
        float v = value_map_component(texel);
        // Assume 0..1 range for v
        float norm = clamp(v, 0.0, 1.0);
        
        float new_angle = norm * TAU * kink + angle;
        if (quantize) {
            new_angle = round(new_angle);
        }
        
        float stride_norm = stride / max(resolution.x, resolution.y);
        
        pos.x += sin(new_angle) * stride_norm;
        pos.y += cos(new_angle) * stride_norm;
        
        pos = fract(pos); // Wrap
        angle = new_angle;
    }
    
    fragColor = vec4(pos, angle, wstride);
}
