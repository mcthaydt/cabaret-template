shader_type canvas_item;

// Grain + dither post-process shader in a single pass.
// One screen_texture sample instead of separate fullscreen passes.
uniform sampler2D screen_texture : hint_screen_texture;

// --- Effect enable flags (0 = off, 1 = on) ---
uniform int film_grain_enabled : hint_range(0, 1) = 0;
uniform int dither_enabled : hint_range(0, 1) = 0;
uniform int scanlines_enabled : hint_range(0, 1) = 0;

// --- Scanline uniforms ---
uniform float line_mask_intensity : hint_range(0.0, 1.0) = 0.35;
uniform float scanline_count     : hint_range(60.0, 1080.0) = 480.0;

// --- Film grain uniforms ---
uniform float fg_intensity : hint_range(0.0, 1.0) = 0.1;
uniform float fg_grain_size : hint_range(0.5, 4.0) = 1.0;
uniform float fg_time = 0.0;

// --- Dither uniforms ---
uniform float dither_intensity : hint_range(0.0, 1.0) = 0.5;
uniform int dither_levels : hint_range(2, 16) = 8;
uniform float dither_luma_weight : hint_range(0.0, 1.0) = 0.5;

// ======== Film Grain ========

float _fg_hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 _apply_film_grain(vec3 color, vec2 uv) {
	vec2 grain_uv = uv * fg_grain_size * 1000.0;
	float grain = _fg_hash13(vec3(grain_uv, fg_time)) - 0.5;
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	float luma_factor = mix(1.2, 0.6, luma);
	return color + vec3(grain) * fg_intensity * luma_factor;
}

// ======== Dither ========

float _dither_bayer8x8(vec2 pixel_pos) {
	int x = int(mod(pixel_pos.x, 8.0));
	int y = int(mod(pixel_pos.y, 8.0));
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

vec3 _apply_dither(vec3 color, vec2 uv, vec2 pixel_size) {
	vec2 viewport_size = vec2(1.0) / pixel_size;
	vec2 pixel_pos = floor(uv * viewport_size);
	float threshold = _dither_bayer8x8(pixel_pos);

	float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
	float luma_scale = 1.0 - (luma * dither_luma_weight);
	float weighted_threshold = mix(0.5, threshold, luma_scale);

	float level_count = max(2.0, float(dither_levels));
	float dither_amount = 1.0 / level_count;
	vec3 dithered = color + (weighted_threshold - 0.5) * dither_amount;
	vec3 quantized = floor(dithered * level_count + 0.5) / level_count;
	quantized = clamp(quantized, 0.0, 1.0);

	return mix(color, quantized, dither_intensity);
}

// ======== Scanlines ========

vec3 _apply_scanlines(vec3 color, vec2 uv) {
	float s = 0.5 + 0.5 * cos(uv.y * scanline_count * 6.2831853);
	float mask = mix(1.0, s, line_mask_intensity);
	return color * mask;
}

// ======== Main ========

void fragment() {
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;

	// Apply effects in order: film grain -> dither
	if (film_grain_enabled == 1) {
		color = _apply_film_grain(color, SCREEN_UV);
		color = clamp(color, 0.0, 1.0);
	}

	if (dither_enabled == 1) {
		color = _apply_dither(color, SCREEN_UV, SCREEN_PIXEL_SIZE);
	}

	if (scanlines_enabled == 1) {
		color = _apply_scanlines(color, SCREEN_UV);
		color = clamp(color, 0.0, 1.0);
	}

	COLOR = vec4(color, 1.0);
}
