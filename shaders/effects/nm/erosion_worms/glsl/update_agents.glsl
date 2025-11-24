#version 300 es

precision highp float;

uniform sampler2D agentTex;
uniform sampler2D inputTex;
uniform vec2 resolution;
uniform int frame;
uniform float density;
uniform float stride;
uniform bool quantize;
uniform bool inverse;
uniform bool xy_blend;
uniform float worm_lifetime;
uniform float time;

layout(location = 0) out vec4 wormsOut;

const float TAU = 6.28318530718;
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

vec2 sampleGradient(vec2 uv) {
    vec2 texel = vec2(1.0) / resolution;
    vec3 c = texture(inputTex, uv).rgb;
    vec3 cx1 = texture(inputTex, uv + vec2(texel.x, 0.0)).rgb;
    vec3 cx2 = texture(inputTex, uv - vec2(texel.x, 0.0)).rgb;
    vec3 cy1 = texture(inputTex, uv + vec2(0.0, texel.y)).rgb;
    vec3 cy2 = texture(inputTex, uv - vec2(0.0, texel.y)).rgb;
    const vec3 luma = vec3(0.299, 0.587, 0.114);
    float gx = dot(cx1 - cx2, luma);
    float gy = dot(cy1 - cy2, luma);
    vec2 grad = vec2(gx, gy);
    if (length(grad) < 1e-4) {
        return vec2(0.0, 1.0);
    }
    return normalize(grad);
}

void main() {
    ivec2 dims = textureSize(agentTex, 0);
    vec2 uv = (gl_FragCoord.xy - 0.5) / vec2(dims);

    vec4 state = texture(agentTex, uv);
    vec2 pos = state.xy;
    float headingNorm = state.z;
    float ageNorm = state.w;

    float heading = headingNorm * TAU - PI;
    float lifetime = max(worm_lifetime, 1.0);
    float age = ageNorm * lifetime;

    float noiseSeed = hash21(uv + float(frame) * 0.013 + time * 0.11);

    if (frame <= 1 || pos == vec2(0.0)) {
        pos = spawnPosition(uv, noiseSeed);
        heading = spawnHeading(uv, noiseSeed);
        age = 0.0;
    }

    if (age > lifetime) {
        pos = spawnPosition(uv + 0.17, noiseSeed);
        heading = spawnHeading(uv + 0.53, noiseSeed);
        age = 0.0;
    }

    vec2 grad = sampleGradient(pos);
    if (xy_blend) {
        grad = normalize(grad + vec2(grad.y, -grad.x));
    }
    if (quantize) {
        grad = sign(grad);
        if (grad == vec2(0.0)) {
            grad = vec2(1.0, 0.0);
        }
        grad = normalize(grad);
    }
    if (inverse) {
        grad = -grad;
    }

    float steer = atan(grad.y, grad.x);
    float inertia = mix(0.6, 0.92, clamp(density / 100.0, 0.0, 1.0));
    heading = mix(heading, steer, 1.0 - inertia);
    heading += (rand(noiseSeed) - 0.5) * 0.35;

    float speedPixels = max(stride, 0.1);
    float step = speedPixels / max(resolution.x, resolution.y);
    vec2 dir = vec2(cos(heading), sin(heading));
    pos = wrap01(pos + dir * step);

    age += 1.0;

    float headingOut = fract((heading + PI) / TAU);
    float ageOut = clamp(age / lifetime, 0.0, 1.0);
    wormsOut = vec4(pos, headingOut, ageOut);
}
