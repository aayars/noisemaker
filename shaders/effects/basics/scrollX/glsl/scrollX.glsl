#version 300 es
precision highp float;

uniform vec2 resolution;
uniform float aspect;
uniform float x;
uniform float speed;
uniform float time;
uniform sampler2D tex0;

out vec4 fragColor;

/* Scrolls texture horizontally with wraparound. */
void main(){
  vec2 st = gl_FragCoord.xy / resolution;
  st.x *= aspect;
  float shift = (x + time * speed) * aspect;
  st.x += shift;
  st.x /= aspect;
  st = fract(st);
  fragColor = vec4(texture(tex0, st).rgb, 1.0);
}
