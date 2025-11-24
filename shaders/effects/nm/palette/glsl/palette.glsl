#version 300 es
precision highp float;

uniform sampler2D inputTex;
uniform float time;
uniform int palette_index;
uniform float alpha;

out vec4 fragColor;

struct PaletteEntry {
    vec4 amp;
    vec4 freq;
    vec4 offset;
    vec4 phase;
};

const int PALETTE_COUNT = 38;
const PaletteEntry PALETTES[PALETTE_COUNT] = PaletteEntry[PALETTE_COUNT](

    PaletteEntry(
        vec4(0.76, 0.88, 0.37, 0.0),
        vec4(1.0, 1.0, 1.0, 0.0),
        vec4(0.93, 0.97, 0.52, 0.0),
        vec4(0.21, 0.41, 0.56, 0.0)
    ),
    PaletteEntry(
        vec4(0.5, 0.5, 0.5, 0.0),
        vec4(1.0, 1.0, 1.0, 0.0),
        vec4(0.5, 0.5, 0.5, 0.0),
        vec4(0.0, 0.1, 0.2, 0.0)
    ),
    PaletteEntry(
        vec4(0.5, 0.5, 0.5, 0.0),
        vec4(1.0, 1.0, 1.0, 0.0),
        vec4(0.2, 0.64, 0.62, 0.0),
        vec4(0.15, 0.2, 0.3, 0.0)
    ),
    PaletteEntry(
        vec4(0.1, 0.9, 0.7, 0.0),
        vec4(1.0, 1.0, 1.0, 0.0),
        vec4(0.0, 0.3, 0.0, 0.0),
        vec4(0.6, 0.1, 0.6, 0.0)
    ),
    PaletteEntry(
        vec4(0.5, 0.5, 0.5, 0.0),
        vec4(0.5, 1.0, 0.5, 0.0),
        vec4(0.5, 0.5, 0.5, 0.0),
        vec4(0.5, 0.0, 1.0, 0.0)
    ),
    PaletteEntry(
        vec4(0.5, 0.5, 0.5, 0.0),
        vec4(1.0, 1.0, 1.0, 0.0),
        vec4(0.83, 0.6, 0.63, 0.0),
        vec4(0.3, 0.1, 0.0, 0.0)
    ),
    PaletteEntry(
        vec4(0.5, 0.5, 0.5, 0.0),
        vec4(1.0, 1.0, 1.0, 0.0),
        vec4(0.28, 0.39, 0.07, 0.0),
        vec4(0.25, 0.2, 0.1, 0.0)
    ),
    PaletteEntry(
        vec4(0.0, 0.5, 0.5, 0.0),
        vec4(0.0, 1.0, 1.0, 0.0),
        vec4(0.0, 0.5, 0.5, 0.0),
        vec4(0.0, 0.5, 0.5, 0.0)
    ),
    PaletteEntry(
        vec4(0.5, 0.5, 0.5, 0.0),
        vec4(1.0, 1.0, 1.0, 0.0),
        vec4(0.5, 0.5, 0.5, 0.0),
        vec4(0.3, 0.2, 0.2, 0.0)
    ),
    PaletteEntry(
        vec4(0.5, 0.5, 0.5, 0.0),
        vec4(1.0, 1.0, 1.0, 0.0),
        vec4(0.1, 0.4, 0.7, 0.0),
        vec4(0.1, 0.1, 0.1, 0.0)
    ),
    PaletteEntry(
        vec4(0.5, 0.5, 0.5, 0.0),
        vec4(1.0, 1.0, 1.0, 0.0),
        vec4(0.41, 0.22, 0.67, 0.0),
        vec4(0.2, 0.25, 0.2, 0.0)
    ),
    PaletteEntry(
        vec4(0.83, 0.45, 0.19, 0.0),
        vec4(1.0, 1.0, 1.0, 0.0),
        vec4(0.79, 0.45, 0.35, 0.0),
        vec4(0.28, 0.91, 0.61, 0.0)
    ),
    PaletteEntry(
        vec4(0.5, 0.5, 0.5, 0.0),
        vec4(2.0, 2.0, 2.0, 0.0),
        vec4(0.5, 0.5, 0.5, 0.0),
        vec4(1.0, 1.0, 1.0, 0.0)
    ),
    PaletteEntry(
        vec4(0.5, 0.5, 0.5, 0.0),
        vec4(1.0, 1.0, 1.0, 0.0),
        vec4(0.22, 0.48, 0.62, 0.0),
        vec4(0.1, 0.3, 0.2, 0.0)
    ),
    PaletteEntry(
        vec4(0.65, 0.4, 0.11, 0.0),
        vec4(1.0, 1.0, 1.0, 0.0),
        vec4(0.72, 0.45, 0.08, 0.0),
        vec4(0.71, 0.8, 0.84, 0.0)
    ),
    PaletteEntry(
        vec4(0.5, 0.5, 0.5, 0.0),
        vec4(1.0, 1.0, 1.0, 0.0),
        vec4(0.5, 0.5, 0.5, 0.0),
        vec4(0.27, 0.01, 0.48, 0.0)
    ),
    PaletteEntry(
        vec4(0.568, 0.774, 0.234, 0.0),
        vec4(1.0, 1.0, 1.0, 0.0),
        vec4(0.5, 0.5, 0.5, 0.0),
        vec4(0.727, 0.08, 0.104, 0.0)
    ),
    PaletteEntry(
        vec4(0.5, 0.5, 0.5, 0.0),
        vec4(1.0, 1.0, 1.0, 0.0),
        vec4(0.5, 0.5, 1.0, 0.0),
        vec4(0.0, 0.2, 0.2, 0.0)
    ),
    PaletteEntry(
        vec4(0.51, 0.39, 0.41, 0.0),
        vec4(1.0, 1.0, 1.0, 0.0),
        vec4(0.59, 0.53, 0.94, 0.0),
        vec4(0.15, 0.41, 0.46, 0.0)
    ),
    PaletteEntry(
        vec4(0.5, 0.5, 0.5, 0.0),
        vec4(1.0, 1.0, 1.0, 0.0),
        vec4(0.64, 0.12, 0.84, 0.0),
        vec4(0.1, 0.25, 0.15, 0.0)
    ),
    PaletteEntry(
        vec4(0.5, 0.5, 0.5, 0.0),
        vec4(1.0, 1.0, 1.0, 0.0),
        vec4(0.5, 0.5, 0.5, 0.0),
        vec4(0.0, 0.33, 0.67, 0.0)
    ),
    PaletteEntry(
        vec4(0.5, 0.5, 0.5, 0.0),
        vec4(1.0, 1.0, 1.0, 0.0),
        vec4(0.5, 0.5, 0.5, 0.0),
        vec4(0.25, 0.5, 0.75, 0.0)
    ),
    PaletteEntry(
        vec4(0.758, 0.628, 0.222, 0.0),
        vec4(1.0, 1.0, 1.0, 0.0),
        vec4(0.355, 0.129, 0.17, 0.0),
        vec4(0.0, 0.25, 0.5, 0.0)
    ),
    PaletteEntry(
        vec4(1.0, 0.25, 0.5, 0.0),
        vec4(1.0, 1.0, 1.0, 0.0),
        vec4(0.0, 0.0, 0.25, 0.0),
        vec4(0.5, 0.0, 0.0, 0.0)
    ),
    PaletteEntry(
        vec4(0.5, 0.5, 0.5, 0.0),
        vec4(1.0, 1.0, 1.0, 0.0),
        vec4(0.5, 0.5, 0.5, 0.0),
        vec4(0.3, 0.1, 0.1, 0.0)
    ),
    PaletteEntry(
        vec4(0.2, 0.2, 0.1, 0.0),
        vec4(1.0, 1.0, 1.0, 0.0),
        vec4(0.7, 0.2, 0.2, 0.0),
        vec4(0.5, 0.4, 0.0, 0.0)
    ),
    PaletteEntry(
        vec4(0.605, 0.175, 0.171, 0.0),
        vec4(1.0, 1.0, 1.0, 0.0),
        vec4(0.522, 0.386, 0.36, 0.0),
        vec4(0.0, 0.25, 0.5, 0.0)
    ),
    PaletteEntry(
        vec4(0.605, 0.175, 0.171, 0.0),
        vec4(2.0, 2.0, 2.0, 0.0),
        vec4(0.522, 0.386, 0.36, 0.0),
        vec4(0.0, 0.25, 0.5, 0.0)
    ),
    PaletteEntry(
        vec4(0.5, 0.5, 0.5, 0.0),
        vec4(1.0, 1.0, 1.0, 0.0),
        vec4(0.5, 0.5, 0.5, 0.0),
        vec4(0.4, 0.2, 0.0, 0.0)
    ),
    PaletteEntry(
        vec4(0.5, 0.5, 0.5, 0.0),
        vec4(1.0, 1.0, 1.0, 0.0),
        vec4(0.5, 0.5, 0.5, 0.0),
        vec4(0.0, 0.2, 0.25, 0.0)
    ),
    PaletteEntry(
        vec4(0.5, 0.5, 0.5, 0.0),
        vec4(1.0, 1.0, 1.0, 0.0),
        vec4(0.5, 0.5, 0.5, 0.0),
        vec4(0.0, 0.2, 0.4, 0.0)
    ),
    PaletteEntry(
        vec4(0.5, 0.5, 0.5, 0.0),
        vec4(2.0, 2.0, 2.0, 0.0),
        vec4(0.5, 0.5, 0.5, 0.0),
        vec4(0.0, 0.2, 0.4, 0.0)
    ),
    PaletteEntry(
        vec4(0.5, 0.5, 0.5, 0.0),
        vec4(1.0, 1.0, 1.0, 0.0),
        vec4(0.6, 0.4, 0.1, 0.0),
        vec4(0.3, 0.2, 0.1, 0.0)
    ),
    PaletteEntry(
        vec4(0.5, 0.5, 0.5, 0.0),
        vec4(1.0, 1.0, 1.0, 0.0),
        vec4(0.26, 0.57, 0.03, 0.0),
        vec4(0.0, 0.1, 0.3, 0.0)
    ),
    PaletteEntry(
        vec4(0.9, 0.76, 0.63, 0.0),
        vec4(1.0, 1.0, 1.0, 0.0),
        vec4(0.0, 0.19, 0.68, 0.0),
        vec4(0.43, 0.23, 0.32, 0.0)
    ),
    PaletteEntry(
        vec4(0.78, 0.63, 0.68, 0.0),
        vec4(1.0, 1.0, 1.0, 0.0),
        vec4(0.41, 0.03, 0.16, 0.0),
        vec4(0.81, 0.61, 0.06, 0.0)
    ),
    PaletteEntry(
        vec4(0.725, 0.7, 0.949, 0.0),
        vec4(1.0, 1.0, 1.0, 0.0),
        vec4(0.632, 0.378, 0.294, 0.0),
        vec4(0.0, 0.1, 0.2, 0.0)
    ),
    PaletteEntry(
        vec4(0.73, 0.36, 0.52, 0.0),
        vec4(1.0, 1.0, 1.0, 0.0),
        vec4(0.78, 0.68, 0.15, 0.0),
        vec4(0.74, 0.93, 0.28, 0.0)
    )
);

