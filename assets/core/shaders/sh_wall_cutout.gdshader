shader_type spatial;
render_mode unshaded, cull_back, blend_mix, depth_draw_opaque;

global uniform vec3 wall_cutout_player_pos;
global uniform vec3 wall_cutout_camera_pos;
global uniform float wall_cutout_near_radius;
global uniform float wall_cutout_far_radius;
global uniform float wall_cutout_falloff;
global uniform float wall_cutout_min_alpha;

uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D base_texture : source_color, hint_default_white;
uniform bool use_base_texture = false;

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 ab = wall_cutout_player_pos - wall_cutout_camera_pos;
	float ab_len_sq = max(dot(ab, ab), 1e-6);
	vec3 ap = v_world_pos - wall_cutout_camera_pos;
	float t_raw = dot(ap, ab) / ab_len_sq;
	float t = clamp(t_raw, 0.0, 1.0);
	vec3 closest = wall_cutout_camera_pos + t * ab;
	float dist = length(v_world_pos - closest);

	float radius = mix(wall_cutout_near_radius, wall_cutout_far_radius, t);
	float falloff = max(wall_cutout_falloff, 1e-4);
	float edge = smoothstep(radius, radius + falloff, dist);
	float alpha = mix(wall_cutout_min_alpha, 1.0, edge);

	// Cone strictly ends at player: fragments past the player along the
	// camera->player axis stay fully opaque. Without this, clamp(t, 0, 1)
	// causes walls behind the player within far_radius to be cut out (the
	// cutout becomes a sphere around the player instead of a cone).
	if (t_raw > 1.0 || t_raw < 0.0) {
		alpha = 1.0;
	}

	vec3 tex_rgb = use_base_texture ? texture(base_texture, UV).rgb : vec3(1.0);
	ALBEDO = base_color.rgb * tex_rgb;
	ALPHA = alpha;
}
