#version 300 es

/*
 * Reaction-diffusion display shader.
 * Converts the feedback buffer into output colors with optional palette cycling for animated looks.
 * Normalization keeps the solver output in [0,1] so post-processing stays predictable.
 */

precision highp float;
precision highp int;

uniform float time;
uniform float seed;
uniform vec2 resolution;
uniform sampler2D fbTex;
uniform int smoothing;
uniform int paletteMode;
uniform int colorMode;
uniform vec3 paletteOffset;
uniform vec3 paletteAmp;
uniform vec3 paletteFreq;
uniform vec3 palettePhase;
uniform int cyclePalette;
uniform float rotatePalette;
uniform float repeatPalette;
out vec4 fragColor;

#define PI 3.14159265359
#define TAU 6.28318530718
#define aspectRatio resolution.x / resolution.y


// Quadratic B-spline interpolation for 3 samples (degree 2 polynomial)
vec4 quadratic3(vec4 p0, vec4 p1, vec4 p2, float t) {
    // Quadratic B-spline interpolation (degree 2)
    // Smooth C¹ continuous blending between 3 control points
    // B-spline basis functions for uniform knots with t ∈ [0, 1]
    float t2 = t * t;
    
    // B-spline basis: B0 = (1-t)²/2, B1 = (-2t² + 2t + 1)/2, B2 = t²/2
    return p0 * 0.5 * (1.0 - t) * (1.0 - t) +
           p1 * 0.5 * (-2.0 * t2 + 2.0 * t + 1.0) +
           p2 * 0.5 * t2;
}

// 3x3 quadratic texture interpolation (9 taps)
vec4 quadratic(sampler2D tex, vec2 uv, vec2 texelSize) {
    uv += texelSize; // offset by one texel to accommodate texel centering
    vec2 texCoord = uv / texelSize;
    vec2 baseCoord = floor(texCoord - 0.5);
    vec2 f = fract(texCoord - 0.5);
    
    // Sample 3x3 grid centered on the interpolation point
    vec4 v00 = texture(tex, (baseCoord + vec2(-0.5, -0.5)) * texelSize);
    vec4 v10 = texture(tex, (baseCoord + vec2( 0.5, -0.5)) * texelSize);
    vec4 v20 = texture(tex, (baseCoord + vec2( 1.5, -0.5)) * texelSize);
    
    vec4 v01 = texture(tex, (baseCoord + vec2(-0.5,  0.5)) * texelSize);
    vec4 v11 = texture(tex, (baseCoord + vec2( 0.5,  0.5)) * texelSize);
    vec4 v21 = texture(tex, (baseCoord + vec2( 1.5,  0.5)) * texelSize);
    
    vec4 v02 = texture(tex, (baseCoord + vec2(-0.5,  1.5)) * texelSize);
    vec4 v12 = texture(tex, (baseCoord + vec2( 0.5,  1.5)) * texelSize);
    vec4 v22 = texture(tex, (baseCoord + vec2( 1.5,  1.5)) * texelSize);
    
    // Interpolate rows
    vec4 y0 = quadratic3(v00, v10, v20, f.x);
    vec4 y1 = quadratic3(v01, v11, v21, f.x);
    vec4 y2 = quadratic3(v02, v12, v22, f.x);
    
    // Interpolate columns
    return quadratic3(y0, y1, y2, f.y);
}

// Catmull-Rom spline for cubic interpolation
// Cubic B-spline 4-point interpolation (degree 3)
vec4 bicubic4(vec4 p0, vec4 p1, vec4 p2, vec4 p3, float t) {
    // Cubic B-spline basis functions for uniform knots
    // Provides C² continuous smoothing
    float t2 = t * t;
    float t3 = t2 * t;
    
    float b0 = (1.0 - t) * (1.0 - t) * (1.0 - t) / 6.0;
    float b1 = (3.0 * t3 - 6.0 * t2 + 4.0) / 6.0;
    float b2 = (-3.0 * t3 + 3.0 * t2 + 3.0 * t + 1.0) / 6.0;
    float b3 = t3 / 6.0;
    
    return p0 * b0 + p1 * b1 + p2 * b2 + p3 * b3;
}

