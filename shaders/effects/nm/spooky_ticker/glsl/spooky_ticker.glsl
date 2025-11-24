#version 300 es

precision highp float;
precision highp int;

// Spooky ticker effect that renders flickering segmented glyphs crawling across the image.
// Mirrors the behaviour of noisemaker.effects.spooky_ticker.

const uint CHANNEL_COUNT = 4u;
const float INV_U32_MAX = 1.0 / 4294967295.0;


uniform sampler2D input_texture;
uniform float width;
uniform float height;
uniform float channels;
uniform float time;
uniform float speed;

const uint MASK_ARECIBO_NUCLEOTIDE = 0u;
const uint MASK_ARECIBO_NUM = 1u;
const uint MASK_BANK_OCR = 2u;
const uint MASK_BAR_CODE = 3u;
const uint MASK_BAR_CODE_SHORT = 4u;
const uint MASK_EMOJI = 5u;
const uint MASK_FAT_LCD_HEX = 6u;
const uint MASK_ALPHANUM_HEX = 7u;
const uint MASK_ICHING = 8u;
const uint MASK_IDEOGRAM = 9u;
const uint MASK_INVADERS = 10u;
const uint MASK_LCD = 11u;
const uint MASK_LETTERS = 12u;
const uint MASK_MATRIX = 13u;
const uint MASK_ALPHANUM_NUMERIC = 14u;
const uint MASK_SCRIPT = 15u;
const uint MASK_WHITE_BEAR = 16u;

