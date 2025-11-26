#version 300 es

precision highp float;
precision highp int;

uniform vec2 resolution;
uniform sampler2D agentTex;
uniform sampler2D inputTex;
uniform float stride;
uniform float kink;
uniform float quantize;
uniform float time;
uniform float behavior;
uniform float lifetime;
uniform int frame;

layout(location = 0) out vec4 agentOut;

const float TAU = 6.283185307179586;
const float PI = 3.14159265359;

float hash21(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}

float rand(inout float seed) {
    seed = fract(seed * 43758.5453123 + 0.2137);
    return seed;
}

vec2 wrap01(vec2 value) {
    return fract(value);
}

vec2 spawnPosition(vec2 coord, inout float seed) {
    float rx = rand(seed);
    float ry = rand(seed);
    return vec2(rx, ry);
}

float spawnHeading(vec2 coord, float seed) {
    return hash21(coord + seed * 13.1) * TAU - PI;
}

float srgb_to_linear(float value) {
    if (value <= 0.04045) {
        return value / 12.92;
    }
    return pow((value + 0.055) / 1.055, 2.4);
}

float cube_root(float value) {
    if (value == 0.0) {
        return 0.0;
    }
    float sign_value = value >= 0.0 ? 1.0 : -1.0;
    return sign_value * pow(abs(value), 1.0 / 3.0);
}

float oklab_l(vec3 rgb) {
    float r_lin = srgb_to_linear(clamp(rgb.x, 0.0, 1.0));
    float g_lin = srgb_to_linear(clamp(rgb.y, 0.0, 1.0));
    float b_lin = srgb_to_linear(clamp(rgb.z, 0.0, 1.0));

    float l = 0.4121656120 * r_lin + 0.5362752080 * g_lin + 0.0514575653 * b_lin;
    float m = 0.2118591070 * r_lin + 0.6807189584 * g_lin + 0.1074065790 * b_lin;
    float s = 0.0883097947 * r_lin + 0.2818474174 * g_lin + 0.6302613616 * b_lin;

    float l_c = cube_root(l);
    float m_c = cube_root(m);
    float s_c = cube_root(s);

    return 0.2104542553 * l_c + 0.7936177850 * m_c - 0.0040720468 * s_c;
}

void main() {
    ivec2 dims = textureSize(agentTex, 0);
    vec2 uv = (gl_FragCoord.xy - 0.5) / vec2(dims);

    // Agent format: [pos.x, pos.y, heading_norm, age_norm]
    vec4 state = texture(agentTex, uv);
    vec2 pos = state.xy;          // normalized 0-1
    float headingNorm = state.z;  // normalized heading
    float ageNorm = state.w;      // normalized age

    float heading = headingNorm * TAU - PI;
    float maxLifetime = max(lifetime, 1.0);
    float age = ageNorm * maxLifetime;

    float noiseSeed = hash21(uv + float(frame) * 0.013 + time * 0.11);

    // Initial spawn on first frame or uninitialized agent
    if (frame <= 1 || pos == vec2(0.0)) {
        pos = spawnPosition(uv, noiseSeed);
        heading = spawnHeading(uv, noiseSeed);
        age = 0.0;
    }

    // Respawn when lifetime exceeded
    if (age > maxLifetime) {
        pos = spawnPosition(uv + 0.17, noiseSeed);
        heading = spawnHeading(uv + 0.53, noiseSeed);
        age = 0.0;
    }

    // Sample input texture at agent position
    vec4 texel_here = texture(inputTex, pos);
    float index_value = oklab_l(texel_here.rgb);

    int behavior_mode = int(floor(behavior + 0.5));
    float rotation_bias;

    if (behavior_mode <= 0) {
        // No behavior - pure index-driven
        rotation_bias = 0.0;
    } else if (behavior_mode == 10) {
        // Meandering - oscillate based on time
        float phase = fract(headingNorm);
        rotation_bias = sin((time - phase) * TAU) * 0.5 + 0.5;
        rotation_bias = rotation_bias * TAU - PI;
    } else {
        // Obedient and others - maintain heading bias
        rotation_bias = heading;
    }

    float final_angle = index_value * TAU * kink + rotation_bias;

    if (quantize > 0.5) {
        final_angle = round(final_angle / (PI * 0.25)) * (PI * 0.25);
    }

    // Update position (normalized)
    float speedPixels = max(stride, 0.1);
    float step = speedPixels / max(resolution.x, resolution.y);
    vec2 dir = vec2(cos(final_angle), sin(final_angle));
    pos = wrap01(pos + dir * step);

    age += 1.0;

    // Pack output
    float headingOut = fract((heading + PI) / TAU);
    float ageOut = clamp(age / maxLifetime, 0.0, 1.0);
    agentOut = vec4(pos, headingOut, ageOut);
}
