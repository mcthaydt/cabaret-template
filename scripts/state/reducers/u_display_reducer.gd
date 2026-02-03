extends RefCounted
class_name U_DisplayReducer

## Display Reducer (Display Manager Phase 0 - Task 0C.2)
##
## Pure reducer functions for Display slice state mutations. Handles window
## settings, post-processing options, UI scale, and accessibility settings with
## validation and clamping.

const U_DisplayActions := preload("res://scripts/state/actions/u_display_actions.gd")

const VALID_WINDOW_PRESETS := [
	"1280x720",
	"1600x900",
	"1920x1080",
	"2560x1440",
	"3840x2160",
]
const VALID_WINDOW_MODES := ["windowed", "fullscreen", "borderless"]
const VALID_QUALITY_PRESETS := ["low", "medium", "high", "ultra"]
const VALID_COLOR_BLIND_MODES := ["normal", "deuteranopia", "protanopia", "tritanopia"]
const VALID_DITHER_PATTERNS := ["bayer", "noise"]

const DEFAULT_DISPLAY_STATE := {
	"window_size_preset": "1920x1080",
	"window_mode": "windowed",
	"vsync_enabled": true,
	"quality_preset": "high",
	"film_grain_enabled": false,
	"film_grain_intensity": 0.1,
	"crt_enabled": false,
	"crt_scanline_intensity": 0.3,
	"crt_curvature": 2.0,
	"crt_chromatic_aberration": 0.002,
	"dither_enabled": false,
	"dither_intensity": 0.5,
	"dither_pattern": "bayer",
	"lut_enabled": false,
	"lut_resource": "",
	"lut_intensity": 1.0,
	"ui_scale": 1.0,
	"color_blind_mode": "normal",
	"high_contrast_enabled": false,
	"color_blind_shader_enabled": false,
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
	return DEFAULT_DISPLAY_STATE.duplicate(true)

static func reduce(state: Dictionary, action: Dictionary) -> Variant:
	var current := _merge_with_defaults(DEFAULT_DISPLAY_STATE, state)
	var action_type: Variant = action.get("type")

	match action_type:
		U_DisplayActions.ACTION_SET_WINDOW_SIZE_PRESET:
			var payload: Dictionary = action.get("payload", {})
			var preset: String = String(payload.get("preset", ""))
			if not VALID_WINDOW_PRESETS.has(preset):
				return null
			return _with_values(current, {"window_size_preset": preset})

		U_DisplayActions.ACTION_SET_WINDOW_MODE:
			var payload: Dictionary = action.get("payload", {})
			var mode: String = String(payload.get("mode", ""))
			if not VALID_WINDOW_MODES.has(mode):
				return null
			return _with_values(current, {"window_mode": mode})

		U_DisplayActions.ACTION_SET_VSYNC_ENABLED:
			var payload: Dictionary = action.get("payload", {})
			var enabled := bool(payload.get("enabled", true))
			return _with_values(current, {"vsync_enabled": enabled})

		U_DisplayActions.ACTION_SET_QUALITY_PRESET:
			var payload: Dictionary = action.get("payload", {})
			var preset: String = String(payload.get("preset", ""))
			if not VALID_QUALITY_PRESETS.has(preset):
				return null
			return _with_values(current, {"quality_preset": preset})

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
			if not VALID_DITHER_PATTERNS.has(pattern):
				return null
			return _with_values(current, {"dither_pattern": pattern})

		U_DisplayActions.ACTION_SET_LUT_ENABLED:
			var payload: Dictionary = action.get("payload", {})
			var enabled := bool(payload.get("enabled", false))
			return _with_values(current, {"lut_enabled": enabled})

		U_DisplayActions.ACTION_SET_LUT_RESOURCE:
			var payload: Dictionary = action.get("payload", {})
			var resource: String = String(payload.get("resource", ""))
			return _with_values(current, {"lut_resource": resource})

		U_DisplayActions.ACTION_SET_LUT_INTENSITY:
			var payload: Dictionary = action.get("payload", {})
			var raw_intensity: float = float(payload.get("intensity", 1.0))
			var clamped_intensity := clampf(raw_intensity, MIN_INTENSITY, MAX_INTENSITY)
			return _with_values(current, {"lut_intensity": clamped_intensity})

		U_DisplayActions.ACTION_SET_UI_SCALE:
			var payload: Dictionary = action.get("payload", {})
			var raw_scale: float = float(payload.get("scale", 1.0))
			var clamped_scale := clampf(raw_scale, MIN_UI_SCALE, MAX_UI_SCALE)
			return _with_values(current, {"ui_scale": clamped_scale})

		U_DisplayActions.ACTION_SET_COLOR_BLIND_MODE:
			var payload: Dictionary = action.get("payload", {})
			var mode: String = String(payload.get("mode", ""))
			if not VALID_COLOR_BLIND_MODES.has(mode):
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
