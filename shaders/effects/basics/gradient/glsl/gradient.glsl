#version 300 es
precision highp float;

uniform vec2 resolution;
uniform float aspect;
uniform float time;
uniform float speed;

out vec4 fragColor;

/*
 * Horizontal gradient with time-based hue rotation.
 * The speed argument controls rotation rate.
 * Starts with red on the left and green on the top, matching the
 * original red/green gradient.
 */
const mat3 rgb2yiq = mat3(
  0.299, 0.587, 0.114,
  0.596, -0.275, -0.321,
  0.212, -0.523, 0.311
);
const mat3 yiq2rgb = mat3(
  1.0, 0.956, 0.621,
  1.0, -0.272, -0.647,
  1.0, -1.107, 1.704
);

void main(){
  vec2 st = gl_FragCoord.xy / resolution;
  st.x *= aspect;
  vec3 base = vec3(st.x, st.y, 0.0);

  float angle = time * speed * 6.2831853; // 2π
  vec3 yiq = rgb2yiq * base;
  float cosA = cos(angle);
  float sinA = sin(angle);
  yiq = vec3(yiq.x,
             yiq.y * cosA - yiq.z * sinA,
             yiq.y * sinA + yiq.z * cosA);

  vec3 col = clamp(yiq2rgb * yiq, 0.0, 1.0);
  fragColor = vec4(col, 1.0);
}
