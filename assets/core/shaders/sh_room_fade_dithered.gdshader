shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform float fade_alpha : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D albedo_texture : source_color, hint_default_white;
uniform vec4 albedo_color : source_color = vec4(1.0);

int bayer64(ivec2 p) {
	int x = p.x & 7;
	int y = p.y & 7;
	int bayer8[64] = int[](
		 0, 32,  8, 40,  2, 34, 10, 42,
		48, 16, 56, 24, 50, 18, 58, 26,
		12, 44,  4, 36, 14, 46,  6, 38,
		60, 28, 52, 20, 62, 30, 54, 22,
		 3, 35, 11, 43,  1, 33,  9, 41,
		51, 19, 59, 27, 49, 17, 57, 25,
		15, 47,  7, 39, 13, 45,  5, 37,
		63, 31, 55, 23, 61, 29, 53, 21
	);
	return bayer8[y * 8 + x];
}

void fragment() {
	vec4 albedo_sample = texture(albedo_texture, UV) * albedo_color;

	if (fade_alpha < 0.999) {
		float threshold = float(bayer64(ivec2(FRAGCOORD.xy))) / 64.0;
		if (fade_alpha <= threshold) {
			discard;
		}
	}

	ALBEDO = albedo_sample.rgb;
}
