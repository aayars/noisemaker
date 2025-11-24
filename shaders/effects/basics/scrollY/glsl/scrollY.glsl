#version 300 es
precision highp float;

uniform vec2 resolution;
uniform float aspect;
uniform float y;
uniform float speed;
uniform float time;
uniform sampler2D tex0;

out vec4 fragColor;

/* Scrolls texture vertically with wraparound. */
void main(){
  vec2 st = gl_FragCoord.xy / resolution;
  st.x *= aspect;
  float shift = y + time * speed;
  st += vec2(0.0, shift);
  st.x /= aspect;
  st = fract(st);
  fragColor = vec4(texture(tex0, st).rgb, 1.0);
}
