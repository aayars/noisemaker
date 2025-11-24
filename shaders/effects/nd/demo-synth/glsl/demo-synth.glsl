#version 300 es

/*
 * WebGL port of the revived demo synth. Mirrors the WGSL shader so both
 * renderers share identical procedural noise and colour logic.
 */

precision highp float;
precision highp int;

uniform vec2 resolution;
uniform float time;
uniform float aspect;
uniform float scale;
uniform float offset;
uniform float seed;
uniform int octaves;
uniform int colorMode;
uniform float hueRotation;
uniform float hueRange;
uniform bool ridged;

out vec4 fragColor;

const int COLOR_MODE_MONO = 0;
const int COLOR_MODE_RGB = 1;
const int COLOR_MODE_HSV = 2;
const int MAX_OCTAVES = 6;
const float TAU = 6.28318530718;

vec3 mod289(vec3 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 mod289(vec4 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 permute(vec4 x) {
    return mod289(((x * 34.0) + 1.0) * x);
}

vec4 taylorInvSqrt(vec4 r) {
    return vec4(1.79284291400159) - 0.85373472095314 * r;
}

float hash31(vec3 p) {
    p = fract(p * 0.1031);
    p += vec3(dot(p, p.yzx + vec3(33.33)));
    return fract((p.x + p.y) * p.z);
}

vec3 randomVec3(vec3 p) {
    return vec3(
        hash31(p),
        hash31(p + vec3(17.17, 27.27, 37.37)),
        hash31(p + vec3(41.41, 59.59, 73.73))
    ) * 2.0 - vec3(1.0);
}

vec3 safeNormalize(vec3 v) {
    float lenSq = dot(v, v);
    if (lenSq < 1e-8) {
        return vec3(1.0, 0.0, 0.0);
    }
    return v * inversesqrt(lenSq);
}

mat3 rotationFromAxisAngle(vec3 axis, float angle) {
    vec3 a = safeNormalize(axis);
    float s = sin(angle);
    float c = cos(angle);
    float oc = 1.0 - c;

    float r00 = oc * a.x * a.x + c;
    float r01 = oc * a.x * a.y - a.z * s;
    float r02 = oc * a.x * a.z + a.y * s;
    float r10 = oc * a.y * a.x + a.z * s;
    float r11 = oc * a.y * a.y + c;
    float r12 = oc * a.y * a.z - a.x * s;
    float r20 = oc * a.z * a.x - a.y * s;
    float r21 = oc * a.z * a.y + a.x * s;
    float r22 = oc * a.z * a.z + c;

    return mat3(
        vec3(r00, r10, r20),
        vec3(r01, r11, r21),
        vec3(r02, r12, r22)
    );
}

float snoise(vec3 v) {
    const vec2 C = vec2(1.0 / 6.0, 1.0 / 3.0);
    const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);

    vec3 i = floor(v + dot(v, vec3(C.y)));
    vec3 x0 = v - i + dot(i, vec3(C.x));

    vec3 g = step(x0.yzx, x0.xyz);
    vec3 l = vec3(1.0) - g;
    vec3 i1 = min(g.xyz, l.zxy);
    vec3 i2 = max(g.xyz, l.zxy);

    vec3 x1 = x0 - i1 + vec3(C.x);
    vec3 x2 = x0 - i2 + vec3(C.y);
    vec3 x3 = x0 - D.yyy;

    i = mod289(i);
    vec4 p = permute(
        permute(
            permute(vec4(i.z) + vec4(0.0, i1.z, i2.z, 1.0))
            + vec4(i.y) + vec4(0.0, i1.y, i2.y, 1.0)
        )
        + vec4(i.x) + vec4(0.0, i1.x, i2.x, 1.0)
    );

    const float n_ = 0.142857142857;
    vec3 ns = n_ * D.wyz - D.xzx;

    vec4 j = p - 49.0 * floor(p * ns.z * ns.z);

    vec4 x_ = floor(j * ns.z);
    vec4 y_ = floor(j - 7.0 * x_);

    vec4 x = x_ * ns.x + ns.y;
    vec4 y = y_ * ns.x + ns.y;
    vec4 h = vec4(1.0) - abs(x) - abs(y);

    vec4 b0 = vec4(x.xy, y.xy);
    vec4 b1 = vec4(x.zw, y.zw);

    vec4 s0 = floor(b0) * 2.0 + 1.0;
    vec4 s1 = floor(b1) * 2.0 + 1.0;
    vec4 sh = -step(h, vec4(0.0));

    vec4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
    vec4 a1 = b1.xzyw + s1.xzyw * sh.zzww;

    vec3 p0 = vec3(a0.xy, h.x);
    vec3 p1 = vec3(a0.zw, h.y);
    vec3 p2 = vec3(a1.xy, h.z);
    vec3 p3 = vec3(a1.zw, h.w);

    vec4 norm = taylorInvSqrt(vec4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
    p0 *= norm.x;
    p1 *= norm.y;
    p2 *= norm.z;
    p3 *= norm.w;

    vec4 m = max(vec4(0.6) - vec4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), vec4(0.0));
    m *= m;

    return 42.0 * dot(m * m, vec4(dot(p0, x0), dot(p1, x1), dot(p2, x2), dot(p3, x3)));
}

vec3 hsv2rgb(vec3 hsv) {
    float h = fract(hsv.x);
    float s = hsv.y;
    float v = hsv.z;

    float c = v * s;
    float h6 = h * 6.0;
    float k = h6 - 2.0 * floor(h6 / 2.0);
    float x = c * (1.0 - abs(k - 1.0));
    float m = v - c;

    vec3 rgb = vec3(0.0);
    if (h6 < 1.0) {
        rgb = vec3(c, x, 0.0);
    } else if (h6 < 2.0) {
        rgb = vec3(x, c, 0.0);
    } else if (h6 < 3.0) {
        rgb = vec3(0.0, c, x);
    } else if (h6 < 4.0) {
        rgb = vec3(0.0, x, c);
    } else if (h6 < 5.0) {
        rgb = vec3(x, 0.0, c);
    } else {
        rgb = vec3(c, 0.0, x);
    }
    return rgb + vec3(m);
}

float fbm(vec3 p, float offsetVal, bool ridgedFlag, int oct, float seedVal) {
    float amplitude = 0.5;
    float frequency = 1.0;
    float sum = 0.0;
    vec3 baseSeedOffset = randomVec3(vec3(seedVal, seedVal + 19.19, seedVal + 37.37)) * 10.0;
    vec3 offsetVec = vec3(offsetVal * 0.05, offsetVal * 0.09, offsetVal);
    vec3 baseP = p;

    for (int i = 0; i < MAX_OCTAVES; ++i) {
        if (i >= oct) { break; }
        float octave = float(i);
        vec3 jitterSeed = vec3(seedVal + octave * 31.31, offsetVal + octave * 17.17, octave * 13.13);
        vec3 axis = randomVec3(jitterSeed);
        float angle = hash31(jitterSeed + vec3(7.7, 11.1, 13.3)) * TAU;
        mat3 octaveRotation = rotationFromAxisAngle(axis, angle);
        vec3 sampleOffset = randomVec3(jitterSeed + vec3(23.0, 37.0, 53.0)) * 5.0;
        vec3 sampleP = octaveRotation * (baseP * frequency) + baseSeedOffset + offsetVec + sampleOffset;
        float n = snoise(sampleP);
        if (ridgedFlag) {
            n = 1.0 - abs(n);
            n = n * 2.0 - 1.0;
        }
        sum += n * amplitude;
        frequency *= 2.0;
        amplitude *= 0.5;
    }

    return sum;
}

void main() {
    vec2 st = gl_FragCoord.xy / resolution;
    st.x *= aspect;
    float zoom = 101.0 - scale;
    st *= zoom;

    float t = time + offset;
    vec3 domain = vec3(st, t);

    bool ridgedFlag = ridged;
    bool hybridRidged = colorMode == COLOR_MODE_HSV && ridgedFlag;

    float r = fbm(domain, 0.0, hybridRidged ? false : ridgedFlag, octaves, seed);
    float g = fbm(domain, 100.0, hybridRidged ? false : ridgedFlag, octaves, seed);
    float b = fbm(domain, 200.0, ridgedFlag, octaves, seed);

    vec3 col;
    if (colorMode == COLOR_MODE_MONO) {
        float v = r * 0.5 + 0.5;
        col = vec3(v);
    } else if (colorMode == COLOR_MODE_RGB) {
        col = vec3(r, g, b) * 0.5 + vec3(0.5);
    } else {
        float h = r * 0.5 + 0.5;
        h *= hueRange * 0.01;
        h += 1.0 - (hueRotation / 360.0);
        h = fract(h);
        float s = g * 0.5 + 0.5;
        float v = b * 0.5 + 0.5;
        col = hsv2rgb(vec3(h, s, v));
    }

    fragColor = vec4(col, 1.0);
}
