/*
 * Lens distortion (barrel/pincushion)
 * Warps sample coordinates radially around the frame center
 */

#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D inputTex;
uniform float lensDisplacement;

out vec4 fragColor;

const float HALF_FRAME = 0.5;
const float MAX_DISTANCE = 0.7071067811865476; // sqrt(0.5*0.5 + 0.5*0.5)

void main() {
    ivec2 texSize = textureSize(inputTex, 0);
    vec2 dims = vec2(texSize);
    vec2 uv = gl_FragCoord.xy / dims;
    
    // Zoom for negative displacement (pincushion)
    float zoom = (lensDisplacement < 0.0) ? (lensDisplacement * -0.25) : 0.0;
    
    // Distance from center
    vec2 dist = uv - HALF_FRAME;
    float distFromCenter = length(dist);
    float normalizedDist = clamp(distFromCenter / MAX_DISTANCE, 0.0, 1.0);
    
    // Stronger effect near edges, weaker at center
    float centerWeight = 1.0 - normalizedDist;
    float centerWeightSq = centerWeight * centerWeight;
    
    // Apply radial distortion
    vec2 offset = uv - dist * zoom - dist * centerWeightSq * lensDisplacement;
    
    // Wrap coordinates
    offset = fract(offset);

    fragColor = texture(inputTex, offset);
}
