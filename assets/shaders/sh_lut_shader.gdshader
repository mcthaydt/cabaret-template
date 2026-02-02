shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D lut_texture : hint_default_black;
uniform sampler2D screen_texture : hint_screen_texture;

// Sample LUT in horizontal strip format (256x16 for 16^3)
vec3 _sample_lut_strip(vec3 color, ivec2 size) {
	float lut_size = 16.0;
	vec3 clamped = clamp(color, 0.0, 1.0);
	float blue = clamped.b * (lut_size - 1.0);
	float slice0 = floor(blue);
	float slice1 = min(slice0 + 1.0, lut_size - 1.0);
	float slice_t = fract(blue);

	vec2 tex_size = vec2(size);
	vec2 inv_tex_size = 1.0 / tex_size;
	float x0 = clamped.r * (lut_size - 1.0) + slice0 * lut_size;
	float x1 = clamped.r * (lut_size - 1.0) + slice1 * lut_size;
	float y = clamped.g * (lut_size - 1.0);

	vec2 uv0 = (vec2(x0, y) + vec2(0.5)) * inv_tex_size;
	vec2 uv1 = (vec2(x1, y) + vec2(0.5)) * inv_tex_size;
	vec3 color0 = texture(lut_texture, uv0).rgb;
	vec3 color1 = texture(lut_texture, uv1).rgb;
	return mix(color0, color1, slice_t);
}

// Sample LUT in square grid format (512x512 for 64^3)
vec3 _sample_lut_square(vec3 color, ivec2 size) {
	float lut_size = 64.0;
	float tiles_per_row = 8.0;
	vec3 clamped = clamp(color, 0.0, 1.0);

	float blue = clamped.b * (lut_size - 1.0);
	float slice0 = floor(blue);
	float slice1 = min(slice0 + 1.0, lut_size - 1.0);
	float slice_t = fract(blue);

	vec2 tex_size = vec2(size);
	vec2 inv_tex_size = 1.0 / tex_size;

	// Calculate tile positions for both slices
	float tile_x0 = mod(slice0, tiles_per_row);
	float tile_y0 = floor(slice0 / tiles_per_row);
	float tile_x1 = mod(slice1, tiles_per_row);
	float tile_y1 = floor(slice1 / tiles_per_row);

	// Calculate positions within tiles
	float local_x = clamped.r * (lut_size - 1.0);
	float local_y = clamped.g * (lut_size - 1.0);

	// Calculate final UV coordinates
	vec2 uv0 = (vec2(tile_x0 * lut_size + local_x, tile_y0 * lut_size + local_y) + vec2(0.5)) * inv_tex_size;
	vec2 uv1 = (vec2(tile_x1 * lut_size + local_x, tile_y1 * lut_size + local_y) + vec2(0.5)) * inv_tex_size;

	vec3 color0 = texture(lut_texture, uv0).rgb;
	vec3 color1 = texture(lut_texture, uv1).rgb;
	return mix(color0, color1, slice_t);
}

vec3 _sample_lut(vec3 color) {
	ivec2 size = textureSize(lut_texture, 0);
	if (size.x <= 1 || size.y <= 1) {
		return color;
	}

	// Auto-detect format based on dimensions
	// Square format: width == height (e.g., 512x512, 256x256)
	// Strip format: width >> height (e.g., 256x16, 512x32)
	if (size.x == size.y) {
		return _sample_lut_square(color, size);
	} else {
		return _sample_lut_strip(color, size);
	}
}

void fragment() {
	vec4 base = texture(screen_texture, SCREEN_UV);
	vec3 graded = _sample_lut(base.rgb);
	vec3 result = mix(base.rgb, graded, intensity);
	COLOR = vec4(result, base.a);
}