const MASK_CHOICES : array<u32, 17> = array<u32, 17>(
const uint MASK_CHOICES_COUNT = 17u;

const HEX_SEGMENTS : array<u32, 16> = array<u32, 16>(


uint as_u32(float value) {
    return uint(max(round(value), 0.0));
}

uint sanitized_channel_count(float channel_value) {
    int rounded = int(round(channel_value));
    if (rounded <= 1) {
        return 1u;
    }
    if (rounded >= int(CHANNEL_COUNT)) {
        return CHANNEL_COUNT;
    }
    return uint(rounded);
}

uint pixel_base_index(uint x, uint y, uint width) {
    return (y * width + x) * CHANNEL_COUNT;
}

int clamp_i32(int value, int lo, int hi) {
    int min_v = lo;
    int max_v = hi;
    if (min_v > max_v) {
        int tmp = min_v;
        min_v = max_v;
        max_v = tmp;
    }
    if (value < min_v) {
        return min_v;
    }
    if (value > max_v) {
        return max_v;
    }
    return value;
}

int wrap_coord(int value, int size) {
    if (size <= 0) {
        return 0;
    }
    int wrapped = value % size;
    if (wrapped < 0) {
        wrapped = wrapped + size;
    }
    return wrapped;
}

uint hash_mix(uint value) {
    uint v = value;
    v = v ^ (v >> 16u);
    v = v * 0x7feb352du;
    v = v ^ (v >> 15u);
    v = v * 0x846ca68bu;
    v = v ^ (v >> 16u);
    return v;
}

uint combine_seed(uint base, uint salt) {
    return hash_mix(base ^ (salt * 0x9e3779b9u + 0x85ebca6bu));
}

uint random_u32(uint base, uint salt) {
    return hash_mix(base ^ salt);
}

float random_float(uint base, uint salt) {
    return float(random_u32(base, salt)) * INV_U32_MAX;
}

int random_int_inclusive(uint base, uint salt, int lo, int hi) {
    if (hi <= lo) {
        return lo;
    }
    uint span = uint(hi - lo + 1);
    if (span == 0u) {
        return lo;
    }
    uint value = random_u32(base, salt);
    return lo + int(value % span);
}

float lerp_f32(float a, float b, float t) {
    return a + (b - a) * t;
}

float mask_noise(uint seed, int x, int y, uint salt) {
    uint packed = (uint(x & 0xffff) << 16) ^ uint(y & 0xffff) ^ (salt * 0x45d9f3b8u);
    return random_float(seed, packed);
}

void digital_segment_value(MaskShape mask_shape(uint mask_type, uint seed) {
    switch mask_type {
        case MASK_ARECIBO_NUCLEOTIDE: {
            return MaskShape(6, 6);
        }
        case MASK_ARECIBO_NUM: {
            return MaskShape(6, 3);
        }
        case MASK_BANK_OCR: {
            return MaskShape(8, 7);
        }
        case MASK_BAR_CODE: {
            return MaskShape(24, 1);
        }
        case MASK_BAR_CODE_SHORT: {
            return MaskShape(10, 1);
        }
        case MASK_EMOJI: {
            return MaskShape(13, 13);
        }
        case MASK_FAT_LCD_HEX: {
            return MaskShape(10, 10);
        }
        case MASK_ALPHANUM_HEX: {
            return MaskShape(6, 6);
        }
        case MASK_ICHING: {
            return MaskShape(14, 8);
        }
        case MASK_IDEOGRAM: {
            int size = random_int_inclusive(seed, 3u, 4, 6) * 2;
            return MaskShape(size, size);
        }
        case MASK_INVADERS: {
            int h = random_int_inclusive(seed, 5u, 5, 7);
            int w = random_int_inclusive(seed, 7u, 6, 12);
            return MaskShape(h, w);
        }
        case MASK_LCD: {
            return MaskShape(8, 5);
        }
        case MASK_LETTERS: {
            int height = random_int_inclusive(seed, 11u, 3, 4) * 2 + 1;
            int width = random_int_inclusive(seed, 13u, 3, 4) * 2 + 1;
            return MaskShape(height, width);
        }
        case MASK_MATRIX: {
            return MaskShape(6, 4);
        }
        case MASK_ALPHANUM_NUMERIC: {
            return MaskShape(6, 6);
        }
        case MASK_SCRIPT: {
            int h = random_int_inclusive(seed, 13u, 7, 9);
            int w = random_int_inclusive(seed, 17u, 12, 24);
            return MaskShape(h, w);
        }
        case MASK_WHITE_BEAR: {
            return MaskShape(4, 4);
        }
        default: {
            return MaskShape(6, 6);
        }
    }
}

int mask_multiplier(uint mask_type, int mask_width) {
    // Uniform larger multiplier for all rows
    return 8;
}

int mask_padding(uint mask_type, int glyph_width) {
    if (glyph_width <= 0) {
        return 0;
    }
    if (mask_type == MASK_BAR_CODE || mask_type == MASK_BAR_CODE_SHORT) {
        return 0;
    }
    // Fixed single trailing pixel gap to mirror Python kerning behaviour.
    return 1;
}

uint digital_pattern(uint mask_type, uint glyph_seed) {
    if (mask_type == MASK_ALPHANUM_HEX || mask_type == MASK_FAT_LCD_HEX) {
        uint index = random_u32(glyph_seed, 23u) % 16u;
        return HEX_SEGMENTS[index];
    }
    uint digit_index = random_u32(glyph_seed, 29u) % 10u;
    return HEX_SEGMENTS[digit_index];
}

void sample_mask_pattern(fn sample_padded_mask(  fn ticker_mask(      // Force maximum rows (3) {

    // Simple approach: each row uses its natural mask height * multiplier, no artificial scaling



        // Use natural mask height * multiplier


            // Direct mapping: row_height pixels map to shape.height * multiplier mask pixels

            // Compute horizontal repeats to fill width
            // Python: width = int(shape[1] / multiplier) quantized to mask_shape[1]
            // Quantize to be evenly divisible by mask width (matches Python line 3007)

            // Each row scrolls independently, with speed proportional to character width

            // Smooth sub-pixel scrolling; positive offset scrolls content to the left.


            // Sample current and next x position for horizontal interpolation

            // Bilinear interpolation for smooth scrolling




float apply_blend(float src, float offset_value, float mask_val, float alpha) {
    float shadow_alpha = alpha * (1.0 / 3.0);
    float first = mix(src, offset_value, shadow_alpha);
    float highlight = max(mask_val, first);
    float final_val = mix(first, highlight, alpha);
    return clamp(final_val, 0.0, 1.0);
}


out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uint width = max(as_u32(width), 1u);
    uint height = max(as_u32(height), 1u);
    if (global_id.x >= width || global_id.y >= height) {
        return;
    }

    int width_i = int(width);
    int height_i = int(height);
    uint channel_count = sanitized_channel_count(channels);

    vec2 coords = vec2(int(global_id.x), int(global_id.y));
    vec4 src = texture(input_texture, (vec2(coords) + vec2(0.5)) / vec2(textureSize(input_texture, 0)));

    // Use a stable seed independent of time/speed so glyphs do not change each frame.
    uint base_seed = combine_seed(
        hash_mix(floatBitsToUint(width)),
        hash_mix(floatBitsToUint(height)) ^ 0x9e3779b9u,
    );
    float alpha = clamp(0.5 + random_float(base_seed, 197u) * 0.25, 0.0, 1.0);

    // Flip Y so ticker rows anchor to the bottom of the final image instead of the top.
    int ticker_y = height_i - 1 - coords.y;
    float mask_val = ticker_mask(coords.x, ticker_y, width_i, height_i, base_seed, time, speed);
    float offset_mask = ticker_mask(coords.x - 1, ticker_y + 1, width_i, height_i, base_seed, time, speed);

    float offset_value_r = src.x - offset_mask;
    float offset_value_g = src.y - offset_mask;
    float offset_value_b = src.z - offset_mask;

    vec4 result = vec4(0.0);
    result.x = apply_blend(src.x, offset_value_r, mask_val, alpha);
    result.y = apply_blend(src.y, offset_value_g, mask_val, alpha);
    result.z = apply_blend(src.z, offset_value_b, mask_val, alpha);
    result.w = src.w;

    uint base_index = pixel_base_index(global_id.x, global_id.y, width);
    if (channel_count >= 1u) {
    }
    if (channel_count >= 2u) {
    }
    if (channel_count >= 3u) {
    }
    if (channel_count >= 4u) {
    }
    for (uint c = channel_count; c < CHANNEL_COUNT; c = c + 1u) {
    }
}