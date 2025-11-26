#version 300 es

precision highp float;
precision highp int;

// Ridge effect.
// Implements the ridge transform from noisemaker/value.py: 1 - abs(n * 2 - 1).


const uint CHANNEL_COUNT = 4u;
const float RIDGE_SCALE = 2.0;
const float RIDGE_OFFSET = 1.0;

uniform sampler2D inputTex;
uniform float width;
uniform float height;
uniform float channels;
uniform float time;
uniform float speed;

uint as_u32(float value) {
    return uint(max(round(value), 0.0));
}

vec4 ridge_transform(vec4 value) {
    vec4 scaled = value * RIDGE_SCALE - vec4(RIDGE_OFFSET);
    vec4 result = vec4(1.0) - abs(scaled);
    return clamp(result, vec4(0.0), vec4(1.0));
}


out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    // Derive dimensions from the bound input texture to avoid relying on uniforms
    uvec2 dims = uvec2(textureSize(inputTex, 0));
    uint width = dims.x;
    uint height = dims.y;
    if (global_id.x >= width || global_id.y >= height) {
        return;
    }

    vec2 coords = vec2(int(global_id.x), int(global_id.y));
    vec4 texel = texture(inputTex, (vec2(coords) + vec2(0.5)) / vec2(textureSize(inputTex, 0)));
    
    // Apply ridge transform
    vec4 ridged = ridge_transform(texel);
    vec4 out_color = vec4(ridged.xyz, 1.0);
    
    fragColor = out_color;
}