// Copyright 2025 Noise Factor LLC
// Licensed under the MIT License

// Cellular automata display pass (WGSL).

struct Uniforms {
    data : array<vec4<f32>, 8>,
};

@group(0) @binding(0) var<uniform> uniforms : Uniforms;
@group(0) @binding(1) var fbTex: texture_2d<f32>;
@group(0) @binding(2) var mySampler: sampler;

fn cubic(xIn: f32) -> f32 {
    var x = abs(xIn);
    if (x <= 1.0) {
        return 1.5 * x * x * x - 2.5 * x * x + 1.0;
    } else if (x < 2.0) {
        return -0.5 * x * x * x + 2.5 * x * x - 4.0 * x + 2.0;
    }
    return 0.0;
}

fn quadratic3(p0: vec4<f32>, p1: vec4<f32>, p2: vec4<f32>, t: f32) -> vec4<f32> {
    // Quadratic B-spline basis functions
    let t2 = t * t;
    
    let B0 = 0.5 * (1.0 - t) * (1.0 - t);
    let B1 = 0.5 * (-2.0 * t2 + 2.0 * t + 1.0);
    let B2 = 0.5 * t2;
    
    return p0 * B0 + p1 * B1 + p2 * B2;
}

fn catmullRom3(p0: vec4<f32>, p1: vec4<f32>, p2: vec4<f32>, t: f32) -> vec4<f32> {
    // Catmull-Rom 3-point interpolation
    let t2 = t * t;
    let t3 = t2 * t;
    
    return p1 + 0.5 * t * (p2 - p0) + 
           0.5 * t2 * (2.0*p0 - 5.0*p1 + 4.0*p2 - p0) +
           0.5 * t3 * (-p0 + 3.0*p1 - 3.0*p2 + p0);
}

fn catmullRom4(p0: vec4<f32>, p1: vec4<f32>, p2: vec4<f32>, p3: vec4<f32>, t: f32) -> vec4<f32> {
    // Catmull-Rom 4-point interpolation
    return p1 + 0.5 * t * (p2 - p0 + t * (2.0 * (p0 - p1) + (p2 - p1) + t * (3.0 * (p1 - p2) + p3 - p0)));
}

fn quadraticSample(tex: texture_2d<f32>, samp: sampler, uv: vec2<f32>, texelSize: vec2<f32>) -> vec4<f32> {
    // Match GLSL: offset uv by one texel to accommodate texel centering
    let uv2 = uv + texelSize;
    let texCoord = uv2 / texelSize;
    let baseCoord = floor(texCoord - 0.5);
    let f = fract(texCoord - 0.5);
    
    // Sample 3x3 grid centered on the interpolation point
    let v00 = textureSampleLevel(tex, samp, (baseCoord + vec2<f32>(-0.5, -0.5)) * texelSize, 0.0);
    let v10 = textureSampleLevel(tex, samp, (baseCoord + vec2<f32>( 0.5, -0.5)) * texelSize, 0.0);
    let v20 = textureSampleLevel(tex, samp, (baseCoord + vec2<f32>( 1.5, -0.5)) * texelSize, 0.0);
    
    let v01 = textureSampleLevel(tex, samp, (baseCoord + vec2<f32>(-0.5,  0.5)) * texelSize, 0.0);
    let v11 = textureSampleLevel(tex, samp, (baseCoord + vec2<f32>( 0.5,  0.5)) * texelSize, 0.0);
    let v21 = textureSampleLevel(tex, samp, (baseCoord + vec2<f32>( 1.5,  0.5)) * texelSize, 0.0);
    
    let v02 = textureSampleLevel(tex, samp, (baseCoord + vec2<f32>(-0.5,  1.5)) * texelSize, 0.0);
    let v12 = textureSampleLevel(tex, samp, (baseCoord + vec2<f32>( 0.5,  1.5)) * texelSize, 0.0);
    let v22 = textureSampleLevel(tex, samp, (baseCoord + vec2<f32>( 1.5,  1.5)) * texelSize, 0.0);
    
    // Interpolate rows using quadratic B-spline
    let y0 = quadratic3(v00, v10, v20, f.x);
    let y1 = quadratic3(v01, v11, v21, f.x);
    let y2 = quadratic3(v02, v12, v22, f.x);
    
    // Interpolate columns
    return quadratic3(y0, y1, y2, f.y);
}

