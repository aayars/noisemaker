#version 300 es
out vec4 v_color;
precision highp float;

uniform sampler2D inputTex;
uniform int channel;

void main() {
    ivec2 texSize = textureSize(inputTex, 0);
    int width = texSize.x;
    int height = texSize.y;
    
    int pixelIndex = gl_VertexID;
    int x = pixelIndex % width;
    int y = pixelIndex / width;
    
    if (y >= height) {
        gl_Position = vec4(-2.0, -2.0, 0.0, 1.0); // Discard
        return;
    }
    
    vec4 val = texelFetch(inputTex, ivec2(x, y), 0);
    float v = (channel == 0) ? val.r : (channel == 1) ? val.g : (channel == 2) ? val.b : val.a;
    
    // Bucket 0-255
    float bucket = floor(clamp(v, 0.0, 0.9999) * 255.0);
    
    // Map to clip space
    // Texture size is 256 x Height
    // x range [0, 255] -> [-1, 1]
    // y range [0, Height-1] -> [-1, 1]
    // Pixel center offset: +0.5
    
    float ndcX = (bucket + 0.5) / 256.0 * 2.0 - 1.0;
    float ndcY = (float(y) + 0.5) / float(height) * 2.0 - 1.0;
    
    gl_Position = vec4(ndcX, ndcY, 0.0, 1.0);
    gl_PointSize = 1.0;
    
}
