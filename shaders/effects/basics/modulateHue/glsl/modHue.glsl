#version 300 es
precision highp float;

uniform sampler2D tex0;
uniform sampler2D tex1;
uniform float amount;

out vec4 fragColor;

/* Shifts hue based on modulator's red channel. */
vec3 rgb2hsv(vec3 c){
  vec4 K = vec4(0., -1./3., 2./3., -1.);
  vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
  vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
  float d = q.x - min(q.w, q.y);
  float e = 1e-10;
  return vec3(abs((q.w - q.y)/(6. * d + e)), d/(q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c){
  vec4 K = vec4(1., 2./3., 1./3., 3.);
  vec3 p = abs(fract(c.xxx + K.xyz) * 6. - K.www);
  return c.z * mix(K.xxx, clamp(p - K.xxx, 0., 1.), c.y);
}

void main(){
  vec2 st = gl_FragCoord.xy / vec2(textureSize(tex0,0));
  vec4 base = texture(tex0, st);
  vec4 m = texture(tex1, st);
  vec3 hsv = rgb2hsv(base.rgb);
  hsv.x = fract(hsv.x + (m.r - 0.5) * amount);
  vec3 rgb = hsv2rgb(hsv);
  fragColor = vec4(rgb, 1.0);
}

