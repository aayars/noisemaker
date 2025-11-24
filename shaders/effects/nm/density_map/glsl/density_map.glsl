#version 300 es
precision highp float;
precision highp int;

uniform sampler2D input_texture;
uniform sampler2D minmax_texture;
uniform vec4 size;
uniform vec4 controls;

out vec4 fragColor;

float clamp01(float value) {
    return clamp(value, 0.0, 1.0);
}

void main() {
    ivec2 coord = ivec2(gl_FragCoord.xy);
    vec4 original = texelFetch(input_texture, coord, 0);
    
    vec4 minmax = texelFetch(minmax_texture, ivec2(0, 0), 0);
    float min_val = minmax.x;
    float max_val = minmax.y;
    
    float delta = max_val - min_val;
    vec4 normalized = original;
    
    if (delta > 0.0) {
        normalized = (original - min_val) / delta;
    } else {
        normalized = clamp(original, 0.0, 1.0);
    }
    
    // Density map usually implies more than just normalization, 
    // but without atomics for histogram, we fallback to min/max normalization.
    
    fragColor = vec4(clamp01(normalized.r), clamp01(normalized.g), clamp01(normalized.b), original.a);
}
