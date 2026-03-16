shader_type spatial;
render_mode blend_mix, unshaded, cull_back, depth_draw_never, depth_test_disabled;

uniform vec4 silhouette_color : source_color = vec4(0.02, 0.02, 0.02, 0.65);
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

void fragment() {
	float depth_sample = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	// Reversed-Z: closer surface = higher depth value
	// If depth buffer has a closer surface than this fragment, we are occluded
	if (depth_sample > FRAGCOORD.z + 0.00001) {
		ALBEDO = silhouette_color.rgb;
		ALPHA = silhouette_color.a;
	} else {
		ALPHA = 0.0;
	}
}
