#version 300 es
precision highp float;

uniform vec2 resolution;
uniform float aspect;
uniform float x;
uniform float y;
uniform sampler2D tex0;

out vec4 fragColor;

/* Offsets texture coordinates. */
void main(){
  vec2 st = gl_FragCoord.xy / resolution;
  st.x *= aspect;
  st -= vec2(x * aspect, y);
  st.x /= aspect;
  fragColor = vec4(texture(tex0, st).rgb, 1.0);
}