fn catmullRom3x3Sample(tex: texture_2d<f32>, samp: sampler, uv: vec2<f32>, texelSize: vec2<f32>) -> vec4<f32> {
    // Match GLSL: offset uv by one texel to accommodate texel centering
    let uv2 = uv + texelSize;
    let texCoord = uv2 / texelSize;
    let baseCoord = floor(texCoord - 0.5);
    let f = fract(texCoord - 0.5);
    
    // Sample 3x3 grid
    let v00 = textureSampleLevel(tex, samp, (baseCoord + vec2<f32>(-0.5, -0.5)) * texelSize, 0.0);
    let v10 = textureSampleLevel(tex, samp, (baseCoord + vec2<f32>( 0.5, -0.5)) * texelSize, 0.0);
    let v20 = textureSampleLevel(tex, samp, (baseCoord + vec2<f32>( 1.5, -0.5)) * texelSize, 0.0);
    
    let v01 = textureSampleLevel(tex, samp, (baseCoord + vec2<f32>(-0.5,  0.5)) * texelSize, 0.0);
    let v11 = textureSampleLevel(tex, samp, (baseCoord + vec2<f32>( 0.5,  0.5)) * texelSize, 0.0);
    let v21 = textureSampleLevel(tex, samp, (baseCoord + vec2<f32>( 1.5,  0.5)) * texelSize, 0.0);
    
    let v02 = textureSampleLevel(tex, samp, (baseCoord + vec2<f32>(-0.5,  1.5)) * texelSize, 0.0);
    let v12 = textureSampleLevel(tex, samp, (baseCoord + vec2<f32>( 0.5,  1.5)) * texelSize, 0.0);
    let v22 = textureSampleLevel(tex, samp, (baseCoord + vec2<f32>( 1.5,  1.5)) * texelSize, 0.0);
    
    // Interpolate rows using Catmull-Rom
    let y0 = catmullRom3(v00, v10, v20, f.x);
    let y1 = catmullRom3(v01, v11, v21, f.x);
    let y2 = catmullRom3(v02, v12, v22, f.x);
    
    // Interpolate columns
    return catmullRom3(y0, y1, y2, f.y);
}

fn bicubicSample(tex: texture_2d<f32>, samp: sampler, uv: vec2<f32>, texelSize: vec2<f32>) -> vec4<f32> {
    // Match GLSL: offset uv by one texel to accommodate texel centering
    let uv2 = uv + texelSize;
    let texCoord = uv2 / texelSize;
    let baseCoord = floor(texCoord) - 0.5 * texelSize;
    let fractional = texCoord - baseCoord;

    var totalWeight = 0.0;
    var result = vec4<f32>(0.0);
    for (var j: i32 = -2; j <= 3; j++) {
        for (var i: i32 = -2; i <= 3; i++) {
            let offset = vec2<f32>(f32(i), f32(j));
            let sampleCoord = (baseCoord + offset) * texelSize;
            let weight = cubic(offset.x - fractional.x) * cubic(offset.y - fractional.y);
            totalWeight += weight;
            result += textureSampleLevel(tex, samp, sampleCoord, 0.0) * weight;
        }
    }
    return result / totalWeight;
}

fn catmullRom4x4Sample(tex: texture_2d<f32>, samp: sampler, uv: vec2<f32>, texelSize: vec2<f32>) -> vec4<f32> {
    let uv2 = uv + texelSize;
    let texCoord = uv2 / texelSize;
    let baseCoord = floor(texCoord - 0.5);
    let f = fract(texCoord - 0.5);
    
    // Sample 4x4 grid
    var samples: array<array<vec4<f32>, 4>, 4>;
    for (var y: i32 = 0; y < 4; y++) {
        for (var x: i32 = 0; x < 4; x++) {
            let offset = vec2<f32>(f32(x) - 1.5, f32(y) - 1.5);
            samples[y][x] = textureSampleLevel(tex, samp, (baseCoord + offset) * texelSize, 0.0);
        }
    }
    
    // Interpolate rows
    var rows: array<vec4<f32>, 4>;
    for (var y: i32 = 0; y < 4; y++) {
        rows[y] = catmullRom4(samples[y][0], samples[y][1], samples[y][2], samples[y][3], f.x);
    }
    
    // Interpolate columns
    return catmullRom4(rows[0], rows[1], rows[2], rows[3], f.y);
}

