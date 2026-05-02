shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled;

uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform vec4 base_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 effective_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float effective_intensity : hint_range(0.0, 8.0, 0.01) = 1.0;
uniform float minimum_unlit_floor : hint_range(0.0, 1.0, 0.01) = 0.2;

void vertex() {
	vec3 cam_right = INV_VIEW_MATRIX[0].xyz;
	vec3 cam_up = INV_VIEW_MATRIX[1].xyz;
	cam_up.y = 0.0;
	cam_up = normalize(cam_up);

	float angle = atan(cam_right.x, cam_right.z);
	float c = cos(angle);
	float s = sin(angle);

	MODELVIEW_MATRIX = VIEW_MATRIX * MODEL_MATRIX * mat4(
		vec4(c, 0.0, s, 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(-s, 0.0, c, 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);
}

void fragment() {
	vec4 albedo_sample = texture(albedo_texture, UV);
	vec3 zone_tinted_color = albedo_sample.rgb * base_tint.rgb * effective_tint.rgb;
	ALBEDO = zone_tinted_color * effective_intensity;
	EMISSION = zone_tinted_color * minimum_unlit_floor;
	ALPHA = albedo_sample.a;
}
