shader_type canvas_item;

// Dithering effect with ordered Bayer pattern
uniform float intensity : hint_range(0.0, 1.0) = 0.5;
uniform int levels : hint_range(2, 16) = 4;
uniform int pattern_mode : hint_range(0, 1) = 0; // 0 = bayer, 1 = noise
uniform sampler2D screen_texture : hint_screen_texture;

// Fast hash for noise pattern
float _hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// 8x8 Bayer matrix pattern (classic ordered dithering)
float _bayer8x8(vec2 pixel_pos) {
	int x = int(mod(pixel_pos.x, 8.0));
	int y = int(mod(pixel_pos.y, 8.0));

	// Bayer 8x8 matrix values (0-63) / 64.0
	int bayer[64] = int[](
		 0, 32,  8, 40,  2, 34, 10, 42,
		48, 16, 56, 24, 50, 18, 58, 26,
		12, 44,  4, 36, 14, 46,  6, 38,
		60, 28, 52, 20, 62, 30, 54, 22,
		 3, 35, 11, 43,  1, 33,  9, 41,
		51, 19, 59, 27, 49, 17, 57, 25,
		15, 47,  7, 39, 13, 45,  5, 37,
		63, 31, 55, 23, 61, 29, 53, 21
	);

	return float(bayer[y * 8 + x]) / 64.0;
}

// Get dither threshold value
float _get_threshold(vec2 pixel_pos) {
	if (pattern_mode == 1) {
		return _hash12(pixel_pos);
	} else {
		return _bayer8x8(pixel_pos);
	}
}

// Quantize color with dithering
vec3 _dither_color(vec3 color, float threshold, float level_count) {
	// Scale threshold based on number of levels
	float dither_amount = 1.0 / level_count;
	vec3 dithered = color + (threshold - 0.5) * dither_amount;

	// Quantize to discrete levels
	vec3 quantized = floor(dithered * level_count + 0.5) / level_count;

	return clamp(quantized, 0.0, 1.0);
}

void fragment() {
	vec4 base = texture(screen_texture, SCREEN_UV);

	// Get pixel position for dither pattern
	vec2 viewport_size = vec2(1.0) / SCREEN_PIXEL_SIZE;
	vec2 pixel_pos = floor(SCREEN_UV * viewport_size);

	// Get dither threshold
	float threshold = _get_threshold(pixel_pos);

	// Apply dithering
	float level_count = max(2.0, float(levels));
	vec3 dithered = _dither_color(base.rgb, threshold, level_count);

	// Blend with original based on intensity
	vec3 result = mix(base.rgb, dithered, intensity);

	COLOR = vec4(result, base.a);
}
