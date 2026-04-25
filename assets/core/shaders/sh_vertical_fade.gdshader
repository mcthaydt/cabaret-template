shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded;

uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 0.65);
uniform float fade_start = -1.0;
uniform float fade_height = 2.0;

varying float v_height;

void vertex() {
	v_height = VERTEX.y;
}

void fragment() {
	float fade = 0.0;
	if (fade_height > 0.0001) {
		fade = clamp((v_height - fade_start) / fade_height, 0.0, 1.0);
	}
	ALBEDO = color.rgb;
	ALPHA = color.a * (1.0 - fade);
}
