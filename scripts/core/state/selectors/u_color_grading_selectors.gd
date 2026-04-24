extends RefCounted
class_name U_ColorGradingSelectors

## Color Grading Selectors
##
## Pure selector functions for reading color grading state from the display slice.
## All color grading keys use "color_grading_" prefix in the display slice.

static func get_filter_mode(state: Dictionary) -> int:
	var display := _get_display_slice(state)
	return int(display.get("color_grading_filter_mode", 0))

static func get_filter_intensity(state: Dictionary) -> float:
	var display := _get_display_slice(state)
	return float(display.get("color_grading_filter_intensity", 1.0))

static func get_exposure(state: Dictionary) -> float:
	var display := _get_display_slice(state)
	return float(display.get("color_grading_exposure", 0.0))

static func get_brightness(state: Dictionary) -> float:
	var display := _get_display_slice(state)
	return float(display.get("color_grading_brightness", 0.0))

static func get_contrast(state: Dictionary) -> float:
	var display := _get_display_slice(state)
	return float(display.get("color_grading_contrast", 1.0))

static func get_brilliance(state: Dictionary) -> float:
	var display := _get_display_slice(state)
	return float(display.get("color_grading_brilliance", 0.0))

static func get_highlights(state: Dictionary) -> float:
	var display := _get_display_slice(state)
	return float(display.get("color_grading_highlights", 0.0))

static func get_shadows(state: Dictionary) -> float:
	var display := _get_display_slice(state)
	return float(display.get("color_grading_shadows", 0.0))

static func get_saturation(state: Dictionary) -> float:
	var display := _get_display_slice(state)
	return float(display.get("color_grading_saturation", 1.0))

static func get_vibrance(state: Dictionary) -> float:
	var display := _get_display_slice(state)
	return float(display.get("color_grading_vibrance", 0.0))

static func get_warmth(state: Dictionary) -> float:
	var display := _get_display_slice(state)
	return float(display.get("color_grading_warmth", 0.0))

static func get_tint(state: Dictionary) -> float:
	var display := _get_display_slice(state)
	return float(display.get("color_grading_tint", 0.0))

static func get_sharpness(state: Dictionary) -> float:
	var display := _get_display_slice(state)
	return float(display.get("color_grading_sharpness", 0.0))

static func get_color_grading_settings(state: Dictionary) -> Dictionary:
	var display := _get_display_slice(state)
	var result := {}
	for key in display.keys():
		var key_str: String = str(key)
		if key_str.begins_with("color_grading_"):
			result[key] = display[key]
	return result

static func _get_display_slice(state: Dictionary) -> Dictionary:
	if state == null:
		return {}
	var slice: Variant = state.get("display", {})
	if slice is Dictionary:
		return slice as Dictionary
	return {}