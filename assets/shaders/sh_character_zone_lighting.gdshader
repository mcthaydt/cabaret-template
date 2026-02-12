shader_type spatial;
render_mode depth_draw_opaque, cull_back, unshaded;

uniform sampler2D albedo_texture : source_color;
uniform vec4 base_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 effective_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float effective_intensity : hint_range(0.0, 8.0, 0.01) = 1.0;

void fragment() {
	vec4 albedo_sample = texture(albedo_texture, UV);
	vec3 lit_color = albedo_sample.rgb * base_tint.rgb * effective_tint.rgb * effective_intensity;
	ALBEDO = lit_color;
}
