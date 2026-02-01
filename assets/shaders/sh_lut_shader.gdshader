shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D lut_texture : hint_default_black;
uniform sampler2D screen_texture : hint_screen_texture;

vec3 _sample_lut(vec3 color) {
	ivec2 size = textureSize(lut_texture, 0);
	if (size.x <= 1 || size.y <= 1) {
		return color;
	}

	float lut_size = 16.0;
	vec3 clamped = clamp(color, 0.0, 1.0);
	float blue = clamped.b * (lut_size - 1.0);
	float slice0 = floor(blue);
	float slice1 = min(slice0 + 1.0, lut_size - 1.0);
	float slice_t = fract(blue);

	vec2 tex_size = vec2(size);
	vec2 inv_tex_size = 1.0 / tex_size;
	float x0 = clamped.r * (lut_size - 1.0) + slice0 * lut_size;
	float x1 = clamped.r * (lut_size - 1.0) + slice1 * lut_size;
	float y = clamped.g * (lut_size - 1.0);

	vec2 uv0 = (vec2(x0, y) + vec2(0.5)) * inv_tex_size;
	vec2 uv1 = (vec2(x1, y) + vec2(0.5)) * inv_tex_size;
	vec3 color0 = texture(lut_texture, uv0).rgb;
	vec3 color1 = texture(lut_texture, uv1).rgb;
	return mix(color0, color1, slice_t);
}

void fragment() {
	vec4 base = texture(screen_texture, SCREEN_UV);
	vec3 graded = _sample_lut(base.rgb);
	vec3 result = mix(base.rgb, graded, intensity);
	COLOR = vec4(result, base.a);
}
