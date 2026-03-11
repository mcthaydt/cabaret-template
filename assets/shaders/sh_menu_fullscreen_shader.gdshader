shader_type canvas_item;
render_mode unshaded;

uniform int preset_mode = 0;
uniform float effect_intensity: hint_range(0.0, 1.0) = 0.5;
uniform float effect_speed: hint_range(0.0, 5.0) = 1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * effect_speed;
	vec3 base = COLOR.rgb;
	float intensity = clamp(effect_intensity, 0.0, 1.0);
	float overlay = 0.0;
	vec3 accent = vec3(0.0);

	if (preset_mode == 0) {
		vec2 grid = fract((uv + vec2(t * 0.02, t * 0.01)) * vec2(36.0, 20.0));
		float line_x = smoothstep(0.0, 0.08, grid.x) * (1.0 - smoothstep(0.92, 1.0, grid.x));
		float line_y = smoothstep(0.0, 0.08, grid.y) * (1.0 - smoothstep(0.92, 1.0, grid.y));
		overlay = max(1.0 - line_x, 1.0 - line_y);
		accent = vec3(0.10, 0.24, 0.46);
	} else if (preset_mode == 1) {
		float warp = sin((uv.y + t * 0.07) * 42.0) * 0.006;
		float scan = sin((uv.y + warp) * 720.0 + t * 11.0) * 0.5 + 0.5;
		float drift = sin((uv.x + t * 0.06) * 16.0) * 0.5 + 0.5;
		overlay = scan * 0.8 + drift * 0.2;
		accent = vec3(0.15, 0.18, 0.38);
	} else {
		vec2 cell = floor((uv + vec2(t * 0.03, -t * 0.02)) * vec2(128.0, 72.0));
		float noise = hash21(cell);
		float grain = noise * 0.7 + sin((uv.x + uv.y + t) * 180.0) * 0.15 + 0.15;
		overlay = clamp(grain, 0.0, 1.0);
		accent = vec3(0.22, 0.08, 0.18);
	}

	vec3 shaded = base + accent * (overlay - 0.5) * intensity;
	COLOR = vec4(clamp(shaded, 0.0, 1.0), COLOR.a);
}
