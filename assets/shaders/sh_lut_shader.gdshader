shader_type canvas_item;

// Professional LUT shader with smooth interpolation and tone mapping
uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D lut_texture : hint_default_black, filter_linear;
uniform sampler2D screen_texture : hint_screen_texture;

// Enhanced trilinear sampling with smooth interpolation
vec3 _sample_lut_strip(vec3 color, ivec2 size) {
	float lut_size = 16.0;
	vec3 clamped = clamp(color, 0.0, 1.0);

	// Calculate blue slice positions
	float blue = clamped.b * (lut_size - 1.0);
	float slice0 = floor(blue);
	float slice1 = min(slice0 + 1.0, lut_size - 1.0);
	float slice_t = fract(blue);

	vec2 tex_size = vec2(size);
	vec2 inv_tex_size = 1.0 / tex_size;

	// Calculate positions within each slice
	vec2 rg = clamped.rg * (lut_size - 1.0);

	// Sample both blue slices
	vec2 uv0 = (vec2(rg.x + slice0 * lut_size, rg.y) + vec2(0.5)) * inv_tex_size;
	vec2 uv1 = (vec2(rg.x + slice1 * lut_size, rg.y) + vec2(0.5)) * inv_tex_size;

	vec3 color0 = texture(lut_texture, uv0).rgb;
	vec3 color1 = texture(lut_texture, uv1).rgb;

	// Smooth cubic interpolation between slices for better quality
	float t = slice_t * slice_t * (3.0 - 2.0 * slice_t);
	return mix(color0, color1, t);
}

// Enhanced square format sampling with smooth interpolation
vec3 _sample_lut_square(vec3 color, ivec2 size) {
	float lut_size = 64.0;
	float tiles_per_row = 8.0;
	vec3 clamped = clamp(color, 0.0, 1.0);

	// Calculate blue slice positions
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
	vec2 local_pos = clamped.rg * (lut_size - 1.0);

	// Sample both slices
	vec2 uv0 = (vec2(tile_x0 * lut_size + local_pos.x, tile_y0 * lut_size + local_pos.y) + vec2(0.5)) * inv_tex_size;
	vec2 uv1 = (vec2(tile_x1 * lut_size + local_pos.x, tile_y1 * lut_size + local_pos.y) + vec2(0.5)) * inv_tex_size;

	vec3 color0 = texture(lut_texture, uv0).rgb;
	vec3 color1 = texture(lut_texture, uv1).rgb;

	// Smooth cubic interpolation for better gradients
	float t = slice_t * slice_t * (3.0 - 2.0 * slice_t);
	return mix(color0, color1, t);
}

vec3 _sample_lut(vec3 color) {
	ivec2 size = textureSize(lut_texture, 0);
	if (size.x <= 1 || size.y <= 1) {
		return color;
	}

	// Auto-detect format based on dimensions
	if (size.x == size.y) {
		return _sample_lut_square(color, size);
	} else {
		return _sample_lut_strip(color, size);
	}
}

// ACES-inspired tone mapping for cinematic look
vec3 _aces_tonemap(vec3 color) {
	// Simplified ACES approximation
	const float a = 2.51;
	const float b = 0.03;
	const float c = 2.43;
	const float d = 0.59;
	const float e = 0.14;

	color = (color * (a * color + b)) / (color * (c * color + d) + e);
	return clamp(color, 0.0, 1.0);
}

// Inverse ACES for pre-LUT processing
vec3 _inverse_aces_tonemap(vec3 color) {
	// Simplified inverse (approximate)
	return pow(color, vec3(1.0 / 2.2));
}

void fragment() {
	vec4 base = texture(screen_texture, SCREEN_UV);

	// Apply gentle tone curve before LUT for better color preservation
	vec3 prepared = _inverse_aces_tonemap(base.rgb);

	// Sample LUT with high-quality interpolation
	vec3 graded = _sample_lut(prepared);

	// Apply final tone mapping
	graded = _aces_tonemap(graded);

	// Blend with original based on intensity
	vec3 result = mix(base.rgb, graded, intensity);

	// Subtle color vibrance boost (common in cinematic grading)
	float luma = dot(result, vec3(0.299, 0.587, 0.114));
	result = mix(vec3(luma), result, 1.05);

	COLOR = vec4(clamp(result, 0.0, 1.0), base.a);
}
