shader_type canvas_item;

uniform int thickness : hint_range(1, 5) = 2;
uniform vec3 outline_color : source_color = vec3(0.0);
uniform float edge_threshold : hint_range(0.0, 1.0) = 0.2;
uniform sampler2D screen_texture : hint_screen_texture;

float _luminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec2 texel = SCREEN_PIXEL_SIZE * float(thickness);
	float tl = _luminance(texture(screen_texture, SCREEN_UV + texel * vec2(-1.0, -1.0)).rgb);
	float tc = _luminance(texture(screen_texture, SCREEN_UV + texel * vec2(0.0, -1.0)).rgb);
	float tr = _luminance(texture(screen_texture, SCREEN_UV + texel * vec2(1.0, -1.0)).rgb);
	float ml = _luminance(texture(screen_texture, SCREEN_UV + texel * vec2(-1.0, 0.0)).rgb);
	float mr = _luminance(texture(screen_texture, SCREEN_UV + texel * vec2(1.0, 0.0)).rgb);
	float bl = _luminance(texture(screen_texture, SCREEN_UV + texel * vec2(-1.0, 1.0)).rgb);
	float bc = _luminance(texture(screen_texture, SCREEN_UV + texel * vec2(0.0, 1.0)).rgb);
	float br = _luminance(texture(screen_texture, SCREEN_UV + texel * vec2(1.0, 1.0)).rgb);

	float gx = -tl - 2.0 * ml - bl + tr + 2.0 * mr + br;
	float gy = -tl - 2.0 * tc - tr + bl + 2.0 * bc + br;
	float edge = length(vec2(gx, gy));
	float edge_mask = smoothstep(edge_threshold, edge_threshold + 0.25, edge);

	vec4 base = texture(screen_texture, SCREEN_UV);
	vec3 result = mix(base.rgb, outline_color, edge_mask);
	COLOR = vec4(result, base.a);
}
