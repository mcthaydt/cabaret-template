extends RefCounted
class_name U_CinemaGradeSelectors

## Cinema Grade Selectors
##
## Pure selector functions for reading cinema grade state from the display slice.
## All cinema grade keys use "cinema_grade_" prefix in the display slice.

static func get_filter_mode(state: Dictionary) -> int:
	var display := _get_display_slice(state)
	return int(display.get("cinema_grade_filter_mode", 0))

static func get_filter_intensity(state: Dictionary) -> float:
	var display := _get_display_slice(state)
	return float(display.get("cinema_grade_filter_intensity", 1.0))

static func get_exposure(state: Dictionary) -> float:
	var display := _get_display_slice(state)
	return float(display.get("cinema_grade_exposure", 0.0))

static func get_brightness(state: Dictionary) -> float:
	var display := _get_display_slice(state)
	return float(display.get("cinema_grade_brightness", 0.0))

static func get_contrast(state: Dictionary) -> float:
	var display := _get_display_slice(state)
	return float(display.get("cinema_grade_contrast", 1.0))

static func get_brilliance(state: Dictionary) -> float:
	var display := _get_display_slice(state)
	return float(display.get("cinema_grade_brilliance", 0.0))

static func get_highlights(state: Dictionary) -> float:
	var display := _get_display_slice(state)
	return float(display.get("cinema_grade_highlights", 0.0))

static func get_shadows(state: Dictionary) -> float:
	var display := _get_display_slice(state)
	return float(display.get("cinema_grade_shadows", 0.0))

static func get_saturation(state: Dictionary) -> float:
	var display := _get_display_slice(state)
	return float(display.get("cinema_grade_saturation", 1.0))

static func get_vibrance(state: Dictionary) -> float:
	var display := _get_display_slice(state)
	return float(display.get("cinema_grade_vibrance", 0.0))

static func get_warmth(state: Dictionary) -> float:
	var display := _get_display_slice(state)
	return float(display.get("cinema_grade_warmth", 0.0))

static func get_tint(state: Dictionary) -> float:
	var display := _get_display_slice(state)
	return float(display.get("cinema_grade_tint", 0.0))

static func get_sharpness(state: Dictionary) -> float:
	var display := _get_display_slice(state)
	return float(display.get("cinema_grade_sharpness", 0.0))

static func get_cinema_grade_settings(state: Dictionary) -> Dictionary:
	var display := _get_display_slice(state)
	var result := {}
	for key in display.keys():
		var key_str: String = str(key)
		if key_str.begins_with("cinema_grade_"):
			result[key] = display[key]
	return result

static func _get_display_slice(state: Dictionary) -> Dictionary:
	if state == null:
		return {}
	var slice: Variant = state.get("display", {})
	if slice is Dictionary:
		return slice as Dictionary
	return {}