fn cosineMix(a: f32, b: f32, t: f32) -> f32 {
    let amount = (1.0 - cos(t * 3.141592653589793)) * 0.5;
    return mix(a, b, amount);
}

fn hsv2rgb(hsv: vec3<f32>) -> vec3<f32> {
    let h = fract(hsv.x);
    let s = clamp(hsv.y, 0.0, 1.0);
    let v = clamp(hsv.z, 0.0, 1.0);

    let c = v * s;
    let x = c * (1.0 - abs(fract(h * 6.0) * 2.0 - 1.0));
    let m = v - c;

    var rgb = vec3<f32>(0.0);
    if (0.0 <= h && h < 1.0 / 6.0) {
        rgb = vec3<f32>(c, x, 0.0);
    } else if (1.0 / 6.0 <= h && h < 2.0 / 6.0) {
        rgb = vec3<f32>(x, c, 0.0);
    } else if (2.0 / 6.0 <= h && h < 3.0 / 6.0) {
        rgb = vec3<f32>(0.0, c, x);
    } else if (3.0 / 6.0 <= h && h < 4.0 / 6.0) {
        rgb = vec3<f32>(0.0, x, c);
    } else if (4.0 / 6.0 <= h && h < 5.0 / 6.0) {
        rgb = vec3<f32>(x, 0.0, c);
    } else if (5.0 / 6.0 <= h && h < 1.0) {
        rgb = vec3<f32>(c, 0.0, x);
    }
    return clamp(rgb + vec3<f32>(m, m, m), vec3<f32>(0.0), vec3<f32>(1.0));
}

fn linearToSrgb(linear: vec3<f32>) -> vec3<f32> {
    var srgb = vec3<f32>(0.0);
    for (var i: i32 = 0; i < 3; i++) {
        let v = linear[i];
        if (v <= 0.0031308) {
            srgb[i] = v * 12.92;
        } else {
            srgb[i] = 1.055 * pow(v, 1.0 / 2.4) - 0.055;
        }
    }
    return srgb;
}

fn linear_srgb_from_oklab(c: vec3<f32>) -> vec3<f32> {
    let fwdA = mat3x3<f32>(
        vec3<f32>(1.0, 1.0, 1.0),
        vec3<f32>(0.3963377774, -0.1055613458, -0.0894841775),
        vec3<f32>(0.2158037573, -0.0638541728, -1.2914855480)
    );
    let fwdB = mat3x3<f32>(
        vec3<f32>(4.0767245293, -1.2681437731, -0.0041119885),
        vec3<f32>(-3.3072168827, 2.6093323231, -0.7034763098),
        vec3<f32>(0.2307590544, -0.3411344290,  1.7068625689)
    );
    let lms = fwdA * c;
    return fwdB * (lms * lms * lms);
}

fn pal(cursor: f32) -> vec3<f32> {
    let paletteMode = i32(uniforms.data[1].w);
    let offset = uniforms.data[4].xyz;
    let amp = uniforms.data[5].xyz;
    let freq = uniforms.data[6].xyz;
    let phase = uniforms.data[7].xyz;
    var color = offset + amp * cos(6.28318 * (freq * cursor + phase));
    if (paletteMode == 1) {
        color = hsv2rgb(color);
    } else if (paletteMode == 2) {
        color.g = color.g * -0.509 + 0.276;
        color.b = color.b * -0.509 + 0.198;
        color = linear_srgb_from_oklab(color);
        color = linearToSrgb(color);
    }
    return clamp(color, vec3<f32>(0.0), vec3<f32>(1.0));
}

fn applyPalette(state: f32) -> vec3<f32> {
    let colorMode = i32(uniforms.data[1].z);
    let time = uniforms.data[0].z;
    let repeatPalette = uniforms.data[2].z;
    let rotatePalette = uniforms.data[2].y * 0.01;
    let cyclePalette = i32(uniforms.data[2].x);
    let intensity = clamp(state, 0.0, 1.0);
    if (colorMode == 4) {
        var cursor = intensity * repeatPalette + rotatePalette;
        if (cyclePalette == -1) {
            cursor += time;
        } else if (cyclePalette == 1) {
            cursor -= time;
        }
        let base = pal(cursor);
        return mix(vec3<f32>(0.0), base, intensity);
    }
    return vec3<f32>(intensity);
}

