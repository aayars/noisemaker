#version 300 es
precision highp float;

uniform sampler2D tex0;
uniform sampler2D tex1;

out vec4 fragColor;

/* Overlays tex1 atop tex0 using tex1 alpha. */
void main(){
  vec2 st = gl_FragCoord.xy / vec2(textureSize(tex0,0));
  vec4 a = texture(tex0, st);
  vec4 b = texture(tex1, st);
  vec3 rgb = mix(a.rgb, b.rgb, b.a);
  fragColor = vec4(rgb, 1.0);
}
