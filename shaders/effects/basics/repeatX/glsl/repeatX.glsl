#version 300 es
precision highp float;

uniform vec2 resolution;
uniform float aspect;
uniform float x;
uniform float offset;
uniform sampler2D tex0;

out vec4 fragColor;

/* Repeats the input texture along the X axis. */
void main(){
  vec2 st = gl_FragCoord.xy / resolution;
  st.x *= aspect;
  st.x = st.x * x + offset * aspect;
  st.x /= aspect;
  st.x = fract(st.x);
  fragColor = vec4(texture(tex0, st).rgb, 1.0);
}
