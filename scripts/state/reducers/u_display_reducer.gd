extends RefCounted
class_name U_DisplayReducer

## Display Reducer (Display Manager Phase 0 - Task 0C.2)
##
## Pure reducer functions for Display slice state mutations. Handles window
## settings, post-processing options, UI scale, and accessibility settings with
## validation and clamping.

const U_DisplayActions := preload("res://scripts/state/actions/u_display_actions.gd")
const U_CinemaGradeActions := preload("res://scripts/state/actions/u_cinema_grade_actions.gd")
const U_DISPLAY_OPTION_CATALOG := preload("res://scripts/utils/display/u_display_option_catalog.gd")
const U_PostProcessingPresetValues := preload("res://scripts/utils/display/u_post_processing_preset_values.gd")

const DEFAULT_DISPLAY_STATE := {
	"window_size_preset": "1920x1080",
	"window_mode": "windowed",
	"vsync_enabled": true,
	"quality_preset": "high",
	"post_processing_enabled": false,
	"post_processing_preset": "medium",
	"ui_scale": 1.0,
	"color_blind_mode": "normal",
	"high_contrast_enabled": false,
	# Note: Intensity values are loaded from post_processing_preset in get_default_display_state()
}

const MIN_INTENSITY := 0.0
const MAX_INTENSITY := 1.0
const MIN_CRT_CURVATURE := 0.0
const MAX_CRT_CURVATURE := 10.0
const MIN_CRT_CHROMATIC_ABERRATION := 0.0
const MAX_CRT_CHROMATIC_ABERRATION := 0.01
const MIN_UI_SCALE := 0.8
const MAX_UI_SCALE := 1.3

static func get_default_display_state() -> Dictionary:
	var state := DEFAULT_DISPLAY_STATE.duplicate(true)
	# Load intensity values from the default preset (medium)
	var preset: String = state.get("post_processing_preset", "medium")
	var preset_values := U_PostProcessingPresetValues.get_preset_values(preset)
	state["film_grain_intensity"] = preset_values.get("film_grain_intensity", 0.2)
	state["crt_scanline_intensity"] = preset_values.get("crt_scanline_intensity", 0.25)
	state["crt_curvature"] = preset_values.get("crt_curvature", 0.0)
	state["crt_chromatic_aberration"] = preset_values.get("crt_chromatic_aberration", 0.001)
	state["dither_intensity"] = preset_values.get("dither_intensity", 1.0)
	return state