// 4×4 bicubic B-spline texture interpolation (16 taps)
vec4 bicubic(sampler2D tex, vec2 uv, vec2 texelSize) {
    uv += texelSize;
    vec2 texCoord = uv / texelSize;
    vec2 baseCoord = floor(texCoord - 0.5);
    vec2 f = fract(texCoord - 0.5);
    
    // Sample 4×4 grid
    vec4 row0 = bicubic4(
        texture(tex, (baseCoord + vec2(-0.5, -0.5)) * texelSize),
        texture(tex, (baseCoord + vec2( 0.5, -0.5)) * texelSize),
        texture(tex, (baseCoord + vec2( 1.5, -0.5)) * texelSize),
        texture(tex, (baseCoord + vec2( 2.5, -0.5)) * texelSize),
        f.x
    );
    
    vec4 row1 = bicubic4(
        texture(tex, (baseCoord + vec2(-0.5,  0.5)) * texelSize),
        texture(tex, (baseCoord + vec2( 0.5,  0.5)) * texelSize),
        texture(tex, (baseCoord + vec2( 1.5,  0.5)) * texelSize),
        texture(tex, (baseCoord + vec2( 2.5,  0.5)) * texelSize),
        f.x
    );
    
    vec4 row2 = bicubic4(
        texture(tex, (baseCoord + vec2(-0.5,  1.5)) * texelSize),
        texture(tex, (baseCoord + vec2( 0.5,  1.5)) * texelSize),
        texture(tex, (baseCoord + vec2( 1.5,  1.5)) * texelSize),
        texture(tex, (baseCoord + vec2( 2.5,  1.5)) * texelSize),
        f.x
    );
    
    vec4 row3 = bicubic4(
        texture(tex, (baseCoord + vec2(-0.5,  2.5)) * texelSize),
        texture(tex, (baseCoord + vec2( 0.5,  2.5)) * texelSize),
        texture(tex, (baseCoord + vec2( 1.5,  2.5)) * texelSize),
        texture(tex, (baseCoord + vec2( 2.5,  2.5)) * texelSize),
        f.x
    );
    
    // Interpolate columns
    return bicubic4(row0, row1, row2, row3, f.y);
}

// Catmull-Rom 3-point cubic interpolation (degree 3)
vec4 catmullRom3(vec4 p0, vec4 p1, vec4 p2, float t) {
    // Catmull-Rom cubic interpolation for 3 points
    // Uses endpoint tangents estimated from neighbors
    float t2 = t * t;
    float t3 = t2 * t;
    
    // Tangent at p1 estimated as (p2 - p0) / 2
    vec4 m = 0.5 * (p2 - p0);
    
    // Hermite basis functions with tangent m at both endpoints
    return (2.0*t3 - 3.0*t2 + 1.0) * p1 + 
           (t3 - 2.0*t2 + t) * m +
           (-2.0*t3 + 3.0*t2) * p2 + 
           (t3 - t2) * m;
}

// Catmull-Rom 4-point cubic interpolation (degree 3)
vec4 catmullRom4(vec4 p0, vec4 p1, vec4 p2, vec4 p3, float t) {
    // Standard Catmull-Rom spline with tension = 0.5
    // Interpolating (passes through p1 and p2)
    return p1 + 0.5 * t * (p2 - p0 + t * (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3 + t * (3.0 * (p1 - p2) + p3 - p0)));
}

