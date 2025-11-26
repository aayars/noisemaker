#version 300 es

precision highp float;

uniform sampler2D gridTex;
uniform vec2 resolution;
uniform int frame;
uniform float seedDensity;
uniform float padding;
uniform float density;
uniform float alpha;

layout(location = 0) out vec4 dlaOutColor;

float hash11(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

float hash21(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}

vec3 seedTint(float t) {
    return vec3(1.0, mix(0.12, 0.35, t), mix(0.75, 0.95, t));
}

void main() {
    vec2 dims = resolution;
    vec2 uv = (gl_FragCoord.xy - 0.5) / dims;

    vec4 prev = texture(gridTex, uv);

    // Controlled decay to keep the structure alive while avoiding blowout
    float padBias = clamp(padding / 8.0, 0.0, 1.0);
    float decay = mix(0.90, 0.988, clamp(alpha + padBias * 0.35, 0.0, 1.0));
    vec3 color = prev.rgb * decay;
    float energy = prev.a * decay;

    float rng = hash21(gl_FragCoord.xy + float(frame) * 17.0);
    float radial = smoothstep(0.18, 0.02, length(uv - 0.5));
    float seedWeight = 0.0;

    if (frame <= 1) {
        float densityScale = clamp(seedDensity * 900.0, 0.0, 0.98);
        seedWeight = step(1.0 - densityScale, rng) * radial;
    } else if (energy < 0.015) {
        float dripChance = clamp(seedDensity * (3.0 + density * 2.5), 0.0, 0.4);
        seedWeight = step(1.0 - dripChance, rng * 0.82) * radial * 0.6;
    }

    if (seedWeight > 0.0) {
        vec3 tint = seedTint(hash11(rng * 19.31));
        float strength = mix(0.25, 0.85, seedWeight);
        color = max(color, tint * strength);
        energy = max(energy, strength);
    }

    dlaOutColor = vec4(clamp(color, 0.0, 1.0), clamp(energy, 0.0, 1.0));
}