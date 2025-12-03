#version 300 es
precision highp float;

uniform sampler2D tex0;
uniform sampler2D tex1;

out vec4 fragColor;

/* Uses tex1 red channel as alpha mask for tex0. */
void main(){
  vec2 st = gl_FragCoord.xy / vec2(textureSize(tex0,0));
  vec4 a = texture(tex0, st);
  float m = texture(tex1, st).r;
  fragColor = vec4(a.rgb * m, 1.0);
}
