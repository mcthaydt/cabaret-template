shader_type canvas_item;
render_mode unshaded;

uniform int preset_mode = 0;
uniform float effect_intensity: hint_range(0.0, 1.0) = 0.5;
uniform float effect_speed: hint_range(0.0, 5.0) = 1.0;

const float LOCAL_TAU = 6.28318530718;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

mat2 rotate2d(float angle) {
	float s = sin(angle);
	float c = cos(angle);
	return mat2(vec2(c, -s), vec2(s, c));
}

vec3 neon_palette(float t) {
	return clamp(
		0.54 + 0.46 * cos(LOCAL_TAU * (t + vec3(0.0, 0.33, 0.67))),
		0.0,
		1.0
	);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * effect_speed;
	vec3 base = COLOR.rgb;
	float intensity = clamp(effect_intensity, 0.0, 1.0);
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 centered_uv = uv * 2.0 - 1.0;
	centered_uv.x *= aspect;
	vec3 vivid = vec3(0.0);
	float band = 0.0;

	if (preset_mode == 0) {
		vec2 p = rotate2d(0.55) * centered_uv;
		float rings = sin(length(p) * 17.5 - t * 4.2);
		float swirl = sin(atan(p.y, p.x) * 6.0 + length(p) * 11.0 - t * 3.1);
		float cross = sin((p.x + p.y + t * 0.9) * 20.0) * sin((p.x - p.y - t * 0.6) * 20.0);
		band = clamp(0.5 + rings * 0.24 + swirl * 0.2 + cross * 0.16, 0.0, 1.0);
		vivid = neon_palette(band + t * 0.06);
		float core = pow(clamp(1.0 - length(centered_uv), 0.0, 1.0), 1.6);
		vivid += neon_palette(band + 0.25) * core * 0.35;
	} else if (preset_mode == 1) {
		float sweep = centered_uv.x * 2.4 + centered_uv.y * 1.45 + t * 1.9;
		float stripes = sin(sweep * 16.0);
		float wave = sin((centered_uv.y + sin(centered_uv.x * 2.8 + t * 1.35) * 0.25) * 24.0 - t * 3.4);
		vec2 orb_center = vec2(sin(t * 0.55) * 0.34, cos(t * 0.42) * 0.24);
		float orb = sin(length(centered_uv - orb_center) * 21.0 - t * 5.7);
		band = clamp(0.5 + stripes * 0.22 + wave * 0.18 + orb * 0.14, 0.0, 1.0);
		vivid = mix(
			neon_palette(band + t * 0.1),
			neon_palette(sweep * 0.06 + t * 0.12),
			0.42
		);
	} else {
		vec2 grain_cell = floor((uv + vec2(t * 0.03, -t * 0.02)) * vec2(220.0, 130.0));
		vec2 blob_cell = floor((uv + vec2(-t * 0.02, t * 0.025)) * vec2(34.0, 20.0));
		float grain = hash21(grain_cell);
		float blob = hash21(blob_cell);
		vec2 warp_uv = centered_uv * 1.35 + vec2(t * 0.34, -t * 0.21);
		float liquid = sin(warp_uv.x * 8.0 + sin(warp_uv.y * 6.2 + t * 1.2) * 2.1 + t * 2.3);
		float halo = sin(length(centered_uv) * 25.0 - t * 6.0);
		band = clamp(
			0.35 * grain
			+ 0.25 * blob
			+ 0.24 * (liquid * 0.5 + 0.5)
			+ 0.16 * (halo * 0.5 + 0.5),
			0.0,
			1.0
		);
		vivid = neon_palette(band + t * 0.14);
		vivid += neon_palette(band + 0.5) * (grain - 0.5) * 0.48;
	}

	float lum = dot(vivid, vec3(0.2126, 0.7152, 0.0722));
	vivid = mix(vec3(lum), vivid, 1.28);
	vivid = clamp(vivid, 0.0, 1.0);

	float blend = pow(intensity, 0.85) * 0.9;
	float glow = smoothstep(0.58, 1.0, band) * intensity * 0.35;
	vec3 shaded = mix(base, vivid, blend) + vivid * glow * intensity;
	COLOR = vec4(clamp(shaded, 0.0, 1.0), COLOR.a);
}
