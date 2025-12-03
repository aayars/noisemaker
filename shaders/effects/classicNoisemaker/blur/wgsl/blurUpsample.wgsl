// Blur upsample pass - reads from 64x64 downsampled texture and interpolates to full resolution

@group(0) @binding(0) var downsampleTex: texture_2d<f32>;
@group(0) @binding(1) var inputTex: texture_2d<f32>;
// amount not used in upsample pass
@group(0) @binding(2) var<uniform> splineOrder: f32;

const PI: f32 = 3.14159265358979323846;

fn interpolationWeight(value: f32, order: i32) -> f32 {
    if (order == 2) { // Cosine
        let clamped: f32 = clamp(value, 0.0, 1.0);
        return (1.0 - cos(clamped * PI)) * 0.5;
    }
    return clamp(value, 0.0, 1.0); // Linear
}

// Cubic interpolation weights (Catmull-Rom)
fn cubicWeight(t: f32, index: i32) -> f32 {
    let t2: f32 = t * t;
    let t3: f32 = t2 * t;
    if (index == 0) { return -0.5 * t3 + t2 - 0.5 * t; }
    if (index == 1) { return 1.5 * t3 - 2.5 * t2 + 1.0; }
    if (index == 2) { return -1.5 * t3 + 2.0 * t2 + 0.5 * t; }
    return 0.5 * t3 - 0.5 * t2; // index == 3
}

fn readDownsample(coord: vec2<i32>, downSize: vec2<i32>) -> vec4<f32> {
    let safeX: i32 = clamp(coord.x, 0, downSize.x - 1);
    let safeY: i32 = clamp(coord.y, 0, downSize.y - 1);
    return textureLoad(downsampleTex, vec2<i32>(safeX, safeY), 0);
}

@fragment
fn main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // Output is full resolution, input is 64x64 downsample buffer
    let outputSize: vec2<u32> = textureDimensions(inputTex, 0);
    let downSize: vec2<i32> = vec2<i32>(64, 64);
    
    let coord: vec2<i32> = vec2<i32>(i32(pos.x), i32(pos.y));
    
    // Map output coordinate to downsample space
    let scaleX: f32 = f32(downSize.x) / f32(outputSize.x);
    let scaleY: f32 = f32(downSize.y) / f32(outputSize.y);
    
    let srcX: f32 = (f32(coord.x) + 0.5) * scaleX - 0.5;
    let srcY: f32 = (f32(coord.y) + 0.5) * scaleY - 0.5;
    
    let baseX: i32 = i32(floor(srcX));
    let baseY: i32 = i32(floor(srcY));
    
    let fracX: f32 = srcX - f32(baseX);
    let fracY: f32 = srcY - f32(baseY);
    
    let order: i32 = i32(splineOrder);
    
    if (order == 0) {
        // Constant - nearest neighbor
        return readDownsample(vec2<i32>(i32(srcX + 0.5), i32(srcY + 0.5)), downSize);
    } else if (order == 3) {
        // Bicubic interpolation (Catmull-Rom)
        var result: vec4<f32> = vec4<f32>(0.0);
        for (var j: i32 = 0; j < 4; j = j + 1) {
            for (var i: i32 = 0; i < 4; i = i + 1) {
                let sampleVal: vec4<f32> = readDownsample(vec2<i32>(baseX + i - 1, baseY + j - 1), downSize);
                let weight: f32 = cubicWeight(fracX, i) * cubicWeight(fracY, j);
                result = result + sampleVal * weight;
            }
        }
        return result;
    } else {
        // Linear/Cosine interpolation (order 1 or 2)
        let tl: vec4<f32> = readDownsample(vec2<i32>(baseX, baseY), downSize);
        let tr: vec4<f32> = readDownsample(vec2<i32>(baseX + 1, baseY), downSize);
        let bl: vec4<f32> = readDownsample(vec2<i32>(baseX, baseY + 1), downSize);
        let br: vec4<f32> = readDownsample(vec2<i32>(baseX + 1, baseY + 1), downSize);
        
        let wx: f32 = interpolationWeight(fracX, order);
        let wy: f32 = interpolationWeight(fracY, order);
        
        let top: vec4<f32> = mix(tl, tr, wx);
        let bottom: vec4<f32> = mix(bl, br, wx);
        return mix(top, bottom, wy);
    }
}
