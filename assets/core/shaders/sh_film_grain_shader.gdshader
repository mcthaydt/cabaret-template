shader_type canvas_item;

// Film grain effect with per-pixel randomness
uniform float intensity : hint_range(0.0, 1.0) = 0.1;
uniform float grain_size : hint_range(0.5, 4.0) = 1.0;
uniform float time = 0.0;
uniform sampler2D screen_texture : hint_screen_texture;

// Fast hash for per-pixel random grain
float _hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

// Generate random grain value for this pixel
float _film_grain(vec2 uv, float time_seed) {
	// Scale UV by grain size and screen resolution
	vec2 grain_uv = uv * grain_size * 1000.0;

	// Add time for animation
	vec3 seed = vec3(grain_uv, time_seed);

	// Generate random value per pixel
	float grain = _hash13(seed);

	// Center around 0 (-0.5 to 0.5)
	grain = grain - 0.5;

	return grain;
}

void fragment() {
	vec4 base = texture(screen_texture, SCREEN_UV);

	// Generate per-pixel film grain
	float grain = _film_grain(SCREEN_UV, time);

	// Vary grain by luminance (darker areas = more visible grain, like real film)
	float luma = dot(base.rgb, vec3(0.299, 0.587, 0.114));
	float luma_factor = mix(1.2, 0.6, luma);

	// Apply grain to all channels (monochrome grain)
	vec3 grain_vec = vec3(grain) * intensity * luma_factor;

	base.rgb += grain_vec;

	COLOR = vec4(clamp(base.rgb, 0.0, 1.0), base.a);
}
