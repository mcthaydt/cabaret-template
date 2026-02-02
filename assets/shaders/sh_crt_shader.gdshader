shader_type canvas_item;

uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float scanline_count : hint_range(50.0, 500.0) = 200.0;
uniform float curvature : hint_range(0.0, 10.0) = 2.0;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float chromatic_aberration : hint_range(0.0, 0.01) = 0.002;
uniform float brightness : hint_range(0.5, 2.0) = 1.0;
uniform sampler2D screen_texture : hint_screen_texture;

vec2 _curve_uv(vec2 uv, float amount) {
	if (amount <= 0.0) {
		return uv;
	}
	uv = uv * 2.0 - 1.0;
	vec2 offset = abs(uv.yx) / vec2(amount);
	uv = uv + uv * offset * offset;
	uv = uv * 0.5 + 0.5;
	return uv;
}

float _vignette(vec2 uv, float intensity) {
	uv *= 1.0 - uv.yx;
	float vig = uv.x * uv.y * 15.0;
	return pow(vig, intensity * 0.5);
}

void fragment() {
	vec2 curved_uv = _curve_uv(SCREEN_UV, curvature);

	// Check if pixels are outside the curved screen bounds
	if (curved_uv.x < 0.0 || curved_uv.x > 1.0 || curved_uv.y < 0.0 || curved_uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		// Chromatic aberration
		float r = texture(screen_texture, curved_uv + vec2(chromatic_aberration, 0.0)).r;
		float g = texture(screen_texture, curved_uv).g;
		float b = texture(screen_texture, curved_uv - vec2(chromatic_aberration, 0.0)).b;
		vec3 color = vec3(r, g, b);

		// Scanlines
		float scanline = sin(curved_uv.y * scanline_count * 3.14159) * 0.5 + 0.5;
		scanline = mix(1.0, scanline, scanline_intensity);
		color *= scanline;

		// Vignette
		float vig = _vignette(curved_uv, vignette_intensity);
		color *= mix(0.3, 1.0, vig);

		// Brightness
		color *= brightness;

		COLOR = vec4(color, 1.0);
	}
}
