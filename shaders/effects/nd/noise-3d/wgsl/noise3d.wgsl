/*
 * WGSL 3D noise shader.
 * Implements the same simplex volume slicing as the GLSL variant so presets align.
 * Loop parameters are normalized against resolution to prevent aliasing differences.
 */

struct Uniforms {
    data : array<vec4<f32>, 4>,
};
@group(0) @binding(0) var<uniform> uniforms : Uniforms;
@group(0) @binding(1) var samp : sampler;

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
    } else {
        rgb = vec3<f32>(c, 0.0, x);
    }
    return rgb + vec3<f32>(m, m, m);
}

fn fbm(p: vec3<f32>, ridged: i32, seed: f32) -> f32 {
    var amplitude = 0.5;
    var frequency = 1.0;
    var sum = 0.0;
    var i = 0;
    loop {
        if (i >= 4) { break; }
        var n = snoise(p * frequency + seed + f32(i) * 10.0);
        if (ridged == 1) {
            n = 1.0 - abs(n);
            n = n * 2.0 - 1.0;
        }
        sum = sum + n * amplitude;
        frequency = frequency * 2.0;
        amplitude = amplitude * 0.5;
        i = i + 1;
    }
    return sum;
}

@fragment
fn main(@builtin(position) pos : vec4<f32>) -> @location(0) vec4<f32> {
    let resolution = uniforms.data[0].xy;
    let time = uniforms.data[0].z;
    let scale = uniforms.data[1].x;
    let offset = uniforms.data[1].yz;
    let seed = uniforms.data[1].w;
    let speed = uniforms.data[2].x;
    let colorMode = i32(uniforms.data[2].y);
    let hueRotation = uniforms.data[2].z;
    let hueRange = uniforms.data[2].w;
    let ridged = i32(uniforms.data[3].x);

    var st = pos.xy / resolution;
    st = st * scale + offset;
    let p = vec3<f32>(st, time * speed);

    var r = fbm(p, ridged, seed);
    var g = fbm(p + vec3<f32>(100.0), ridged, seed);
    var b = fbm(p + vec3<f32>(200.0), ridged, seed);

    var col: vec3<f32>;
    if (colorMode == 0) {
        let v = r * 0.5 + 0.5;
        col = vec3<f32>(v, v, v);
    } else if (colorMode == 1) {
        col = vec3<f32>(r, g, b) * 0.5 + vec3<f32>(0.5);
    } else {
        var h = r * 0.5 + 0.5;
        h = h * (hueRange * 0.01);
        h = h + 1.0 - (hueRotation / 360.0);
        h = fract(h);
        let s = g * 0.5 + 0.5;
        let v = b * 0.5 + 0.5;
        col = hsv2rgb(vec3<f32>(h, s, v));
    }
    var color = vec4<f32>(col, 1.0);

    return color;
}
