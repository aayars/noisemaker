#version 300 es
precision highp float;

uniform vec2 resolution;
uniform float aspect;
uniform float time;
uniform float scale;
uniform float offset;
uniform float seed;
uniform int octaves;
uniform int colorMode;
uniform float hueRotation;
uniform float hueRange;
uniform int ridged;

out vec4 fragColor;

/* 3D simplex noise implementation based on the Ashima Arts reference (MIT License).
   Animated by treating time as the third dimension. */

vec3 mod289(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 mod289(vec4 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 permute(vec4 x) { return mod289(((x * 34.0) + 1.0) * x); }
vec4 taylorInvSqrt(vec4 r) { return 1.79284291400159 - 0.85373472095314 * r; }

float snoise(vec3 v) {
  const vec2 C = vec2(1.0 / 6.0, 1.0 / 3.0);
  const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);

  // First corner
  vec3 i  = floor(v + dot(v, C.yyy));
  vec3 x0 = v - i + dot(i, C.xxx);

  // Other corners
  vec3 g = step(x0.yzx, x0.xyz);
  vec3 l = 1.0 - g;
  vec3 i1 = min(g.xyz, l.zxy);
  vec3 i2 = max(g.xyz, l.zxy);

  vec3 x1 = x0 - i1 + C.xxx;
  vec3 x2 = x0 - i2 + C.yyy;
  vec3 x3 = x0 - D.yyy;

  // Permutations
  i = mod289(i);
  vec4 p = permute(
    permute(
      permute(i.z + vec4(0.0, i1.z, i2.z, 1.0))
      + i.y + vec4(0.0, i1.y, i2.y, 1.0)
    )
    + i.x + vec4(0.0, i1.x, i2.x, 1.0)
  );

  // Gradients
  float n_ = 0.142857142857; // 1/7
  vec3  ns = n_ * D.wyz - D.xzx;

  vec4 j = p - 49.0 * floor(p * ns.z * ns.z);

  vec4 x_ = floor(j * ns.z);
  vec4 y_ = floor(j - 7.0 * x_);

  vec4 x = x_ * ns.x + ns.y;
  vec4 y = y_ * ns.x + ns.y;
  vec4 h = 1.0 - abs(x) - abs(y);

  vec4 b0 = vec4(x.xy, y.xy);
  vec4 bVec1 = vec4(x.zw, y.zw);

  vec4 s0 = floor(b0) * 2.0 + 1.0;
  vec4 sVec1 = floor(bVec1) * 2.0 + 1.0;
  vec4 sh = -step(h, vec4(0.0));

  vec4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
  vec4 aVec1 = bVec1.xzyw + sVec1.xzyw * sh.zzww;

  vec3 p0 = vec3(a0.xy, h.x);
  vec3 p1 = vec3(a0.zw, h.y);
  vec3 p2 = vec3(aVec1.xy, h.z);
  vec3 p3 = vec3(aVec1.zw, h.w);

  vec4 norm = taylorInvSqrt(vec4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
  p0 *= norm.x;
  p1 *= norm.y;
  p2 *= norm.z;
  p3 *= norm.w;

  vec4 m = max(0.6 - vec4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
  m = m * m;
  return 42.0 * dot(m * m, vec4(dot(p0, x0), dot(p1, x1), dot(p2, x2), dot(p3, x3)));
}

vec3 hsv2rgb(vec3 hsv) {
  float h = fract(hsv.x);
  float s = hsv.y;
  float v = hsv.z;

  float c = v * s;
  float x = c * (1.0 - abs(mod(h * 6.0, 2.0) - 1.0));
  float m = v - c;

  vec3 rgb;
  if (0.0 <= h && h < 1.0/6.0) {
    rgb = vec3(c, x, 0.0);
  } else if (1.0/6.0 <= h && h < 2.0/6.0) {
    rgb = vec3(x, c, 0.0);
  } else if (2.0/6.0 <= h && h < 3.0/6.0) {
    rgb = vec3(0.0, c, x);
  } else if (3.0/6.0 <= h && h < 4.0/6.0) {
    rgb = vec3(0.0, x, c);
  } else if (4.0/6.0 <= h && h < 5.0/6.0) {
    rgb = vec3(x, 0.0, c);
  } else if (5.0/6.0 <= h && h < 1.0) {
    rgb = vec3(c, 0.0, x);
  } else {
    rgb = vec3(0.0);
  }

  return rgb + vec3(m, m, m);
}

float fbm(vec3 p, float offset, int ridged) {
  const int MAX_OCT = 6;
  float amplitude = 0.5;
  float frequency = 1.0;
  float sum = 0.0;
  int oct = octaves;
  if (oct < 1) oct = 1;
  for (int i = 0; i < MAX_OCT; i++) {
    if (i >= oct) break;
    float n = snoise(p * frequency + seed + offset + float(i) * 10.0);
    if (ridged == 1) {
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
  vec2 res = resolution;
  if (res.x < 1.0) res = vec2(1024.0, 1024.0);
  vec2 st = gl_FragCoord.xy / res;
  st.x *= aspect;
  st *= scale;
  float t = time + offset;
  vec3 p = vec3(st, t);
  float r;
  float g;
  float b;
  if (colorMode == 2 && ridged != 0) {
    r = fbm(p, 0.0, 0);
    g = fbm(p, 100.0, 0);
    b = fbm(p, 200.0, ridged);
  } else {
    r = fbm(p, 0.0, ridged);
    g = fbm(p, 100.0, ridged);
    b = fbm(p, 200.0, ridged);
  }
  vec3 col;
  if (colorMode == 0) {
    float v = r * 0.5 + 0.5;
    col = vec3(v);
  } else if (colorMode == 1) {
    col = vec3(r, g, b) * 0.5 + 0.5;
  } else {
    float h = r * 0.5 + 0.5;
    h = h * (hueRange * 0.01);
    h += 1.0 - (hueRotation / 360.0);
    h = fract(h);
    float s = g * 0.5 + 0.5;
    float v = b * 0.5 + 0.5;
    col = hsv2rgb(vec3(h, s, v));
  }
  fragColor = vec4(col, 1.0);
}

