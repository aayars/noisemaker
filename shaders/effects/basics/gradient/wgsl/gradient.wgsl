// WGSL version – WebGPU
@group(0) @binding(0) var<uniform> resolution: vec2<f32>;
@group(0) @binding(1) var<uniform> aspect: f32;
@group(0) @binding(2) var<uniform> time: f32;
@group(0) @binding(3) var<uniform> speed: f32;

/*
 * Horizontal gradient with time-based hue rotation.
 * The speed argument controls rotation rate.
 * Starts with red on the left and green on the top, matching the
 * original red/green gradient.
 */
const rgb2yiq = mat3x3<f32>(
  vec3<f32>(0.299, 0.587, 0.114),
  vec3<f32>(0.596, -0.275, -0.321),
  vec3<f32>(0.212, -0.523, 0.311)
);
const yiq2rgb = mat3x3<f32>(
  vec3<f32>(1.0, 0.956, 0.621),
  vec3<f32>(1.0, -0.272, -0.647),
  vec3<f32>(1.0, -1.107, 1.704)
);

@fragment
fn main(@builtin(position) position: vec4<f32>) -> @location(0) vec4<f32> {
  var st = position.xy / resolution;
  st.y = 1.0 - st.y;
  st.x = st.x * aspect;
  var base = vec3<f32>(st.x, st.y, 0.0);

  let angle = time * speed * 6.2831853;
  var yiq = rgb2yiq * base;
  let cosA = cos(angle);
  let sinA = sin(angle);
  yiq = vec3<f32>(
    yiq.x,
    yiq.y * cosA - yiq.z * sinA,
    yiq.y * sinA + yiq.z * cosA
  );

  let col = clamp(yiq2rgb * yiq, vec3<f32>(0.0), vec3<f32>(1.0));
  return vec4<f32>(col, 1.0);
}
