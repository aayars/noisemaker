// Simple frame mask derived from the Chebyshev distance singularity in the Python reference.
// Applies a binary blend between the source image and a constant brightness value.

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
}

@group(0) @binding(0) var inputTex: texture_2d<f32>;
@group(0) @binding(1) var<uniform> brightness: f32;

const BORDER_BLEND: f32 = 0.55;

fn axis_min_max(size: u32, size_f: f32) -> vec2<f32> {
    if (size <= 1u) {
        return vec2<f32>(0.5, 0.5);
    }
    if ((size & 1u) == 0u) {
        return vec2<f32>(0.0, 0.5);
    }
    
    let half_floor = f32(size / 2u);
    let min_val = 0.5 / size_f;
    let max_val = (half_floor - 0.5) / size_f;
    return vec2<f32>(min_val, max_val);
}

fn axis_distance(coord: f32, center: f32, dimension: f32) -> f32 {
    if (dimension <= 0.0) {
        return 0.0;
    }
    return abs(coord - center) / dimension;
}

fn posterize_level_one(value: f32) -> f32 {
    let scaled = value * BORDER_BLEND;
    return clamp(floor(scaled + 0.5), 0.0, 1.0);
}

@fragment
fn main(in: VertexOutput) -> @location(0) vec4<f32> {
    let dims = textureDimensions(inputTex);
    let coord = vec2<i32>(in.position.xy);
    
    let width_u = dims.x;
    let height_u = dims.y;
    let width_f = f32(width_u);
    let height_f = f32(height_u);
    let center_x = width_f * 0.5;
    let center_y = height_f * 0.5;
    
    let fx = f32(coord.x);
    let fy = f32(coord.y);
    let dx = axis_distance(fx, center_x, width_f);
    let dy = axis_distance(fy, center_y, height_f);
    
    let axis_x = axis_min_max(width_u, width_f);
    let axis_y = axis_min_max(height_u, height_f);
    let min_dist = max(axis_x.x, axis_y.x);
    let max_dist = max(axis_x.y, axis_y.y);
    let dist = max(dx, dy);
    let delta = max_dist - min_dist;
    
    var normalized: f32;
    if (delta > 0.0) {
        normalized = clamp((dist - min_dist) / delta, 0.0, 1.0);
    } else {
        normalized = clamp(dist, 0.0, 1.0);
    }
    
    let ramp = sqrt(normalized);
    let mask = posterize_level_one(ramp);
    
    let srcSample = textureLoad(inputTex, coord, 0);
    
    // Brightness affects both the frame color and blends into the image
    // Scale brightness from [-1,1] to usable range, affecting the blend more directly
    let brightnessScaled = brightness * 0.5 + 0.5;  // Map to [0,1]
    let frameColor = vec3<f32>(brightnessScaled);
    
    // Apply frame blend - mask determines how much frame shows
    // Also apply subtle brightness influence to non-frame area
    var blended_rgb = mix(srcSample.xyz, frameColor, mask);
    blended_rgb = blended_rgb + vec3<f32>(brightness * 0.1 * (1.0 - mask));  // Subtle brightness effect on image
    blended_rgb = clamp(blended_rgb, vec3<f32>(0.0), vec3<f32>(1.0));
    
    return vec4<f32>(blended_rgb, srcSample.w);
}