static func reduce(state: Dictionary, action: Dictionary) -> Variant:
	var current := _merge_with_defaults(DEFAULT_DISPLAY_STATE, state)
	var action_type: Variant = action.get("type")

	match action_type:
		U_DisplayActions.ACTION_SET_WINDOW_SIZE_PRESET:
			var payload: Dictionary = action.get("payload", {})
			var preset: String = String(payload.get("preset", ""))
			if not _is_valid_window_preset(preset):
				return null
			return _with_values(current, {"window_size_preset": preset})

		U_DisplayActions.ACTION_SET_WINDOW_MODE:
			var payload: Dictionary = action.get("payload", {})
			var mode: String = String(payload.get("mode", ""))
			if not _is_valid_window_mode(mode):
				return null
			return _with_values(current, {"window_mode": mode})

		U_DisplayActions.ACTION_SET_VSYNC_ENABLED:
			var payload: Dictionary = action.get("payload", {})
			var enabled := bool(payload.get("enabled", true))
			return _with_values(current, {"vsync_enabled": enabled})

		U_DisplayActions.ACTION_SET_QUALITY_PRESET:
			var payload: Dictionary = action.get("payload", {})
			var preset: String = String(payload.get("preset", ""))
			if not _is_valid_quality_preset(preset):
				return null
			return _with_values(current, {"quality_preset": preset})

		U_DisplayActions.ACTION_SET_POST_PROCESSING_ENABLED:
			var payload: Dictionary = action.get("payload", {})
			var enabled := bool(payload.get("enabled", false))
			return _with_values(current, {"post_processing_enabled": enabled})

		U_DisplayActions.ACTION_SET_POST_PROCESSING_PRESET:
			var payload: Dictionary = action.get("payload", {})
			var preset: String = String(payload.get("preset", ""))
			if not _is_valid_post_processing_preset(preset):
				return null
			# Apply preset values to individual intensity settings
			var preset_values := U_PostProcessingPresetValues.get_preset_values(preset)
			return _with_values(current, {
				"post_processing_preset": preset,
				"film_grain_intensity": preset_values.get("film_grain_intensity", current.get("film_grain_intensity", 0.1)),
				"crt_scanline_intensity": preset_values.get("crt_scanline_intensity", current.get("crt_scanline_intensity", 0.3)),
				"crt_curvature": preset_values.get("crt_curvature", current.get("crt_curvature", 2.0)),
				"crt_chromatic_aberration": preset_values.get("crt_chromatic_aberration", current.get("crt_chromatic_aberration", 0.002)),
				"dither_intensity": preset_values.get("dither_intensity", current.get("dither_intensity", 0.5)),
			})

		U_DisplayActions.ACTION_SET_FILM_GRAIN_ENABLED:
			var payload: Dictionary = action.get("payload", {})
			var enabled := bool(payload.get("enabled", false))
			return _with_values(current, {"film_grain_enabled": enabled})

		U_DisplayActions.ACTION_SET_FILM_GRAIN_INTENSITY:
			var payload: Dictionary = action.get("payload", {})
			var raw_intensity: float = float(payload.get("intensity", 0.1))
			var clamped_intensity := clampf(raw_intensity, MIN_INTENSITY, MAX_INTENSITY)
			return _with_values(current, {"film_grain_intensity": clamped_intensity})

		U_DisplayActions.ACTION_SET_CRT_ENABLED:
			var payload: Dictionary = action.get("payload", {})
			var enabled := bool(payload.get("enabled", false))
			return _with_values(current, {"crt_enabled": enabled})

		U_DisplayActions.ACTION_SET_CRT_SCANLINE_INTENSITY:
			var payload: Dictionary = action.get("payload", {})
			var raw_intensity: float = float(payload.get("intensity", 0.3))
			var clamped_intensity := clampf(raw_intensity, MIN_INTENSITY, MAX_INTENSITY)
			return _with_values(current, {"crt_scanline_intensity": clamped_intensity})

		U_DisplayActions.ACTION_SET_CRT_CURVATURE:
			var payload: Dictionary = action.get("payload", {})
			var raw_curvature: float = float(payload.get("curvature", 2.0))
			var clamped_curvature := clampf(raw_curvature, MIN_CRT_CURVATURE, MAX_CRT_CURVATURE)
			return _with_values(current, {"crt_curvature": clamped_curvature})

		U_DisplayActions.ACTION_SET_CRT_CHROMATIC_ABERRATION:
			var payload: Dictionary = action.get("payload", {})
			var raw_aberration: float = float(payload.get("aberration", 0.002))
			var clamped_aberration := clampf(raw_aberration, MIN_CRT_CHROMATIC_ABERRATION, MAX_CRT_CHROMATIC_ABERRATION)
			return _with_values(current, {"crt_chromatic_aberration": clamped_aberration})

		U_DisplayActions.ACTION_SET_DITHER_ENABLED:
			var payload: Dictionary = action.get("payload", {})
			var enabled := bool(payload.get("enabled", false))
			return _with_values(current, {"dither_enabled": enabled})

		U_DisplayActions.ACTION_SET_DITHER_INTENSITY:
			var payload: Dictionary = action.get("payload", {})
			var raw_intensity: float = float(payload.get("intensity", 0.5))
			var clamped_intensity := clampf(raw_intensity, MIN_INTENSITY, MAX_INTENSITY)
			return _with_values(current, {"dither_intensity": clamped_intensity})

		U_DisplayActions.ACTION_SET_DITHER_PATTERN:
			var payload: Dictionary = action.get("payload", {})
			var pattern: String = String(payload.get("pattern", ""))
			if not _is_valid_dither_pattern(pattern):
				return null
			return _with_values(current, {"dither_pattern": pattern})

		U_DisplayActions.ACTION_SET_UI_SCALE:
			var payload: Dictionary = action.get("payload", {})
			var raw_scale: float = float(payload.get("scale", 1.0))
			var clamped_scale := clampf(raw_scale, MIN_UI_SCALE, MAX_UI_SCALE)
			return _with_values(current, {"ui_scale": clamped_scale})

		U_DisplayActions.ACTION_SET_COLOR_BLIND_MODE:
			var payload: Dictionary = action.get("payload", {})
			var mode: String = String(payload.get("mode", ""))
			if not _is_valid_color_blind_mode(mode):
				return null
			return _with_values(current, {"color_blind_mode": mode})

		U_DisplayActions.ACTION_SET_HIGH_CONTRAST_ENABLED:
			var payload: Dictionary = action.get("payload", {})
			var enabled := bool(payload.get("enabled", false))
			return _with_values(current, {"high_contrast_enabled": enabled})

		U_DisplayActions.ACTION_SET_COLOR_BLIND_SHADER_ENABLED:
			var payload: Dictionary = action.get("payload", {})
			var enabled := bool(payload.get("enabled", false))
			return _with_values(current, {"color_blind_shader_enabled": enabled})

		U_CinemaGradeActions.ACTION_LOAD_SCENE_GRADE:
			var payload: Dictionary = action.get("payload", {})
			var updates := {}
			for key in payload.keys():
				var key_str: String = str(key)
				if key_str.begins_with("cinema_grade_"):
					updates[key] = payload[key]
			if updates.is_empty():
				return null
			return _with_values(current, updates)

		U_CinemaGradeActions.ACTION_SET_PARAMETER:
			var payload: Dictionary = action.get("payload", {})
			var param_name: String = String(payload.get("param_name", ""))
			if param_name.is_empty():
				return null
			var key := "cinema_grade_" + param_name
			return _with_values(current, {key: payload.get("value")})

		U_CinemaGradeActions.ACTION_RESET_TO_SCENE_DEFAULTS:
			var payload: Dictionary = action.get("payload", {})
			var updates := {}
			for key in payload.keys():
				var key_str: String = str(key)
				if key_str.begins_with("cinema_grade_"):
					updates[key] = payload[key]
			if updates.is_empty():
				return null
			return _with_values(current, updates)

		_:
			return null

