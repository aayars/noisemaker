// WGSL version – WebGPU
@group(0) @binding(0) var<uniform> resolution: vec2<f32>;
@group(0) @binding(1) var<uniform> aspect: f32;
@group(0) @binding(2) var<uniform> time: f32;
@group(0) @binding(3) var<uniform> scale: f32;
@group(0) @binding(4) var<uniform> speed: f32;
@group(0) @binding(5) var<uniform> blend: f32;

/* Simple animated Voronoi pattern written from scratch for the Polymorphic DSL. */
fn hash(p: vec2<f32>) -> vec2<f32> {
  let q = vec2<f32>(dot(p, vec2<f32>(127.1, 311.7)), dot(p, vec2<f32>(269.5, 183.3)));
  return fract(sin(q) * 43758.5453123);
}

@fragment
fn main(@builtin(position) position: vec4<f32>) -> @location(0) vec4<f32> {
  var st = position.xy / resolution;
  st.x *= aspect;
  st *= scale;
  let i_st = floor(st);
  let f_st = fract(st);
  var minDist = 1.0;
  var best = vec2<f32>(0.0, 0.0);
  for (var y: i32 = -1; y <= 1; y = y + 1) {
    for (var x: i32 = -1; x <= 1; x = x + 1) {
      let neighbor = vec2<f32>(f32(x), f32(y));
      var point = hash(i_st + neighbor);
      point = 0.5 + 0.5 * sin(time * speed + 6.2831 * point);
      let diff = neighbor + point - f_st;
      let dist = dot(diff, diff);
      if (dist < minDist) {
        minDist = dist;
        best = point;
      }
    }
  }
  let edge = sqrt(minDist);
  let cellColor = vec3<f32>(best, 0.0);
  let color = mix(vec3<f32>(edge), cellColor, blend);
  return vec4<f32>(color, 1.0);
}