const float PI = 3.141592653589793;
const float TAU = 6.283185307179586;
const float LIGHTNESS_SCALE = 0.875;
const float LIGHTNESS_OFFSET = 0.0625;

float srgb_to_lin(float value) {
    if (value <= 0.04045) {
        return value / 12.92;
    }
    return pow((value + 0.055) / 1.055, 2.4);
}

float oklab_l_component(vec3 rgb) {
    float r_lin = srgb_to_lin(rgb.x);
    float g_lin = srgb_to_lin(rgb.y);
    float b_lin = srgb_to_lin(rgb.z);

    float l_val = 0.4121656120 * r_lin + 0.5362752080 * g_lin + 0.0514575653 * b_lin;
    float m_val = 0.2118591070 * r_lin + 0.6807189584 * g_lin + 0.1074065790 * b_lin;
    float s_val = 0.0883097947 * r_lin + 0.2818474174 * g_lin + 0.6302613616 * b_lin;

    float l_cbrt = pow(l_val, 1.0 / 3.0);
    float m_cbrt = pow(m_val, 1.0 / 3.0);
    float s_cbrt = pow(s_val, 1.0 / 3.0);

    return 0.2104542553 * l_cbrt + 0.7936177850 * m_cbrt - 0.0040720468 * s_cbrt;
}