static func _merge_with_defaults(defaults: Dictionary, state: Dictionary) -> Dictionary:
	var merged := defaults.duplicate(true)
	if state == null:
		return merged
	for key in state.keys():
		merged[key] = _deep_copy(state[key])
	return merged

static func _with_values(state: Dictionary, updates: Dictionary) -> Dictionary:
	var next := state.duplicate(true)
	for key in updates.keys():
		next[key] = _deep_copy(updates[key])
	return next

static func _deep_copy(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value

static func _is_valid_window_preset(preset: String) -> bool:
	return U_DISPLAY_OPTION_CATALOG.get_window_size_ids().has(preset)

static func _is_valid_quality_preset(preset: String) -> bool:
	return U_DISPLAY_OPTION_CATALOG.get_quality_ids().has(preset)

static func _is_valid_window_mode(mode: String) -> bool:
	return U_DISPLAY_OPTION_CATALOG.get_window_mode_ids().has(mode)

static func _is_valid_dither_pattern(pattern: String) -> bool:
	return U_DISPLAY_OPTION_CATALOG.get_dither_pattern_ids().has(pattern)

static func _is_valid_color_blind_mode(mode: String) -> bool:
	return U_DISPLAY_OPTION_CATALOG.get_color_blind_mode_ids().has(mode)

static func _is_valid_post_processing_preset(preset: String) -> bool:
	return U_DISPLAY_OPTION_CATALOG.get_post_processing_preset_ids().has(preset)
