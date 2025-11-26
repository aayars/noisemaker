#version 300 es

precision highp float;
precision highp int;

// Multi-octave image "reverberation" effect mirroring the original compute shader.
// The shader optionally ridge-transforms the input image and accumulates tiled,
// downsampled layers across the requested octaves and iterations. Each layer
// averages the contributing source pixels so the result matches the reference
// proportional downsample + expand tile CPU implementation.

uniform sampler2D inputTex;
uniform int octaves;
uniform int iterations;
uniform bool ridges;

out vec4 fragColor;

int wrap_index(int value, int limit) {
	if (limit <= 0) {
		return 0;
	}
	int wrapped = value % limit;
	if (wrapped < 0) {
		wrapped += limit;
	}
	return wrapped;
}

int clamp_coord(int coord, int limit) {
	return clamp(coord, 0, max(limit - 1, 0));
}

vec4 ridge_transform(vec4 color) {
	return vec4(1.0) - abs(color * 2.0 - vec4(1.0));
}

vec4 load_source_pixel(ivec2 coord, ivec2 dims) {
	int safe_x = clamp_coord(coord.x, dims.x);
	int safe_y = clamp_coord(coord.y, dims.y);
	return texelFetch(inputTex, ivec2(safe_x, safe_y), 0);
}

vec4 load_reference_pixel(ivec2 coord, ivec2 dims, bool use_ridges) {
	vec4 src = load_source_pixel(coord, dims);
	return use_ridges ? ridge_transform(src) : src;
}

int compute_kernel_size(int dimension, int downsampled) {
	if (downsampled <= 0) {
		return 0;
	}
	int ratio = dimension / downsampled;
	return max(ratio, 1);
}

int compute_block_start(int tile_index, int kernel, int dimension) {
	if (kernel <= 0 || dimension <= 0) {
		return 0;
	}
	int max_start = max(dimension - kernel, 0);
	int unclamped = tile_index * kernel;
	return clamp(unclamped, 0, max_start);
}

vec4 downsampled_value(ivec2 tile, ivec2 dims, ivec2 down_dims, bool use_ridges) {
	int kernel_w = compute_kernel_size(dims.x, down_dims.x);
	int kernel_h = compute_kernel_size(dims.y, down_dims.y);
	if (kernel_w <= 0 || kernel_h <= 0) {
		return vec4(0.0);
	}

	int start_x = compute_block_start(tile.x, kernel_w, dims.x);
	int start_y = compute_block_start(tile.y, kernel_h, dims.y);

	vec4 sum = vec4(0.0);
	for (int ky = 0; ky < kernel_h; ++ky) {
		int sample_y = start_y + ky;
		for (int kx = 0; kx < kernel_w; ++kx) {
			int sample_x = start_x + kx;
			sum += load_reference_pixel(ivec2(sample_x, sample_y), dims, use_ridges);
		}
	}

	int sample_count = kernel_w * kernel_h;
	if (sample_count <= 0) {
		return vec4(0.0);
	}

	return sum / float(sample_count);
}

float clamp01(float value) {
	return clamp(value, 0.0, 1.0);
}

void main() {
	ivec2 dims = textureSize(inputTex, 0);
	if (dims.x <= 0 || dims.y <= 0) {
		fragColor = vec4(0.0);
		return;
	}

	ivec2 gid = ivec2(int(gl_FragCoord.x), int(gl_FragCoord.y));
	if (gid.x < 0 || gid.x >= dims.x || gid.y < 0 || gid.y >= dims.y) {
		fragColor = vec4(0.0);
		return;
	}

	bool use_ridges = ridges;
	vec4 source_texel = load_source_pixel(gid, dims);
	vec4 accum = load_reference_pixel(gid, dims, use_ridges);
	float weight_sum = 1.0;

	int iter_count = max(iterations, 0);
	int octave_count = max(octaves, 0);

	if (iter_count > 0 && octave_count > 0) {
		for (int iter = 0; iter < iter_count; ++iter) {
			for (int octave = 1; octave <= octave_count; ++octave) {
				int clamped_octave = min(octave, 30);
				uint multiplier_u = 1u << uint(clamped_octave);
				if (multiplier_u == 0u) {
					continue;
				}
				int multiplier = max(int(multiplier_u), 1);

				int down_width = max(dims.x / multiplier, 1);
				int down_height = max(dims.y / multiplier, 1);
				if (down_width <= 0 || down_height <= 0) {
					break;
				}

				int offset_x = down_width / 2;
				int offset_y = down_height / 2;
				int tile_x = wrap_index(gid.x + offset_x, down_width);
				int tile_y = wrap_index(gid.y + offset_y, down_height);

				vec4 averaged = downsampled_value(
					ivec2(tile_x, tile_y),
					dims,
					ivec2(down_width, down_height),
					use_ridges
				);

				float weight = 1.0 / float(multiplier);
				accum += averaged * weight;
				weight_sum += weight;
			}
		}
	}

	if (weight_sum > 0.0) {
		accum /= weight_sum;
	}

	vec3 rgb = vec3(clamp01(accum.x), clamp01(accum.y), clamp01(accum.z));
	fragColor = vec4(rgb, 1.0);
}
