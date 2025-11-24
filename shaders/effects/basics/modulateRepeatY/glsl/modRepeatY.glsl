#version 300 es
precision highp float;

uniform sampler2D tex0;
uniform sampler2D tex1;
uniform float repeatY;
uniform float offsetY;
uniform float amount;

out vec4 fragColor;

/* Repeats the modulator along the Y axis before displacement. */
void main(){
  vec2 st = gl_FragCoord.xy / vec2(textureSize(tex0,0));
  float y = fract(st.y * repeatY + offsetY);
  vec4 m = texture(tex1, vec2(st.x, y));
  st += (m.xy * 2.0 - 1.0) * amount;
  fragColor = vec4(texture(tex0, st).rgb, 1.0);
}

