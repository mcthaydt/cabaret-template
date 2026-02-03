shader_type canvas_item;

// Professional CRT shader with phosphor glow, shadow mask, and realistic scanlines
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float scanline_count : hint_range(50.0, 500.0) = 200.0;
uniform float curvature : hint_range(0.0, 10.0) = 2.0;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float chromatic_aberration : hint_range(0.0, 0.01) = 0.002;
uniform float brightness : hint_range(0.5, 2.0) = 1.0;
uniform sampler2D screen_texture : hint_screen_texture;

// Improved barrel distortion for CRT curvature
vec2 _curve_uv(vec2 uv, float amount) {
	if (amount <= 0.0) {
		return uv;
	}

	uv = uv * 2.0 - 1.0;

	// Barrel distortion formula
	float r2 = dot(uv, uv);
	float distortion = 1.0 + amount * 0.1 * r2;
	uv *= distortion;

	uv = uv * 0.5 + 0.5;
	return uv;
}

// Realistic vignette with softer falloff
float _vignette(vec2 uv, float intensity) {
	vec2 centered = uv * 2.0 - 1.0;
	float dist = length(centered);
	float vig = 1.0 - smoothstep(0.5, 1.5, dist);
	return mix(1.0, vig, intensity);
}

// Professional scanlines with varying intensity based on brightness
float _scanlines(vec2 uv, float count, float intensity, float pixel_brightness) {
	float line = sin(uv.y * count * 6.28318);

	// Modulate scanline depth based on pixel brightness
	float depth = mix(0.7, 0.95, pixel_brightness);

	// Smooth scanlines with better interpolation
	line = line * 0.5 + 0.5;
	line = mix(depth, 1.0, pow(line, 2.0));

	return mix(1.0, line, intensity);
}

// Shadow mask pattern (RGB triads like real CRTs)
vec3 _shadow_mask(vec2 uv, vec2 resolution) {
	vec2 pixel_pos = uv * resolution;
	float mask_pattern = fract(pixel_pos.x / 3.0);

	vec3 mask = vec3(1.0);

	// RGB triad pattern
	if (mask_pattern < 0.333) {
		mask = vec3(1.0, 0.7, 0.7); // Red phosphor
	} else if (mask_pattern < 0.666) {
		mask = vec3(0.7, 1.0, 0.7); // Green phosphor
	} else {
		mask = vec3(0.7, 0.7, 1.0); // Blue phosphor
	}

	return mask;
}

// Bloom/glow effect for phosphor persistence
vec3 _bloom(sampler2D tex, vec2 uv, vec2 pixel_size, float amount) {
	vec3 bloom = vec3(0.0);
	float total_weight = 0.0;

	// 5-tap blur for subtle glow
	const int samples = 5;
	for (int x = -samples; x <= samples; x++) {
		for (int y = -samples; y <= samples; y++) {
			vec2 offset = vec2(float(x), float(y)) * pixel_size * 2.0;
			float weight = 1.0 / (1.0 + length(vec2(float(x), float(y))));
			bloom += texture(tex, uv + offset).rgb * weight;
			total_weight += weight;
		}
	}

	return (bloom / total_weight) * amount;
}

void fragment() {
	vec2 curved_uv = _curve_uv(SCREEN_UV, curvature);

	// Check if outside curved screen bounds
	if (curved_uv.x < 0.0 || curved_uv.x > 1.0 || curved_uv.y < 0.0 || curved_uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		// Enhanced chromatic aberration (RGB separation)
		vec2 ca_offset = vec2(chromatic_aberration);
		float r = texture(screen_texture, curved_uv + ca_offset * vec2(1.5, 0.0)).r;
		float g = texture(screen_texture, curved_uv).g;
		float b = texture(screen_texture, curved_uv - ca_offset * vec2(1.5, 0.0)).b;
		vec3 color = vec3(r, g, b);

		// Calculate brightness for adaptive effects
		float luma = dot(color, vec3(0.299, 0.587, 0.114));

		// Apply scanlines with brightness-based intensity
		float scanline = _scanlines(curved_uv, scanline_count, scanline_intensity, luma);
		color *= scanline;

		// Shadow mask (subtle RGB phosphor pattern)
		vec3 mask = _shadow_mask(curved_uv, 1.0 / SCREEN_PIXEL_SIZE);
		color *= mix(vec3(1.0), mask, 0.3);

		// Phosphor glow/bloom
		vec3 glow = _bloom(screen_texture, curved_uv, SCREEN_PIXEL_SIZE, 0.3);
		color += glow * luma * 0.2;

		// Vignette
		float vig = _vignette(curved_uv, vignette_intensity);
		color *= vig;

		// Brightness adjustment
		color *= brightness;

		// Slight color temperature shift (CRTs were warmer)
		color.r *= 1.02;
		color.b *= 0.98;

		COLOR = vec4(clamp(color, 0.0, 1.0), 1.0);
	}
}