// 3×3 Catmull-Rom texture interpolation (9 taps)
vec4 catmullRom3x3(sampler2D tex, vec2 uv, vec2 texelSize) {
    uv += texelSize;
    vec2 texCoord = uv / texelSize;
    vec2 baseCoord = floor(texCoord - 0.5);
    vec2 f = fract(texCoord - 0.5);
    
    // Sample 3×3 grid
    vec4 v00 = texture(tex, (baseCoord + vec2(-0.5, -0.5)) * texelSize);
    vec4 v10 = texture(tex, (baseCoord + vec2( 0.5, -0.5)) * texelSize);
    vec4 v20 = texture(tex, (baseCoord + vec2( 1.5, -0.5)) * texelSize);
    
    vec4 v01 = texture(tex, (baseCoord + vec2(-0.5,  0.5)) * texelSize);
    vec4 v11 = texture(tex, (baseCoord + vec2( 0.5,  0.5)) * texelSize);
    vec4 v21 = texture(tex, (baseCoord + vec2( 1.5,  0.5)) * texelSize);
    
    vec4 v02 = texture(tex, (baseCoord + vec2(-0.5,  1.5)) * texelSize);
    vec4 v12 = texture(tex, (baseCoord + vec2( 0.5,  1.5)) * texelSize);
    vec4 v22 = texture(tex, (baseCoord + vec2( 1.5,  1.5)) * texelSize);
    
    // Interpolate rows using Catmull-Rom
    vec4 y0 = catmullRom3(v00, v10, v20, f.x);
    vec4 y1 = catmullRom3(v01, v11, v21, f.x);
    vec4 y2 = catmullRom3(v02, v12, v22, f.x);
    
    // Interpolate columns
    return catmullRom3(y0, y1, y2, f.y);
}

// 4×4 Catmull-Rom texture interpolation (16 taps)
vec4 catmullRom4x4(sampler2D tex, vec2 uv, vec2 texelSize) {
    uv += texelSize;
    vec2 texCoord = uv / texelSize;
    vec2 baseCoord = floor(texCoord - 0.5);
    vec2 f = fract(texCoord - 0.5);
    
    // Sample 4×4 grid and interpolate rows directly
    vec4 row0 = catmullRom4(
        texture(tex, (baseCoord + vec2(-0.5, -0.5)) * texelSize),
        texture(tex, (baseCoord + vec2( 0.5, -0.5)) * texelSize),
        texture(tex, (baseCoord + vec2( 1.5, -0.5)) * texelSize),
        texture(tex, (baseCoord + vec2( 2.5, -0.5)) * texelSize),
        f.x
    );
    
    vec4 row1 = catmullRom4(
        texture(tex, (baseCoord + vec2(-0.5,  0.5)) * texelSize),
        texture(tex, (baseCoord + vec2( 0.5,  0.5)) * texelSize),
        texture(tex, (baseCoord + vec2( 1.5,  0.5)) * texelSize),
        texture(tex, (baseCoord + vec2( 2.5,  0.5)) * texelSize),
        f.x
    );
    
    vec4 row2 = catmullRom4(
        texture(tex, (baseCoord + vec2(-0.5,  1.5)) * texelSize),
        texture(tex, (baseCoord + vec2( 0.5,  1.5)) * texelSize),
        texture(tex, (baseCoord + vec2( 1.5,  1.5)) * texelSize),
        texture(tex, (baseCoord + vec2( 2.5,  1.5)) * texelSize),
        f.x
    );
    
    vec4 row3 = catmullRom4(
        texture(tex, (baseCoord + vec2(-0.5,  2.5)) * texelSize),
        texture(tex, (baseCoord + vec2( 0.5,  2.5)) * texelSize),
        texture(tex, (baseCoord + vec2( 1.5,  2.5)) * texelSize),
        texture(tex, (baseCoord + vec2( 2.5,  2.5)) * texelSize),
        f.x
    );
    
    // Interpolate columns
    return catmullRom4(row0, row1, row2, row3, f.y);
}

float cosineMix(float a, float b, float t) {
    float amount = (1.0 - cos(t * PI)) * 0.5;
    return mix(a, b, amount);
}

