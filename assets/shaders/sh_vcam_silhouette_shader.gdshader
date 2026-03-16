shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;

uniform vec4 silhouette_color : source_color = vec4(0.02, 0.02, 0.02, 0.65);

void fragment() {
	ALBEDO = silhouette_color.rgb;
	ALPHA = silhouette_color.a;
}
