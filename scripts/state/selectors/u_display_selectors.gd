extends RefCounted
class_name U_DisplaySelectors

## Display Selectors (Display Manager Phase 0 - Task 0D.2)
##
## Pure selector functions for reading Display slice state. Provides safe
## defaults when display slice or fields are missing.

static func get_window_size_preset(state: Dictionary) -> String:
	var display := _get_display_slice(state)
	return String(display.get("window_size_preset", "1920x1080"))

static func get_window_mode(state: Dictionary) -> String:
	var display := _get_display_slice(state)
	return String(display.get("window_mode", "windowed"))

static func is_vsync_enabled(state: Dictionary) -> bool:
	var display := _get_display_slice(state)
	return bool(display.get("vsync_enabled", true))

static func get_quality_preset(state: Dictionary) -> String:
	var display := _get_display_slice(state)
	return String(display.get("quality_preset", "high"))

static func is_film_grain_enabled(state: Dictionary) -> bool:
	var display := _get_display_slice(state)
	return bool(display.get("film_grain_enabled", false))

static func get_film_grain_intensity(state: Dictionary) -> float:
	var display := _get_display_slice(state)
	return float(display.get("film_grain_intensity", 0.1))

static func is_crt_enabled(state: Dictionary) -> bool:
	var display := _get_display_slice(state)
	return bool(display.get("crt_enabled", false))

static func get_crt_scanline_intensity(state: Dictionary) -> float:
	var display := _get_display_slice(state)
	return float(display.get("crt_scanline_intensity", 0.3))

static func get_crt_curvature(state: Dictionary) -> float:
	var display := _get_display_slice(state)
	return float(display.get("crt_curvature", 2.0))

static func is_dither_enabled(state: Dictionary) -> bool:
	var display := _get_display_slice(state)
	return bool(display.get("dither_enabled", false))

static func get_dither_intensity(state: Dictionary) -> float:
	var display := _get_display_slice(state)
	return float(display.get("dither_intensity", 0.5))

static func get_dither_pattern(state: Dictionary) -> String:
	var display := _get_display_slice(state)
	return String(display.get("dither_pattern", "bayer"))

static func is_lut_enabled(state: Dictionary) -> bool:
	var display := _get_display_slice(state)
	return bool(display.get("lut_enabled", false))

static func get_lut_resource(state: Dictionary) -> String:
	var display := _get_display_slice(state)
	return String(display.get("lut_resource", ""))

static func get_lut_intensity(state: Dictionary) -> float:
	var display := _get_display_slice(state)
	return float(display.get("lut_intensity", 1.0))

static func get_ui_scale(state: Dictionary) -> float:
	var display := _get_display_slice(state)
	return float(display.get("ui_scale", 1.0))

static func get_color_blind_mode(state: Dictionary) -> String:
	var display := _get_display_slice(state)
	return String(display.get("color_blind_mode", "normal"))

static func is_high_contrast_enabled(state: Dictionary) -> bool:
	var display := _get_display_slice(state)
	return bool(display.get("high_contrast_enabled", false))

static func is_color_blind_shader_enabled(state: Dictionary) -> bool:
	var display := _get_display_slice(state)
	return bool(display.get("color_blind_shader_enabled", false))

static func _get_display_slice(state: Dictionary) -> Dictionary:
	if state == null:
		return {}
	var slice: Variant = state.get("display", {})
	if slice is Dictionary:
		return slice as Dictionary
	return {}