vec3 hsv2rgb(vec3 hsv) {
    float h = fract(hsv.x);
    float s = clamp(hsv.y, 0.0, 1.0);
    float v = clamp(hsv.z, 0.0, 1.0);

    float c = v * s;
    float x = c * (1.0 - abs(mod(h * 6.0, 2.0) - 1.0));
    float m = v - c;

    vec3 rgb;

    if (h < 1.0 / 6.0) {
        rgb = vec3(c, x, 0.0);
    } else if (h < 2.0 / 6.0) {
        rgb = vec3(x, c, 0.0);
    } else if (h < 3.0 / 6.0) {
        rgb = vec3(0.0, c, x);
    } else if (h < 4.0 / 6.0) {
        rgb = vec3(0.0, x, c);
    } else if (h < 5.0 / 6.0) {
        rgb = vec3(x, 0.0, c);
    } else {
        rgb = vec3(c, 0.0, x);
    }

    return rgb + vec3(m);
}

vec3 linearToSrgb(vec3 linear) {
    vec3 srgb;
    for (int i = 0; i < 3; ++i) {
        if (linear[i] <= 0.0031308) {
            srgb[i] = linear[i] * 12.92;
        } else {
            srgb[i] = 1.055 * pow(linear[i], 1.0 / 2.4) - 0.055;
        }
    }
    return srgb;
}

const mat3 fwdA = mat3(1.0, 1.0, 1.0,
                       0.3963377774, -0.1055613458, -0.0894841775,
                       0.2158037573, -0.0638541728, -1.2914855480);

const mat3 fwdB = mat3(4.0767245293, -1.2681437731, -0.0041119885,
                       -3.3072168827, 2.6093323231, -0.7034763098,
                       0.2307590544, -0.3411344290,  1.7068625689);

const mat3 invB = mat3(0.4121656120, 0.2118591070, 0.0883097947,
                       0.5362752080, 0.6807189584, 0.2818474174,
                       0.0514575653, 0.1074065790, 0.6302613616);

const mat3 invA = mat3(0.2104542553, 1.9779984951, 0.0259040371,
                       0.7936177850, -2.4285922050, 0.7827717662,
                       -0.0040720468, 0.4505937099, -0.8086757660);

vec3 oklab_from_linear_srgb(vec3 c) {
    vec3 lms = invB * c;
    return invA * (sign(lms) * pow(abs(lms), vec3(0.3333333333333)));
}

vec3 linear_srgb_from_oklab(vec3 c) {
    vec3 lms = fwdA * c;
    return fwdB * (lms * lms * lms);
}

vec3 pal(float t) {
    float tt = t * repeatPalette + rotatePalette * 0.01;
    vec3 color = paletteOffset + paletteAmp * cos(6.28318 * (paletteFreq * tt + palettePhase));

    if (paletteMode == 1) {
        color = hsv2rgb(color);
    } else if (paletteMode == 2) {
        color.g = color.g * -.509 + .276;
        color.b = color.b * -.509 + .198;
        color = linear_srgb_from_oklab(color);
        color = linearToSrgb(color);
    }

    return color;
}

