#version 300 es
precision highp float;

uniform sampler2D tex0;
uniform float a;

out vec4 fragColor;

/* Simple contrast shift around 0.5. */
void main(){
  vec2 st = gl_FragCoord.xy / vec2(textureSize(tex0,0));
  vec4 c = texture(tex0, st);
  vec3 rgb = (c.rgb - 0.5) * a + 0.5;
  fragColor = vec4(rgb,1.0);
}
