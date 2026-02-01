shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.5;
uniform int levels : hint_range(2, 16) = 8;
uniform int pattern_mode : hint_range(0, 1) = 0; // 0 = bayer, 1 = noise
uniform sampler2D bayer_texture : hint_default_black;
uniform sampler2D screen_texture : hint_screen_texture;

float _rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

float _get_threshold(vec2 pixel_pos) {
	if (pattern_mode == 1) {
		return _rand(pixel_pos);
	}
	ivec2 size = textureSize(bayer_texture, 0);
	if (size.x <= 0 || size.y <= 0) {
		return _rand(pixel_pos);
	}
	vec2 bayer_size = vec2(size);
	vec2 bayer_uv = (mod(pixel_pos, bayer_size) + vec2(0.5)) / bayer_size;
	return texture(bayer_texture, bayer_uv).r;
}

void fragment() {
	vec4 base = texture(screen_texture, SCREEN_UV);
	vec2 viewport_size = vec2(1.0) / SCREEN_PIXEL_SIZE;
	vec2 pixel_pos = floor(SCREEN_UV * viewport_size);
	float threshold = _get_threshold(pixel_pos);

	float levels_f = max(2.0, float(levels));
	vec3 dithered = floor(base.rgb * (levels_f - 1.0) + threshold) / (levels_f - 1.0);
	vec3 result = mix(base.rgb, dithered, intensity);
	COLOR = vec4(result, base.a);
}
