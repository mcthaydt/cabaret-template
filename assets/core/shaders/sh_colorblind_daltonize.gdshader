shader_type canvas_item;

uniform int mode = 0; // 0=off, 1=deuteranopia, 2=protanopia, 3=tritanopia
uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D screen_texture : hint_screen_texture;

vec3 _apply_deuteranopia(vec3 color) {
	mat3 m = mat3(
		vec3(0.625, 0.70, 0.0),
		vec3(0.375, 0.30, 0.30),
		vec3(0.0, 0.0, 0.70)
	);
	return m * color;
}

vec3 _apply_protanopia(vec3 color) {
	mat3 m = mat3(
		vec3(0.56667, 0.55833, 0.0),
		vec3(0.43333, 0.44167, 0.24167),
		vec3(0.0, 0.0, 0.75833)
	);
	return m * color;
}

vec3 _apply_tritanopia(vec3 color) {
	mat3 m = mat3(
		vec3(0.95, 0.0, 0.0),
		vec3(0.05, 0.43333, 0.475),
		vec3(0.0, 0.56667, 0.525)
	);
	return m * color;
}

vec3 _apply_mode(vec3 color, int mode_value) {
	if (mode_value == 1) {
		return _apply_deuteranopia(color);
	}
	if (mode_value == 2) {
		return _apply_protanopia(color);
	}
	if (mode_value == 3) {
		return _apply_tritanopia(color);
	}
	return color;
}

void fragment() {
	vec4 base = texture(screen_texture, SCREEN_UV);
	vec3 result = base.rgb;
	if (mode != 0) {
		vec3 transformed = clamp(_apply_mode(base.rgb, mode), 0.0, 1.0);
		result = mix(base.rgb, transformed, intensity);
	}
	COLOR = vec4(result, base.a);
}
