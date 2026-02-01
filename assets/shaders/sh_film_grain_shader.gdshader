shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.1;
uniform float grain_scale : hint_range(0.25, 4.0) = 1.0;
uniform sampler2D screen_texture : hint_screen_texture;

float _rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 base = texture(screen_texture, SCREEN_UV);
	vec2 noise_uv = SCREEN_UV * grain_scale * 200.0;
	float noise = _rand(noise_uv + vec2(TIME * 12.0, TIME * -8.0)) * 2.0 - 1.0;
	base.rgb += noise * intensity * 0.12;
	COLOR = vec4(clamp(base.rgb, 0.0, 1.0), base.a);
}
