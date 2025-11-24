#version 300 es
precision highp float;

uniform sampler2D tex0;
uniform sampler2D tex1;
uniform float amount;

out vec4 fragColor;

/* Linear interpolation between two textures. */
void main(){
  vec2 st = gl_FragCoord.xy / vec2(textureSize(tex0,0));
  vec4 a = texture(tex0, st);
  vec4 b = texture(tex1, st);
  vec3 rgb = mix(a.rgb, b.rgb, amount);
  fragColor = vec4(rgb, 1.0);
}
