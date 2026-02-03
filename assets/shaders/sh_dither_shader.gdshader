shader_type canvas_item;

// Professional dithering with blue noise and improved ordered dithering
uniform float intensity : hint_range(0.0, 1.0) = 0.5;
uniform int levels : hint_range(2, 16) = 8;
uniform int pattern_mode : hint_range(0, 2) = 0; // 0 = bayer, 1 = blue noise, 2 = triangular
uniform sampler2D bayer_texture : hint_default_black;
uniform sampler2D screen_texture : hint_screen_texture;

// Improved random for blue noise simulation
float _hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Blue noise approximation (better than white noise)
float _blue_noise(vec2 pixel_pos) {
	// Multi-scale noise for blue noise characteristics
	float noise = 0.0;
	float scale = 1.0;
	float amplitude = 1.0;

	for (int i = 0; i < 3; i++) {
		vec2 pos = pixel_pos * scale;
		noise += _hash12(pos) * amplitude;
		scale *= 2.0;
		amplitude *= 0.5;
	}

	return fract(noise);
}

// Triangular dithering (better than uniform for perceptual quality)
float _triangular_dither(vec2 pixel_pos) {
	float r1 = _hash12(pixel_pos);
	float r2 = _hash12(pixel_pos + vec2(1.0, 1.0));
	return (r1 + r2) * 0.5;
}

// Enhanced Bayer matrix sampling
float _bayer_dither(vec2 pixel_pos) {
	ivec2 size = textureSize(bayer_texture, 0);
	if (size.x <= 0 || size.y <= 0) {
		return _blue_noise(pixel_pos);
	}

	vec2 bayer_size = vec2(size);
	vec2 bayer_uv = (mod(pixel_pos, bayer_size) + vec2(0.5)) / bayer_size;
	return texture(bayer_texture, bayer_uv).r;
}

float _get_threshold(vec2 pixel_pos) {
	if (pattern_mode == 1) {
		return _blue_noise(pixel_pos);
	} else if (pattern_mode == 2) {
		return _triangular_dither(pixel_pos);
	} else {
		return _bayer_dither(pixel_pos);
	}
}

// Improved color quantization with error diffusion
vec3 _quantize_color(vec3 color, float threshold, float level_count) {
	// Add dither threshold
	vec3 dithered = color + (threshold - 0.5) / level_count;

	// Quantize to levels
	vec3 quantized = floor(dithered * level_count) / level_count;

	return quantized;
}

void fragment() {
	vec4 base = texture(screen_texture, SCREEN_UV);

	// Get pixel position for dither pattern
	vec2 viewport_size = vec2(1.0) / SCREEN_PIXEL_SIZE;
	vec2 pixel_pos = floor(SCREEN_UV * viewport_size);

	// Get dither threshold
	float threshold = _get_threshold(pixel_pos);

	// Quantize with dithering
	float level_count = max(2.0, float(levels));
	vec3 dithered = _quantize_color(base.rgb, threshold, level_count);

	// Preserve luminance for better quality
	float original_luma = dot(base.rgb, vec3(0.299, 0.587, 0.114));
	float dithered_luma = dot(dithered, vec3(0.299, 0.587, 0.114));

	// Adjust to match original brightness
	if (dithered_luma > 0.0) {
		dithered *= original_luma / dithered_luma;
		dithered = clamp(dithered, 0.0, 1.0);
	}

	// Blend with original based on intensity
	vec3 result = mix(base.rgb, dithered, intensity);

	COLOR = vec4(result, base.a);
}
