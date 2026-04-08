shader_type canvas_item;

// Combined post-process shader: film grain + dither + CRT in a single pass.
// One screen_texture sample instead of three separate fullscreen passes.
uniform sampler2D screen_texture : hint_screen_texture;

// --- Effect enable flags (0 = off, 1 = on) ---
uniform int film_grain_enabled : hint_range(0, 1) = 0;
uniform int dither_enabled : hint_range(0, 1) = 0;
uniform int crt_enabled : hint_range(0, 1) = 0;

// --- Film grain uniforms ---
uniform float fg_intensity : hint_range(0.0, 1.0) = 0.1;
uniform float fg_grain_size : hint_range(0.5, 4.0) = 1.0;
uniform float fg_time = 0.0;

// --- Dither uniforms ---
uniform float dither_intensity : hint_range(0.0, 1.0) = 0.5;
uniform int dither_levels : hint_range(2, 16) = 8;
uniform float dither_luma_weight : hint_range(0.0, 1.0) = 0.5;

// --- CRT uniforms ---
uniform float crt_scanline_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float crt_scanline_count : hint_range(50.0, 500.0) = 200.0;
uniform float crt_curvature : hint_range(0.0, 10.0) = 2.0;
uniform float crt_vignette_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float crt_chromatic_aberration : hint_range(0.0, 0.01) = 0.002;
uniform float crt_brightness : hint_range(0.5, 2.0) = 1.0;

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

// ======== CRT ========

vec2 _crt_curve_uv(vec2 uv, float amount) {
	if (amount <= 0.0) {
		return uv;
	}
	uv = uv * 2.0 - 1.0;
	float r2 = dot(uv, uv);
	float distortion = 1.0 + amount * 0.1 * r2;
	uv *= distortion;
	return uv * 0.5 + 0.5;
}

float _crt_vignette(vec2 uv, float intensity) {
	vec2 centered = uv * 2.0 - 1.0;
	float dist = length(centered);
	float vig = 1.0 - smoothstep(0.5, 1.5, dist);
	return mix(1.0, vig, intensity);
}

float _crt_scanlines(vec2 uv, float count, float intensity, float pixel_brightness) {
	float line = sin(uv.y * count * 6.28318);
	float depth = mix(0.7, 0.95, pixel_brightness);
	line = line * 0.5 + 0.5;
	line = mix(depth, 1.0, pow(line, 2.0));
	return mix(1.0, line, intensity);
}

vec3 _crt_shadow_mask(vec2 uv, vec2 resolution) {
	vec2 pixel_pos = uv * resolution;
	float mask_pattern = fract(pixel_pos.x / 3.0);
	vec3 mask = vec3(1.0);
	if (mask_pattern < 0.333) {
		mask = vec3(1.0, 0.7, 0.7);
	} else if (mask_pattern < 0.666) {
		mask = vec3(0.7, 1.0, 0.7);
	} else {
		mask = vec3(0.7, 0.7, 1.0);
	}
	return mask;
}

// Lightweight 3-tap horizontal bloom (replaces 5-tap cross)
vec3 _crt_bloom_light(vec3 center_color, sampler2D tex, vec2 uv, vec2 pixel_size) {
	vec3 bloom = center_color;
	bloom += texture(tex, uv + vec2(pixel_size.x * 2.0, 0.0)).rgb;
	bloom += texture(tex, uv - vec2(pixel_size.x * 2.0, 0.0)).rgb;
	return bloom * (1.0 / 3.0);
}

vec3 _apply_crt(vec3 color, vec2 uv, vec2 pixel_size) {
	vec2 curved_uv = _crt_curve_uv(uv, crt_curvature);

	// Out-of-bounds check for curvature
	if (curved_uv.x < 0.0 || curved_uv.x > 1.0 || curved_uv.y < 0.0 || curved_uv.y > 1.0) {
		return vec3(0.0);
	}

	// Chromatic aberration: re-sample if enabled, otherwise use passed color
	vec3 crt_color;
	if (crt_chromatic_aberration > 0.0001) {
		vec2 ca_offset = vec2(crt_chromatic_aberration);
		crt_color.r = texture(screen_texture, curved_uv + ca_offset * vec2(1.5, 0.0)).r;
		crt_color.g = texture(screen_texture, curved_uv).g;
		crt_color.b = texture(screen_texture, curved_uv - ca_offset * vec2(1.5, 0.0)).b;
	} else {
		// If no CA and no curvature, reuse the passed-in color to avoid re-sampling
		if (crt_curvature <= 0.0) {
			crt_color = color;
		} else {
			crt_color = texture(screen_texture, curved_uv).rgb;
		}
	}

	float luma = dot(crt_color, vec3(0.299, 0.587, 0.114));

	// Scanlines
	float scanline = _crt_scanlines(curved_uv, crt_scanline_count, crt_scanline_intensity, luma);
	crt_color *= scanline;

	// Shadow mask (skip at low scanline intensity where it's barely visible)
	if (crt_scanline_intensity > 0.3) {
		vec3 mask = _crt_shadow_mask(curved_uv, 1.0 / pixel_size);
		crt_color *= mix(vec3(1.0), mask, 0.3);
	}

	// Lightweight bloom
	vec3 glow = _crt_bloom_light(crt_color, screen_texture, curved_uv, pixel_size);
	crt_color += glow * luma * 0.2;

	// Vignette
	float vig = _crt_vignette(curved_uv, crt_vignette_intensity);
	crt_color *= vig;

	// Brightness + warm tint
	crt_color *= crt_brightness;
	crt_color.r *= 1.02;
	crt_color.b *= 0.98;

	return clamp(crt_color, 0.0, 1.0);
}

// ======== Main ========

void fragment() {
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;

	// Apply effects in order: film grain -> dither -> CRT
	if (film_grain_enabled == 1) {
		color = _apply_film_grain(color, SCREEN_UV);
		color = clamp(color, 0.0, 1.0);
	}

	if (dither_enabled == 1) {
		color = _apply_dither(color, SCREEN_UV, SCREEN_PIXEL_SIZE);
	}

	if (crt_enabled == 1) {
		color = _apply_crt(color, SCREEN_UV, SCREEN_PIXEL_SIZE);
	}

	COLOR = vec4(color, 1.0);
}
