shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

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
uniform float wall_cutout_disc_radius = 0.18;
uniform float wall_cutout_disc_falloff = 0.05;
uniform float wall_cutout_disc_min_alpha = 0.0;
instance uniform float wall_cutout_enabled = 0.0;

uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D base_texture : source_color, hint_default_white;
uniform bool use_base_texture = false;

varying vec3 v_world_pos;

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
	float visibility_alpha = 1.0;

	if (wall_cutout_enabled >= 0.5) {
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
				visibility_alpha = disc_alpha;
			}
		}
	}

	if (visibility_alpha < 0.999) {
		float threshold = float(bayer64(ivec2(FRAGCOORD.xy))) / 64.0;
		if (visibility_alpha <= threshold) {
			discard;
		}
	}

	vec3 tex_rgb = use_base_texture ? texture(base_texture, UV).rgb : vec3(1.0);
	ALBEDO = base_color.rgb * tex_rgb;
}
