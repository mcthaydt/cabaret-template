extends RefCounted
class_name U_ColorGradingActions

## Color Grading Actions
##
## Action creators for color grading state. Uses "color_grading/" prefix which
## is NOT persisted to global_settings.json (not a user setting).


const ACTION_LOAD_SCENE_GRADE := StringName("color_grading/load_scene_grade")
const ACTION_SET_PARAMETER := StringName("color_grading/set_parameter")
const ACTION_RESET_TO_SCENE_DEFAULTS := StringName("color_grading/reset_to_scene_defaults")

static func _static_init() -> void:
	U_ActionRegistry.register_action(ACTION_LOAD_SCENE_GRADE)
	U_ActionRegistry.register_action(ACTION_SET_PARAMETER)
	U_ActionRegistry.register_action(ACTION_RESET_TO_SCENE_DEFAULTS)

static func load_scene_grade(grade_dict: Dictionary) -> Dictionary:
	return {
		"type": ACTION_LOAD_SCENE_GRADE,
		"payload": grade_dict,
		"immediate": true,
	}

static func set_parameter(param_name: String, value: Variant) -> Dictionary:
	return {
		"type": ACTION_SET_PARAMETER,
		"payload": {"param_name": param_name, "value": value},
		"immediate": true,
	}

static func reset_to_scene_defaults(grade_dict: Dictionary) -> Dictionary:
	return {
		"type": ACTION_RESET_TO_SCENE_DEFAULTS,
		"payload": grade_dict,
		"immediate": true,
	}