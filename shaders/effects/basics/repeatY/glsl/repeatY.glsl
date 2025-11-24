#version 300 es
precision highp float;

uniform vec2 resolution;
uniform float aspect;
uniform float y;
uniform float offset;
uniform sampler2D tex0;

out vec4 fragColor;

/* Repeats the input texture along the Y axis. */
void main(){
  vec2 st = gl_FragCoord.xy / resolution;
  st.x *= aspect;
  st.y = st.y * y + offset;
  st.x /= aspect;
  st.y = fract(st.y);
  fragColor = vec4(texture(tex0, st).rgb, 1.0);
}
