extends RefCounted
class_name U_DisplayActions

## Display Actions (Display Manager Phase 0 - Task 0B.2)
##
## Action creators for Display slice mutations. All actions are registered with
## U_ActionRegistry for validation and dispatched via M_StateStore.

const U_ActionRegistry := preload("res://scripts/state/utils/u_action_registry.gd")

# Graphics
const ACTION_SET_WINDOW_SIZE_PRESET := StringName("display/set_window_size_preset")
const ACTION_SET_WINDOW_MODE := StringName("display/set_window_mode")
const ACTION_SET_VSYNC_ENABLED := StringName("display/set_vsync_enabled")
const ACTION_SET_QUALITY_PRESET := StringName("display/set_quality_preset")

# Post-Processing
const ACTION_SET_FILM_GRAIN_ENABLED := StringName("display/set_film_grain_enabled")
const ACTION_SET_FILM_GRAIN_INTENSITY := StringName("display/set_film_grain_intensity")
const ACTION_SET_OUTLINE_ENABLED := StringName("display/set_outline_enabled")
const ACTION_SET_OUTLINE_THICKNESS := StringName("display/set_outline_thickness")
const ACTION_SET_OUTLINE_COLOR := StringName("display/set_outline_color")
const ACTION_SET_DITHER_ENABLED := StringName("display/set_dither_enabled")
const ACTION_SET_DITHER_INTENSITY := StringName("display/set_dither_intensity")
const ACTION_SET_DITHER_PATTERN := StringName("display/set_dither_pattern")
const ACTION_SET_LUT_ENABLED := StringName("display/set_lut_enabled")
const ACTION_SET_LUT_RESOURCE := StringName("display/set_lut_resource")
const ACTION_SET_LUT_INTENSITY := StringName("display/set_lut_intensity")

# UI
const ACTION_SET_UI_SCALE := StringName("display/set_ui_scale")

# Accessibility
const ACTION_SET_COLOR_BLIND_MODE := StringName("display/set_color_blind_mode")
const ACTION_SET_HIGH_CONTRAST_ENABLED := StringName("display/set_high_contrast_enabled")
const ACTION_SET_COLOR_BLIND_SHADER_ENABLED := StringName("display/set_color_blind_shader_enabled")

static func _static_init() -> void:
	U_ActionRegistry.register_action(ACTION_SET_WINDOW_SIZE_PRESET)
	U_ActionRegistry.register_action(ACTION_SET_WINDOW_MODE)
	U_ActionRegistry.register_action(ACTION_SET_VSYNC_ENABLED)
	U_ActionRegistry.register_action(ACTION_SET_QUALITY_PRESET)
	U_ActionRegistry.register_action(ACTION_SET_FILM_GRAIN_ENABLED)
	U_ActionRegistry.register_action(ACTION_SET_FILM_GRAIN_INTENSITY)
	U_ActionRegistry.register_action(ACTION_SET_OUTLINE_ENABLED)
	U_ActionRegistry.register_action(ACTION_SET_OUTLINE_THICKNESS)
	U_ActionRegistry.register_action(ACTION_SET_OUTLINE_COLOR)
	U_ActionRegistry.register_action(ACTION_SET_DITHER_ENABLED)
	U_ActionRegistry.register_action(ACTION_SET_DITHER_INTENSITY)
	U_ActionRegistry.register_action(ACTION_SET_DITHER_PATTERN)
	U_ActionRegistry.register_action(ACTION_SET_LUT_ENABLED)
	U_ActionRegistry.register_action(ACTION_SET_LUT_RESOURCE)
	U_ActionRegistry.register_action(ACTION_SET_LUT_INTENSITY)
	U_ActionRegistry.register_action(ACTION_SET_UI_SCALE)
	U_ActionRegistry.register_action(ACTION_SET_COLOR_BLIND_MODE)
	U_ActionRegistry.register_action(ACTION_SET_HIGH_CONTRAST_ENABLED)
	U_ActionRegistry.register_action(ACTION_SET_COLOR_BLIND_SHADER_ENABLED)

