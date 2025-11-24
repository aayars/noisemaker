// WGSL version – WebGPU
@group(0) @binding(0) var<uniform> resolution: vec2<f32>;
@group(0) @binding(1) var<uniform> aspect: f32;
@group(0) @binding(2) var<uniform> time: f32;
@group(0) @binding(3) var<uniform> scale: f32;
@group(0) @binding(4) var<uniform> offset: f32;
@group(0) @binding(5) var<uniform> seed: f32;
@group(0) @binding(6) var<uniform> octaves: i32;
@group(0) @binding(7) var<uniform> colorMode: i32;
@group(0) @binding(8) var<uniform> hueRotation: f32;
@group(0) @binding(9) var<uniform> hueRange: f32;
@group(0) @binding(10) var<uniform> ridged: i32;

/* 3D simplex noise implementation based on the Ashima Arts reference (MIT License).
   Animated by treating time as the third dimension. */

fn mod_f32(x: f32, y: f32) -> f32 {
  return x - y * floor(x / y);
}

fn mod289(x: vec3<f32>) -> vec3<f32> {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}
fn mod289_v4(x: vec4<f32>) -> vec4<f32> {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}
fn permute(x: vec4<f32>) -> vec4<f32> {
  return mod289_v4(((x * 34.0) + 1.0) * x);
}
fn taylorInvSqrt(r: vec4<f32>) -> vec4<f32> {
  return 1.79284291400159 - 0.85373472095314 * r;
}

fn snoise(v: vec3<f32>) -> f32 {
  let C = vec2<f32>(1.0 / 6.0, 1.0 / 3.0);
  let D = vec4<f32>(0.0, 0.5, 1.0, 2.0);
  var i = floor(v + vec3<f32>(dot(v, vec3<f32>(C.y))));
  var x0 = v - i + vec3<f32>(dot(i, vec3<f32>(C.x)));
  var g = step(x0.yzx, x0.xyz);
  var l = vec3<f32>(1.0) - g;
  var i1 = min(g, l.zxy);
  var i2 = max(g, l.zxy);
  var x1 = x0 - i1 + vec3<f32>(C.x);
  var x2 = x0 - i2 + vec3<f32>(C.y);
  var x3 = x0 - vec3<f32>(D.y);
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
  let j = p - 49.0 * floor(p * ns.z * ns.z);
  let x_ = floor(j * ns.z);
  let y_ = floor(j - 7.0 * x_);
  let x = x_ * ns.x + ns.y;
  let y = y_ * ns.x + ns.y;
  let h = vec4<f32>(1.0) - abs(x) - abs(y);
  let b0 = vec4<f32>(x.xy, y.xy);
  let bVec1 = vec4<f32>(x.zw, y.zw);
  let s0 = floor(b0) * 2.0 + vec4<f32>(1.0);
  let sVec1 = floor(bVec1) * 2.0 + vec4<f32>(1.0);
  let sh = -step(h, vec4<f32>(0.0));
  let a0 = b0.xzyw + s0.xzyw * sh.xxyy;
  let aVec1 = bVec1.xzyw + sVec1.xzyw * sh.zzww;
  var p0 = vec3<f32>(a0.xy, h.x);
  var p1 = vec3<f32>(a0.zw, h.y);
  var p2 = vec3<f32>(aVec1.xy, h.z);
  var p3 = vec3<f32>(aVec1.zw, h.w);
  let norm = taylorInvSqrt(vec4<f32>(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
  p0 = p0 * norm.x;
  p1 = p1 * norm.y;
  p2 = p2 * norm.z;
  p3 = p3 * norm.w;
  var m = max(vec4<f32>(0.6) - vec4<f32>(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), vec4<f32>(0.0));
  m = m * m;
  return 42.0 * dot(m * m, vec4<f32>(dot(p0, x0), dot(p1, x1), dot(p2, x2), dot(p3, x3)));
}

fn hsv2rgb(hsv: vec3<f32>) -> vec3<f32> {
  let h = fract(hsv.x);
  let s = hsv.y;
  let v = hsv.z;
  let c = v * s;
  let x = c * (1.0 - abs(mod_f32(h * 6.0, 2.0) - 1.0));
  let m = v - c;
  var rgb: vec3<f32>;
  if (0.0 <= h && h < 1.0/6.0) {
    rgb = vec3<f32>(c, x, 0.0);
  } else if (1.0/6.0 <= h && h < 2.0/6.0) {
    rgb = vec3<f32>(x, c, 0.0);
  } else if (2.0/6.0 <= h && h < 3.0/6.0) {
    rgb = vec3<f32>(0.0, c, x);
  } else if (3.0/6.0 <= h && h < 4.0/6.0) {
    rgb = vec3<f32>(0.0, x, c);
  } else if (4.0/6.0 <= h && h < 5.0/6.0) {
    rgb = vec3<f32>(x, 0.0, c);
  } else if (5.0/6.0 <= h && h < 1.0) {
    rgb = vec3<f32>(c, 0.0, x);
  } else {
    rgb = vec3<f32>(0.0);
  }
  return rgb + vec3<f32>(m, m, m);
}

fn fbm(p: vec3<f32>, offset: f32, ridged: i32) -> f32 {
  let MAX_OCT: i32 = 6;
  var amplitude: f32 = 0.5;
  var frequency: f32 = 1.0;
  var sum: f32 = 0.0;
  for (var i: i32 = 0; i < MAX_OCT; i = i + 1) {
    if (i >= octaves) { break; }
    let animatedOffset = vec3<f32>(seed + offset + f32(i) * 10.0);
    var n = snoise(p * frequency + animatedOffset);
    if (ridged == 1) {
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
fn main(@builtin(position) position: vec4<f32>) -> @location(0) vec4<f32> {
  var st = position.xy / resolution;
  st.x = st.x * aspect;
  st = st * scale;
  let t = time + offset;
  let p = vec3<f32>(st, t);
  var r: f32;
  var g: f32;
  var b: f32;
  if (colorMode == 2 && ridged != 0) {
    r = fbm(p, 0.0, 0);
    g = fbm(p, 100.0, 0);
    b = fbm(p, 200.0, ridged);
  } else {
    r = fbm(p, 0.0, ridged);
    g = fbm(p, 100.0, ridged);
    b = fbm(p, 200.0, ridged);
  }
  var col: vec3<f32>;
  if (colorMode == 0) {
    let v = r * 0.5 + 0.5;
    col = vec3<f32>(v);
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
  return vec4<f32>(col, 1.0);
}
