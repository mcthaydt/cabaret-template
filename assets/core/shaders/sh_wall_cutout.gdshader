shader_type spatial;
render_mode unshaded, cull_back, blend_mix, depth_draw_opaque;

// Diablo/Hades-style screen-space disc cutout. A circular hole is drawn
// around the player's screen position on every wall fragment that is closer
// to the camera than the player (i.e., actually occluding them).
//
// Sizes are in normalized viewport-height units (0..1). At default 0.12 the
// disc is ~12% of viewport height in radius — readable on mobile and desktop.

// Pushed each frame by S_WallCutoutSystem to this material instance.
// (Plain uniforms rather than global uniforms so the shader doesn't depend on
// project.godot [shader_globals] entries — the cutout system is fully
// self-contained.)
uniform vec3 wall_cutout_player_pos = vec3(1.0e6);
uniform float wall_cutout_disc_radius = 0.12;
uniform float wall_cutout_disc_falloff = 0.05;
uniform float wall_cutout_disc_min_alpha = 0.0;

uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D base_texture : source_color, hint_default_white;
uniform bool use_base_texture = false;

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float alpha = 1.0;

	// Project the player into screen space using the active camera matrices.
	vec4 player_clip = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wall_cutout_player_pos, 1.0);
	if (player_clip.w > 0.0) {
		vec2 player_ndc = player_clip.xy / player_clip.w;
		vec2 player_uv = player_ndc * 0.5 + 0.5;

		// FRAGCOORD is in viewport pixels (origin bottom-left). Convert to UV.
		vec2 frag_uv = FRAGCOORD.xy / VIEWPORT_SIZE;

		// Aspect-correct so the cutout is a true circle on screen, not an
		// ellipse stretched along X by the viewport's aspect ratio.
		float aspect = VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
		vec2 delta = vec2((frag_uv.x - player_uv.x) * aspect, frag_uv.y - player_uv.y);
		float screen_dist = length(delta);

		float falloff = max(wall_cutout_disc_falloff, 1e-4);
		float edge = smoothstep(wall_cutout_disc_radius, wall_cutout_disc_radius + falloff, screen_dist);
		float disc_alpha = mix(wall_cutout_disc_min_alpha, 1.0, edge);

		// Occlusion gate: only fade walls that are actually between camera
		// and player. In Godot view space -Z is forward, so a closer point
		// has a larger (less negative) Z. Add an epsilon so a wall touching
		// the player at the same depth doesn't pop in/out frame to frame.
		vec3 view_player = (VIEW_MATRIX * vec4(wall_cutout_player_pos, 1.0)).xyz;
		vec3 view_frag = (VIEW_MATRIX * vec4(v_world_pos, 1.0)).xyz;
		float depth_epsilon = 0.05;
		if (view_frag.z > view_player.z + depth_epsilon) {
			alpha = disc_alpha;
		}
	}

	vec3 tex_rgb = use_base_texture ? texture(base_texture, UV).rgb : vec3(1.0);
	ALBEDO = base_color.rgb * tex_rgb;
	ALPHA = alpha;
}