@fragment fn main(@builtin(position) fragCoord: vec4<f32>) -> @location(0) vec4<f32> {
    let resolution = uniforms.data[0].xy;
    let smoothing = i32(uniforms.data[1].y);

    var state: f32 = 0.0;
    if (smoothing == 0) {
        // constant - use textureLoad for exact nearest-neighbor sampling
        let texSizeI = vec2<i32>(textureDimensions(fbTex, 0));
        let texSizeF = vec2<f32>(f32(texSizeI.x), f32(texSizeI.y));
        let pixelCoord = vec2<i32>(floor(fragCoord.xy * texSizeF / resolution));
        state = textureLoad(fbTex, clamp(pixelCoord, vec2<i32>(0), texSizeI - vec2<i32>(1)), 0).g;
    } else if (smoothing == 3) {
        // quadratic B-spline (3x3, 9 taps)
        let texSize = vec2<f32>(textureDimensions(fbTex, 0));
        let texelSize = 1.0 / texSize;
        let scaling = resolution / texSize;
        let uv = (fragCoord.xy - scaling * 0.5) / resolution;
        state = quadraticSample(fbTex, mySampler, uv, texelSize).g;
    } else if (smoothing == 4) {
        // cubic B-spline (4×4, 16 taps)
        let texSize = vec2<f32>(textureDimensions(fbTex, 0));
        let texelSize = 1.0 / texSize;
        let scaling = resolution / texSize;
        let uv = (fragCoord.xy - scaling * 0.5) / resolution;
        state = bicubicSample(fbTex, mySampler, uv, texelSize).g;
    } else if (smoothing == 5) {
        // catmull-rom 3x3 (9 taps, interpolating)
        let texSize = vec2<f32>(textureDimensions(fbTex, 0));
        let texelSize = 1.0 / texSize;
        let scaling = resolution / texSize;
        let uv = (fragCoord.xy - scaling * 0.5) / resolution;
        state = catmullRom3x3Sample(fbTex, mySampler, uv, texelSize).g;
    } else if (smoothing == 6) {
        // catmull-rom 4x4 (16 taps, interpolating)
        let texSize = vec2<f32>(textureDimensions(fbTex, 0));
        let texelSize = 1.0 / texSize;
        let scaling = resolution / texSize;
        let uv = (fragCoord.xy - scaling * 0.5) / resolution;
        state = catmullRom4x4Sample(fbTex, mySampler, uv, texelSize).g;
    } else {
        // linear-style smoothing — sample texel centres explicitly to avoid seams.
        let texSize = vec2<f32>(textureDimensions(fbTex, 0));
        let texelPos = (fragCoord.xy * texSize / resolution) - vec2<f32>(0.5, 0.5);
        let base = floor(texelPos);
        let weights = fract(texelPos);
        let next = base + vec2<f32>(1.0, 1.0);

        let texSizeI = vec2<i32>(textureDimensions(fbTex, 0));
        let minIdx = vec2<i32>(0, 0);
        let maxIdx = texSizeI - vec2<i32>(1, 1);
        let baseI = clamp(vec2<i32>(base), minIdx, maxIdx);
        let nextI = clamp(vec2<i32>(next), minIdx, maxIdx);

        let v00 = textureLoad(fbTex, baseI, 0).g;
        let v10 = textureLoad(fbTex, vec2<i32>(nextI.x, baseI.y), 0).g;
        let v01 = textureLoad(fbTex, vec2<i32>(baseI.x, nextI.y), 0).g;
        let v11 = textureLoad(fbTex, nextI, 0).g;

        if (smoothing == 1) {
            let v0 = mix(v00, v10, weights.x);
            let v1 = mix(v01, v11, weights.x);
            state = mix(v0, v1, weights.y);
        } else {
            let v0 = cosineMix(v00, v10, weights.x);
            let v1 = cosineMix(v01, v11, weights.x);
            state = cosineMix(v0, v1, weights.y);
        }
    }

    let color = applyPalette(state);
    return vec4<f32>(color, 1.0);
}