void main() {
    float state = 0.0;

    // Smoothing modes mirror the UI enum ordering; avoid renumbering without
    // updating module metadata and defaults.
    if (smoothing == 0) {
        // constant
        state = texture(fbTex, gl_FragCoord.xy / resolution).g;
    } else if (smoothing == 2) {
        // hermite (smoothstep)
        vec2 texSize = vec2(textureSize(fbTex, 0));
        vec2 texelPos = (gl_FragCoord.xy * texSize / resolution) - vec2(0.5);
        vec2 base = floor(texelPos);
        vec2 weights = fract(texelPos);
        vec2 next = base + vec2(1.0);

        ivec2 texSizeI = textureSize(fbTex, 0);
        ivec2 minIdx = ivec2(0);
        ivec2 maxIdx = texSizeI - ivec2(1);

        ivec2 baseIdx = clamp(ivec2(base), minIdx, maxIdx);
        ivec2 nextIdx = clamp(ivec2(next), minIdx, maxIdx);

        float v00 = texelFetch(fbTex, baseIdx, 0).g;
        float v10 = texelFetch(fbTex, ivec2(nextIdx.x, baseIdx.y), 0).g;
        float v01 = texelFetch(fbTex, ivec2(baseIdx.x, nextIdx.y), 0).g;
        float v11 = texelFetch(fbTex, nextIdx, 0).g;

        vec2 smoothWeights = smoothstep(0.0, 1.0, weights);
        float v0 = mix(v00, v10, smoothWeights.x);
        float v1 = mix(v01, v11, smoothWeights.x);
        state = mix(v0, v1, smoothWeights.y);
    } else if (smoothing == 3) {
        // catmull-rom 3x3 (9 taps)
        vec2 texSize = vec2(textureSize(fbTex, 0));
        vec2 texelSize = 1.0 / texSize;
        vec2 scaling = resolution / texSize;
        vec2 uv = (gl_FragCoord.xy - scaling * 0.5) / resolution;

        state = catmullRom3x3(fbTex, uv, texelSize).g;
    } else if (smoothing == 4) {
        // catmull-rom 4x4 (16 taps)
        vec2 texSize = vec2(textureSize(fbTex, 0));
        vec2 texelSize = 1.0 / texSize;
        vec2 scaling = resolution / texSize;
        vec2 uv = (gl_FragCoord.xy - scaling * 0.5) / resolution;

        state = catmullRom4x4(fbTex, uv, texelSize).g;
    } else if (smoothing == 5) {
        // b-spline 3x3 (9 taps)
        vec2 texSize = vec2(textureSize(fbTex, 0));
        vec2 texelSize = 1.0 / texSize;
        vec2 scaling = resolution / texSize;
        vec2 uv = (gl_FragCoord.xy - scaling * 0.5) / resolution;

        state = quadratic(fbTex, uv, texelSize).g;
    } else if (smoothing == 6) {
        // b-spline 4x4 (16 taps)
        vec2 texSize = vec2(textureSize(fbTex, 0));
        vec2 texelSize = 1.0 / texSize;
        vec2 scaling = resolution / texSize;
        vec2 uv = (gl_FragCoord.xy - scaling * 0.5) / resolution;

        state = bicubic(fbTex, uv, texelSize).g;
    } else {
        // linear or cosine smoothing using direct texel fetches to match the multires reference.
        vec2 texSize = vec2(textureSize(fbTex, 0));
        vec2 texelPos = (gl_FragCoord.xy * texSize / resolution) - vec2(0.5);
        vec2 base = floor(texelPos);
        vec2 weights = fract(texelPos);
        vec2 next = base + vec2(1.0);

        ivec2 texSizeI = textureSize(fbTex, 0);
        ivec2 minIdx = ivec2(0);
        ivec2 maxIdx = texSizeI - ivec2(1);

        ivec2 baseIdx = clamp(ivec2(base), minIdx, maxIdx);
        ivec2 nextIdx = clamp(ivec2(next), minIdx, maxIdx);

        float v00 = texelFetch(fbTex, baseIdx, 0).g;
        float v10 = texelFetch(fbTex, ivec2(nextIdx.x, baseIdx.y), 0).g;
        float v01 = texelFetch(fbTex, ivec2(baseIdx.x, nextIdx.y), 0).g;
        float v11 = texelFetch(fbTex, nextIdx, 0).g;

        if (smoothing == 1) {
            float v0 = mix(v00, v10, weights.x);
            float v1 = mix(v01, v11, weights.x);
            state = mix(v0, v1, weights.y);
        } else {
            float v0 = cosineMix(v00, v10, weights.x);
            float v1 = cosineMix(v01, v11, weights.x);
            state = cosineMix(v0, v1, weights.y);
        }
    }

    float intensity = clamp(state, 0.0, 1.0);

    vec3 finalColor = vec3(intensity);
    if (colorMode == 1) {
        float d = intensity;
        if (cyclePalette == -1) {
            d += time;
        } else if (cyclePalette == 1) {
            d -= time;
        }

        finalColor = pal(d);
    }

    fragColor = vec4(finalColor, 1.0);
}
