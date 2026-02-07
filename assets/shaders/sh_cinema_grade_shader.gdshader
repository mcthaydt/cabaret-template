shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture;

// Filter: 0=none, 1=dramatic, 2=dramatic_warm, 3=dramatic_cold,
//         4=vivid, 5=vivid_warm, 6=vivid_cold, 7=black_and_white, 8=sepia
uniform int filter_mode : hint_range(0, 8) = 0;
uniform float filter_intensity : hint_range(0.0, 1.0) = 1.0;

// Core adjustments
uniform float exposure : hint_range(-3.0, 3.0) = 0.0;
uniform float brightness : hint_range(-1.0, 1.0) = 0.0;
uniform float contrast : hint_range(0.0, 3.0) = 1.0;
uniform float highlights : hint_range(-1.0, 1.0) = 0.0;
uniform float shadows : hint_range(-1.0, 1.0) = 0.0;
uniform float saturation : hint_range(0.0, 3.0) = 1.0;
uniform float vibrance : hint_range(-1.0, 1.0) = 0.0;
uniform float brilliance : hint_range(-1.0, 1.0) = 0.0;

// White balance
uniform float warmth : hint_range(-1.0, 1.0) = 0.0;
uniform float tint : hint_range(-1.0, 1.0) = 0.0;

// Detail
uniform float sharpness : hint_range(0.0, 2.0) = 0.0;

float luminance(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

vec3 apply_sharpness(sampler2D tex, vec2 uv, vec2 pixel_size, float amount) {
	if (amount <= 0.001) {
		return texture(tex, uv).rgb;
	}
	vec3 center = texture(tex, uv).rgb;
	vec3 blur = texture(tex, uv + vec2(pixel_size.x, 0.0)).rgb;
	blur += texture(tex, uv - vec2(pixel_size.x, 0.0)).rgb;
	blur += texture(tex, uv + vec2(0.0, pixel_size.y)).rgb;
	blur += texture(tex, uv - vec2(0.0, pixel_size.y)).rgb;
	blur *= 0.25;
	return center + (center - blur) * amount;
}

vec3 apply_filter(vec3 color, int mode) {
	float luma = luminance(color);

	if (mode == 1) {
		// Dramatic
		color = (color - 0.5) * 1.4 + 0.5;
		float h_mask = smoothstep(0.4, 0.7, luma);
		color -= h_mask * 0.1;
		float s_mask = 1.0 - smoothstep(0.3, 0.6, luma);
		color += s_mask * 0.15;
		color = mix(vec3(luminance(color)), color, 0.85);
	} else if (mode == 2) {
		// Dramatic Warm
		color = (color - 0.5) * 1.4 + 0.5;
		float h_mask = smoothstep(0.4, 0.7, luma);
		color -= h_mask * 0.1;
		float s_mask = 1.0 - smoothstep(0.3, 0.6, luma);
		color += s_mask * 0.15;
		color = mix(vec3(luminance(color)), color, 0.85);
		color.r += 0.04;
		color.b -= 0.06;
	} else if (mode == 3) {
		// Dramatic Cold
		color = (color - 0.5) * 1.4 + 0.5;
		float h_mask = smoothstep(0.4, 0.7, luma);
		color -= h_mask * 0.1;
		float s_mask = 1.0 - smoothstep(0.3, 0.6, luma);
		color += s_mask * 0.15;
		color = mix(vec3(luminance(color)), color, 0.85);
		color.b += 0.06;
		color.r -= 0.04;
	} else if (mode == 4) {
		// Vivid
		color = mix(vec3(luma), color, 1.5);
		color = (color - 0.5) * 1.15 + 0.5;
	} else if (mode == 5) {
		// Vivid Warm
		color = mix(vec3(luma), color, 1.5);
		color = (color - 0.5) * 1.15 + 0.5;
		color.r += 0.03;
		color.b -= 0.04;
	} else if (mode == 6) {
		// Vivid Cold
		color = mix(vec3(luma), color, 1.5);
		color = (color - 0.5) * 1.15 + 0.5;
		color.b += 0.04;
		color.r -= 0.03;
	} else if (mode == 7) {
		// Black and White
		color = vec3(luma);
		color = (color - 0.5) * 1.1 + 0.5;
	} else if (mode == 8) {
		// Sepia
		float l = luminance(color);
		color = vec3(l * 1.12 + 0.04, l * 0.95 + 0.02, l * 0.74);
	}

	// Clamp filter output to prevent negative values or values > 1.0
	return clamp(color, 0.0, 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 pixel_size = SCREEN_PIXEL_SIZE;

	// 1. Sample + Sharpness (5-tap cross unsharp mask)
	vec3 color = apply_sharpness(screen_texture, uv, pixel_size, sharpness);

	// 2. Exposure (EV stops)
	color *= pow(2.0, exposure);

	// 3. White Balance
	color.r += warmth * 0.1;
	color.b -= warmth * 0.1;
	color.g += tint * 0.1;
	color.r -= tint * 0.05;
	color.b -= tint * 0.05;

	// 4. Brilliance (inverse-luminance adaptive lift)
	float luma_brill = luminance(color);
	color += (1.0 - luma_brill) * brilliance * 0.5;

	// 5. Brightness
	color += brightness;

	// 6. Contrast
	color = (color - 0.5) * contrast + 0.5;

	// 7. Highlights / Shadows
	float luma_hs = luminance(clamp(color, 0.0, 1.0));
	float highlight_mask = smoothstep(0.5, 1.0, luma_hs);
	color += highlight_mask * highlights * 0.5;
	float shadow_mask = 1.0 - smoothstep(0.0, 0.5, luma_hs);
	color += shadow_mask * shadows * 0.5;

	// Intermediate clamp to prevent negative/extreme values from affecting saturation/vibrance
	color = clamp(color, 0.0, 1.0);

	// 8. Saturation
	float luma_sat = luminance(color);
	color = mix(vec3(luma_sat), color, saturation);

	// 9. Vibrance (selective saturation: less-saturated pixels get more boost)
	float luma_vib = luminance(color);
	vec3 sat_color = max(color, vec3(0.0));
	float max_channel = max(sat_color.r, max(sat_color.g, sat_color.b));
	float min_channel = min(sat_color.r, min(sat_color.g, sat_color.b));
	float current_sat = (max_channel - min_channel) / (max_channel + 0.001);
	float vibrance_amount = vibrance * (1.0 - current_sat);
	color = mix(vec3(luma_vib), color, 1.0 + vibrance_amount);

	// Clamp again after saturation/vibrance adjustments
	color = clamp(color, 0.0, 1.0);

	// 10. Named Filter (applied as blend)
	if (filter_mode > 0) {
		vec3 filtered = apply_filter(color, filter_mode);
		color = mix(color, filtered, filter_intensity);
		// Clamp after filter blend to prevent artifacts
		color = clamp(color, 0.0, 1.0);
	}

	// 11. Final Clamp
	color = clamp(color, 0.0, 1.0);

	// 12. Black crush - neutralize very dark pixels to prevent color casts
	float final_luma = luminance(color);
	if (final_luma < 0.02) {
		// Force near-black pixels to be neutral gray to prevent green/purple casts
		color = vec3(final_luma);
	}

	COLOR = vec4(color, 1.0);
}