float cosine_blend_weight(float blend) {
    return (1.0 - cos(blend * PI)) * 0.5;
}

void main() {
    ivec2 texSize = textureSize(inputTex, 0);
    vec2 uv = gl_FragCoord.xy / vec2(texSize);
    vec4 texel = texture(inputTex, uv);

    if (palette_index == 0) {
        fragColor = texel;
        return;
    }

    int clamped_index = clamp(palette_index - 1, 0, PALETTE_COUNT - 1);
    PaletteEntry palette = PALETTES[clamped_index];

    vec3 base_rgb = clamp(texel.rgb, 0.0, 1.0);
    float lightness = oklab_l_component(base_rgb);

    vec3 freq_vec = palette.freq.xyz;
    vec3 amp_vec = palette.amp.xyz;
    vec3 offset_vec = palette.offset.xyz;
    vec3 phase_vec = palette.phase.xyz + vec3(time);

    vec3 cosine_arg = freq_vec * (lightness * LIGHTNESS_SCALE + LIGHTNESS_OFFSET) + phase_vec;
    vec3 cosine_vals = cos(TAU * cosine_arg);
    vec3 palette_rgb = offset_vec + amp_vec * cosine_vals;

    float weight = cosine_blend_weight(alpha);
    vec3 blended = mix(base_rgb, palette_rgb, weight);
    
    fragColor = vec4(blended, texel.a);
}

