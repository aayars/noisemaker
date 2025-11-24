/*
 * Reinstated fractal noise demo synth.
 * Matches the original WebGPU prototype while sharing uniforms with the WebGL port.
 */

const COLOR_MODE_MONO : i32 = 0;
const COLOR_MODE_RGB : i32 = 1;
const COLOR_MODE_HSV : i32 = 2;
const MAX_OCTAVES : i32 = 6;
const TAU : f32 = 6.28318530718;

struct Uniforms {
    data : array<vec4<f32>, 4>
};
@group(0) @binding(0) var<uniform> uniforms : Uniforms;

struct DemoUniforms {
    resolution : vec2<f32>,
    time : f32,
    aspect : f32,
    scale : f32,
    offset : f32,
    seed : f32,
    octaves : i32,
    colorMode : i32,
    hueRotation : f32,
    hueRange : f32,
    ridged : bool,
};

fn loadUniforms() -> DemoUniforms {
    let row0 = uniforms.data[0];
    let row1 = uniforms.data[1];
    let row2 = uniforms.data[2];
    return DemoUniforms(
        row0.xy,
        row0.z,
        row0.w,
        row1.x,
        row1.y,
        row1.z,
        i32(row1.w),
        i32(row2.x),
        row2.y,
        row2.z,
        row2.w != 0.0,
    );
}

fn mod289(x: vec3<f32>) -> vec3<f32> {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}
fn mod289_4(x: vec4<f32>) -> vec4<f32> {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}
fn permute(x: vec4<f32>) -> vec4<f32> {
    return mod289_4(((x * 34.0) + 1.0) * x);
}
fn taylorInvSqrt(r: vec4<f32>) -> vec4<f32> {
    return 1.79284291400159 - 0.85373472095314 * r;
}

fn hash31(p: vec3<f32>) -> f32 {
    var q = fract(p * 0.1031);
    q = q + vec3<f32>(dot(q, q.yzx + vec3<f32>(33.33, 33.33, 33.33)));
    return fract((q.x + q.y) * q.z);
}

fn randomVec3(p: vec3<f32>) -> vec3<f32> {
    return vec3<f32>(
        hash31(p),
        hash31(p + vec3<f32>(17.17, 27.27, 37.37)),
        hash31(p + vec3<f32>(41.41, 59.59, 73.73))
    ) * 2.0 - vec3<f32>(1.0, 1.0, 1.0);
}

fn safeNormalize(v: vec3<f32>) -> vec3<f32> {
    let lenSq = dot(v, v);
    if (lenSq < 1e-8) {
        return vec3<f32>(1.0, 0.0, 0.0);
    }
    return v * inverseSqrt(lenSq);
}

fn rotationFromAxisAngle(axis: vec3<f32>, angle: f32) -> mat3x3<f32> {
    let a = safeNormalize(axis);
    let s = sin(angle);
    let c = cos(angle);
    let oc = 1.0 - c;

    let r00 = oc * a.x * a.x + c;
    let r01 = oc * a.x * a.y - a.z * s;
    let r02 = oc * a.x * a.z + a.y * s;
    let r10 = oc * a.y * a.x + a.z * s;
    let r11 = oc * a.y * a.y + c;
    let r12 = oc * a.y * a.z - a.x * s;
    let r20 = oc * a.z * a.x - a.y * s;
    let r21 = oc * a.z * a.y + a.x * s;
    let r22 = oc * a.z * a.z + c;

    return mat3x3<f32>(
        vec3<f32>(r00, r10, r20),
        vec3<f32>(r01, r11, r21),
        vec3<f32>(r02, r12, r22)
    );
}

fn snoise(v: vec3<f32>) -> f32 {
    let C = vec2<f32>(1.0/6.0, 1.0/3.0);
    let D = vec4<f32>(0.0, 0.5, 1.0, 2.0);

    var i = floor(v + dot(v, C.yyy));
    var x0 = v - i + dot(i, C.xxx);

    var g = step(x0.yzx, x0.xyz);
    var l = 1.0 - g;
    var i1 = min(g.xyz, l.zxy);
    var i2 = max(g.xyz, l.zxy);

    var x1 = x0 - i1 + C.xxx;
    var x2 = x0 - i2 + C.yyy;
    var x3 = x0 - D.yyy;

    i = mod289(i);
    var p = permute(
                permute(
                    permute(i.z + vec4<f32>(0.0, i1.z, i2.z, 1.0))
                    + i.y + vec4<f32>(0.0, i1.y, i2.y, 1.0)
                )
                + i.x + vec4<f32>(0.0, i1.x, i2.x, 1.0)
            );

    let n_ = 0.142857142857;
    let ns = n_ * D.wyz - D.xzx;

    var j = p - 49.0 * floor(p * ns.z * ns.z);

    var x_ = floor(j * ns.z);
    var y_ = floor(j - 7.0 * x_);

    var x = x_ * ns.x + ns.y;
    var y = y_ * ns.x + ns.y;
    var h = 1.0 - abs(x) - abs(y);

    var b0 = vec4<f32>(x.xy, y.xy);
    var b1 = vec4<f32>(x.zw, y.zw);

    var s0 = floor(b0) * 2.0 + 1.0;
    var s1 = floor(b1) * 2.0 + 1.0;
    var sh = -step(h, vec4<f32>(0.0));

    var a0 = b0.xzyw + s0.xzyw * sh.xxyy;
    var a1 = b1.xzyw + s1.xzyw * sh.zzww;

    var p0 = vec3<f32>(a0.xy, h.x);
    var p1 = vec3<f32>(a0.zw, h.y);
    var p2 = vec3<f32>(a1.xy, h.z);
    var p3 = vec3<f32>(a1.zw, h.w);

    var norm = taylorInvSqrt(vec4<f32>(dot(p0,p0), dot(p1,p1), dot(p2,p2), dot(p3,p3)));
    p0 *= norm.x;
    p1 *= norm.y;
    p2 *= norm.z;
    p3 *= norm.w;

    var m = max(vec4<f32>(0.6) - vec4<f32>(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), vec4<f32>(0.0));
    m = m * m;
    return 42.0 * dot(m * m, vec4<f32>(dot(p0,x0), dot(p1,x1), dot(p2,x2), dot(p3,x3)));
}

