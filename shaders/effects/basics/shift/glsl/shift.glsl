#version 300 es
precision highp float;

uniform sampler2D tex0;
uniform float r;
uniform float g;
uniform float b;
uniform float a;

out vec4 fragColor;

/* Offsets each color channel by sampling nearby texels. */
void main(){
  vec2 texSize = vec2(textureSize(tex0, 0));
  if (texSize.x <= 0.0 || texSize.y <= 0.0) {
    fragColor = vec4(0.0);
    return;
  }

  vec2 uv = gl_FragCoord.xy / texSize;
  float scale = max(0.0, 1.0 + a);

  vec2 sampleR = fract(uv + vec2(r, 0.0) * scale);
  vec2 sampleG = fract(uv + vec2(g, 0.0) * scale);
  vec2 sampleB = fract(uv + vec2(b, 0.0) * scale);

  vec4 base = texture(tex0, uv);
  float red = texture(tex0, sampleR).r;
  float green = texture(tex0, sampleG).g;
  float blue = texture(tex0, sampleB).b;

  fragColor = vec4(red, green, blue, base.a);
}
