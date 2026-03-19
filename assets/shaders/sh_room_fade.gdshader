shader_type spatial;
render_mode unshaded, depth_draw_never;

uniform float fade_alpha : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D albedo_texture : source_color;
uniform vec4 albedo_color : source_color = vec4(1.0);

void fragment() {
	vec4 albedo_sample = texture(albedo_texture, UV) * albedo_color;
	ALBEDO = albedo_sample.rgb;
	ALPHA = fade_alpha * albedo_sample.a;
}
