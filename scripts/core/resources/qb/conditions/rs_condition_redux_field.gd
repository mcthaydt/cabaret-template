@icon("res://assets/editor_icons/icn_resource.svg")
extends "res://scripts/core/resources/qb/rs_base_condition.gd"
class_name RS_ConditionReduxField

const U_PATH_RESOLVER := preload("res://scripts/utils/qb/u_path_resolver.gd")

@export_group("Source")
@export var state_path: String = ""

@export_group("Match")
@export_enum("normalize", "equals", "not_equals") var match_mode: String = "normalize"
@export var match_value_string: String = ""

@export_group("Normalize")
@export var range_min: float = 0.0
@export var range_max: float = 1.0

func _evaluate_raw(context: Dictionary) -> float:
	var state: Dictionary = _get_redux_state(context)
	if state.is_empty():
		return 0.0

	var value: Variant = state if state_path.is_empty() else U_PATH_RESOLVER.resolve(state, state_path)
	if value == null:
		return 0.0

	match match_mode:
		"normalize":
			return _score_numeric_or_bool(value, range_min, range_max)
		"equals":
			return 1.0 if _matches_string(value, match_value_string) else 0.0
		"not_equals":
			return 0.0 if _matches_string(value, match_value_string) else 1.0
		_:
			return 0.0

func _get_redux_state(context: Dictionary) -> Dictionary:
	var redux_variant: Variant = _get_dict_value_string_or_name(context, "redux_state")
	if redux_variant is Dictionary:
		return redux_variant as Dictionary

	var state_variant: Variant = _get_dict_value_string_or_name(context, "state")
	if state_variant is Dictionary:
		return state_variant as Dictionary

	return {}
