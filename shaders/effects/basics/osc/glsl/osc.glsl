#version 300 es
precision highp float;

uniform vec2 resolution;
uniform float aspect;
uniform float time;
uniform float freq;
uniform float sync;
uniform float amp;

out vec4 fragColor;

/* Inspired by the idea of Hydra's osc: a time-varying sine pattern, reimplemented from scratch. */
void main() {
  vec2 st = gl_FragCoord.xy / resolution;
  st.x *= aspect;
  float phase = st.x * freq + time * sync;
  float r = sin(phase) * 0.5 + 0.5;
  float g = sin(phase + 2.0) * 0.5 + 0.5;
  float b = sin(phase + 4.0) * 0.5 + 0.5;
  vec3 wave = vec3(r, g, b);
  float mixAmount = max(clamp(amp, 0.0, 1.0), 0.1);
  vec3 base = vec3(0.5);
  vec3 col = mix(base, wave, mixAmount);
  fragColor = vec4(col, 1.0);
}