# Graphics
static func set_window_size_preset(preset: String) -> Dictionary:
	return {
		"type": ACTION_SET_WINDOW_SIZE_PRESET,
		"payload": {"preset": preset},
		"immediate": true,
	}

static func set_window_mode(mode: String) -> Dictionary:
	return {
		"type": ACTION_SET_WINDOW_MODE,
		"payload": {"mode": mode},
		"immediate": true,
	}

static func set_vsync_enabled(enabled: bool) -> Dictionary:
	return {
		"type": ACTION_SET_VSYNC_ENABLED,
		"payload": {"enabled": enabled},
		"immediate": true,
	}

static func set_quality_preset(preset: String) -> Dictionary:
	return {
		"type": ACTION_SET_QUALITY_PRESET,
		"payload": {"preset": preset},
		"immediate": true,
	}

# Post-Processing
static func set_film_grain_enabled(enabled: bool) -> Dictionary:
	return {
		"type": ACTION_SET_FILM_GRAIN_ENABLED,
		"payload": {"enabled": enabled},
		"immediate": true,
	}

static func set_film_grain_intensity(intensity: float) -> Dictionary:
	return {
		"type": ACTION_SET_FILM_GRAIN_INTENSITY,
		"payload": {"intensity": intensity},
		"immediate": true,
	}

static func set_outline_enabled(enabled: bool) -> Dictionary:
	return {
		"type": ACTION_SET_OUTLINE_ENABLED,
		"payload": {"enabled": enabled},
		"immediate": true,
	}

static func set_outline_thickness(thickness: float) -> Dictionary:
	return {
		"type": ACTION_SET_OUTLINE_THICKNESS,
		"payload": {"thickness": thickness},
		"immediate": true,
	}

static func set_outline_color(color: String) -> Dictionary:
	return {
		"type": ACTION_SET_OUTLINE_COLOR,
		"payload": {"color": color},
		"immediate": true,
	}

static func set_dither_enabled(enabled: bool) -> Dictionary:
	return {
		"type": ACTION_SET_DITHER_ENABLED,
		"payload": {"enabled": enabled},
		"immediate": true,
	}

static func set_dither_intensity(intensity: float) -> Dictionary:
	return {
		"type": ACTION_SET_DITHER_INTENSITY,
		"payload": {"intensity": intensity},
		"immediate": true,
	}

static func set_dither_pattern(pattern: String) -> Dictionary:
	return {
		"type": ACTION_SET_DITHER_PATTERN,
		"payload": {"pattern": pattern},
		"immediate": true,
	}

static func set_lut_enabled(enabled: bool) -> Dictionary:
	return {
		"type": ACTION_SET_LUT_ENABLED,
		"payload": {"enabled": enabled},
		"immediate": true,
	}

static func set_lut_resource(resource: String) -> Dictionary:
	return {
		"type": ACTION_SET_LUT_RESOURCE,
		"payload": {"resource": resource},
		"immediate": true,
	}

static func set_lut_intensity(intensity: float) -> Dictionary:
	return {
		"type": ACTION_SET_LUT_INTENSITY,
		"payload": {"intensity": intensity},
		"immediate": true,
	}

# UI
static func set_ui_scale(scale: float) -> Dictionary:
	return {
		"type": ACTION_SET_UI_SCALE,
		"payload": {"scale": scale},
		"immediate": true,
	}

# Accessibility
static func set_color_blind_mode(mode: String) -> Dictionary:
	return {
		"type": ACTION_SET_COLOR_BLIND_MODE,
		"payload": {"mode": mode},
		"immediate": true,
	}

static func set_high_contrast_enabled(enabled: bool) -> Dictionary:
	return {
		"type": ACTION_SET_HIGH_CONTRAST_ENABLED,
		"payload": {"enabled": enabled},
		"immediate": true,
	}

static func set_color_blind_shader_enabled(enabled: bool) -> Dictionary:
	return {
		"type": ACTION_SET_COLOR_BLIND_SHADER_ENABLED,
		"payload": {"enabled": enabled},
		"immediate": true,
	}
