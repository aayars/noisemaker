#version 300 es

precision highp float;
precision highp int;

// Warp effect - multi-octave displacement using noise

uniform sampler2D inputTex;
uniform float time;
uniform float speed;
uniform float displacement;
uniform float frequency;
uniform float octaves;
uniform float spline_order;

in vec2 v_texCoord;
out vec4 fragColor;

const float PI = 3.14159265358979;
const float TAU = 6.28318530717959;

// Hash functions
float hash21(vec2 p) {
    float h = dot(p, vec2(127.1, 311.7));
    return fract(sin(h) * 43758.5453123);
}

vec2 hash22(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Simplex-like noise for smoother results
float simplexNoise(vec2 p, float t) {
    float n = noise(p + t * 0.1);
    n += noise(p * 2.0 - t * 0.15) * 0.5;
    n += noise(p * 4.0 + t * 0.2) * 0.25;
    return n / 1.75;
}

float wrapFloat(float value, float limit) {
    if (limit <= 0.0) return 0.0;
    float result = mod(value, limit);
    if (result < 0.0) result += limit;
    return result;
}

void main() {
    vec2 dims = vec2(textureSize(inputTex, 0));
    float width = dims.x;
    float height = dims.y;
    
    // Adjust frequency for aspect ratio
    vec2 freq = vec2(frequency);
    if (width > height && height > 0.0) {
        freq.y = frequency * width / height;
    } else if (height > width && width > 0.0) {
        freq.x = frequency * height / width;
    }
    
    vec2 sampleCoord = v_texCoord * dims;
    
    int numOctaves = max(int(octaves), 1);
    float displaceBase = displacement;
    
    // Multi-octave warping
    for (int octave = 1; octave <= 8; octave++) {
        if (octave > numOctaves) break;
        
        float multiplier = pow(2.0, float(octave));
        vec2 freqScaled = freq * 0.5 * multiplier;
        
        if (freqScaled.x >= width || freqScaled.y >= height) break;
        
        // Compute reference angles from noise
        vec2 noiseCoord = v_texCoord * freqScaled;
        float refX = simplexNoise(noiseCoord + vec2(17.0, 29.0), time * speed);
        float refY = simplexNoise(noiseCoord + vec2(23.0, 31.0), time * speed);
        
        // Convert to signed range
        refX = refX * 2.0 - 1.0;
        refY = refY * 2.0 - 1.0;
        
        // Calculate displacement
        float displaceScale = displaceBase / multiplier;
        vec2 offset = vec2(refX * displaceScale * width, refY * displaceScale * height);
        
        sampleCoord += offset;
        sampleCoord = vec2(
            wrapFloat(sampleCoord.x, width),
            wrapFloat(sampleCoord.y, height)
        );
    }
    
    // Sample with wrapping
    vec2 uv = sampleCoord / dims;
    uv = fract(uv);
    
    vec4 sampled = texture(inputTex, uv);
    
    fragColor = sampled;
}
