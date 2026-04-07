shader_type spatial;
render_mode cull_back;

uniform float clip_y_world : hint_range(-100.0, 100.0) = 100.0;
uniform float clip_fade_range : hint_range(0.0, 2.0) = 0.3;
uniform float fade_amount : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D albedo_texture : source_color, hint_default_white;
uniform vec4 albedo_color : source_color = vec4(1.0);

varying vec3 v_world_pos;

// 8x8 Bayer matrix for ordered dithering (64 opacity levels).
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

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float height_above_clip = v_world_pos.y - clip_y_world;

	// Hard discard above the soft-edge band.
	if (height_above_clip > clip_fade_range) {
		discard;
	}

	// Dithered soft edge at the clip boundary.
	if (clip_fade_range > 0.001 && height_above_clip > 0.0) {
		float height_fade = height_above_clip / clip_fade_range;
		float threshold = float(bayer64(ivec2(FRAGCOORD.xy))) / 64.0;
		if (height_fade > threshold) {
			discard;
		}
	}

	// Directional dither-dissolve for walls below the clip plane.
	if (fade_amount > 0.001) {
		float threshold = float(bayer64(ivec2(FRAGCOORD.xy))) / 64.0;
		if (fade_amount > threshold) {
			discard;
		}
	}

	vec4 tex = texture(albedo_texture, UV) * albedo_color;
	ALBEDO = tex.rgb;
}
