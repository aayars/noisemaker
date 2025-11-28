// Shadow sharpen pass
// Matches shadowSharpen.glsl (GPGPU fragment shader)

const SHARPEN_KERNEL: array<f32, 9> = array<f32, 9>(
    0.0, -1.0, 0.0,
    -1.0, 5.0, -1.0,
    0.0, -1.0, 0.0
);

@group(0) @binding(0) var gradientTexture: texture_2d<f32>;

fn wrapCoord(value: i32, size: i32) -> i32 {
    if (size <= 0) {
        return 0;
    }
    var wrapped = value % size;
    if (wrapped < 0) {
        wrapped += size;
    }
    return wrapped;
}

@fragment
fn main(@builtin(position) fragCoord: vec4<f32>) -> @location(0) vec4<f32> {
    let dimensions = textureDimensions(gradientTexture);
    if (dimensions.x == 0u || dimensions.y == 0u) {
        return vec4<f32>(0.0);
    }

    let coord = vec2<i32>(fragCoord.xy);

    var accum: f32 = 0.0;
    var kernelIndex: i32 = 0;
    for (var ky = -1; ky <= 1; ky++) {
        for (var kx = -1; kx <= 1; kx++) {
            let sampleX = wrapCoord(coord.x + kx, i32(dimensions.x));
            let sampleY = wrapCoord(coord.y + ky, i32(dimensions.y));
            let sampleValue = textureLoad(gradientTexture, vec2<i32>(sampleX, sampleY), 0).r;
            accum += sampleValue * SHARPEN_KERNEL[kernelIndex];
            kernelIndex++;
        }
    }

    let normalized = clamp(accum * 0.5 + 0.5, 0.0, 1.0);
    return vec4<f32>(normalized, normalized, normalized, 1.0);
}
