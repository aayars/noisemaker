#version 300 es
precision highp float;

uniform vec2 resolution;
uniform float aspect;
uniform float time;
uniform float scale;
uniform float speed;
uniform float blend;

out vec4 fragColor;

/* Simple animated Voronoi pattern written from scratch for the Polymorphic DSL. */
vec2 hash(vec2 p) {
  // pseudo random, similar to value noise but original implementation
  p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
  return fract(sin(p) * 43758.5453123);
}

void main() {
  vec2 st = gl_FragCoord.xy / resolution;
  st.x *= aspect;
  st *= scale;
  vec2 i_st = floor(st);
  vec2 f_st = fract(st);
  float minDist = 1.0;
  vec2 best = vec2(0.0);
  for (int y=-1; y<=1; y++) {
    for (int x=-1; x<=1; x++) {
      vec2 neighbor = vec2(float(x), float(y));
      vec2 point = hash(i_st + neighbor);
      // animate feature points
      point = 0.5 + 0.5*sin(time * speed + 6.2831*point);
      vec2 diff = neighbor + point - f_st;
      float dist = dot(diff,diff);
      if (dist < minDist) {
        minDist = dist;
        best = point;
      }
    }
  }
  float edge = sqrt(minDist);
  vec3 cellColor = vec3(best, 0.0);
  vec3 color = mix(vec3(edge), cellColor, blend);
  fragColor = vec4(color, 1.0);
}