fn hsv2rgb(hsv: vec3<f32>) -> vec3<f32> {
    let h = fract(hsv.x);
    let s = hsv.y;
    let v = hsv.z;

    let c = v * s;
    let h6 = h * 6.0;
    let k = h6 - 2.0 * floor(h6 / 2.0);
    let x = c * (1.0 - abs(k - 1.0));
    let m = v - c;

    var rgb = vec3<f32>(0.0);
    if (h6 < 1.0) {
        rgb = vec3<f32>(c, x, 0.0);
    } else if (h6 < 2.0) {
        rgb = vec3<f32>(x, c, 0.0);
    } else if (h6 < 3.0) {
        rgb = vec3<f32>(0.0, c, x);
    } else if (h6 < 4.0) {
        rgb = vec3<f32>(0.0, x, c);
    } else if (h6 < 5.0) {
        rgb = vec3<f32>(x, 0.0, c);
    } else if (h6 < 6.0) {
        rgb = vec3<f32>(c, 0.0, x);
    }
    return rgb + vec3<f32>(m, m, m);
}

fn fbm(p: vec3<f32>, offset: f32, ridged: bool, oct: i32, seed: f32) -> f32 {
    var amplitude = 0.5;
    var frequency = 1.0;
    var sum = 0.0;
    let baseSeedOffset = randomVec3(vec3<f32>(seed, seed + 19.19, seed + 37.37)) * 10.0;
    let offsetVec = vec3<f32>(offset * 0.05, offset * 0.09, offset);
    for (var i = 0; i < MAX_OCTAVES; i = i + 1) {
        if (i >= oct) { break; }
        let octave = f32(i);
        let jitterSeed = vec3<f32>(seed + octave * 31.31, offset + octave * 17.17, octave * 13.13);
        let axis = randomVec3(jitterSeed);
        let angle = hash31(jitterSeed + vec3<f32>(7.7, 11.1, 13.3)) * TAU;
        let octaveRotation = rotationFromAxisAngle(axis, angle);
        let sampleOffset = randomVec3(jitterSeed + vec3<f32>(23.0, 37.0, 53.0)) * 5.0;
        var n = snoise(octaveRotation * (p * frequency) + baseSeedOffset + offsetVec + sampleOffset);
        if (ridged) {
            n = 1.0 - abs(n);
            n = n * 2.0 - 1.0;
        }
        sum = sum + n * amplitude;
        frequency = frequency * 2.0;
        amplitude = amplitude * 0.5;
    }
    return sum;
}

@fragment
fn main(@builtin(position) pos : vec4<f32>) -> @location(0) vec4<f32> {
    let uniformsData = loadUniforms();
    var st = pos.xy / uniformsData.resolution;
    st.x = st.x * uniformsData.aspect;
    let zoom = 101.0 - uniformsData.scale;
    st = st * zoom;

    let t = uniformsData.time + uniformsData.offset;
    let domain = vec3<f32>(st, t);
    let hybridRidged = uniformsData.colorMode == COLOR_MODE_HSV && uniformsData.ridged;

    let r = fbm(domain, 0.0, hybridRidged ? false : uniformsData.ridged, uniformsData.octaves, uniformsData.seed);
    let g = fbm(domain, 100.0, hybridRidged ? false : uniformsData.ridged, uniformsData.octaves, uniformsData.seed);
    let b = fbm(domain, 200.0, uniformsData.ridged, uniformsData.octaves, uniformsData.seed);

    var col: vec3<f32>;
    switch uniformsData.colorMode {
        case COLOR_MODE_MONO: {
            let v = r * 0.5 + 0.5;
            col = vec3<f32>(v, v, v);
        }
        case COLOR_MODE_RGB: {
            col = vec3<f32>(r, g, b) * 0.5 + vec3<f32>(0.5);
        }
        default: {
            var h = r * 0.5 + 0.5;
            h = h * (uniformsData.hueRange * 0.01);
            h = h + 1.0 - (uniformsData.hueRotation / 360.0);
            h = fract(h);
            let s = g * 0.5 + 0.5;
            let v = b * 0.5 + 0.5;
            col = hsv2rgb(vec3<f32>(h, s, v));
        }
    }

    return vec4<f32>(col, 1.0);
}
