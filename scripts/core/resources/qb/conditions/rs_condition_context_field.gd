@icon("res://assets/editor_icons/icn_resource.svg")
extends "res://scripts/core/resources/qb/rs_base_condition.gd"
class_name RS_ConditionContextField

const U_PATH_RESOLVER := preload("res://scripts/utils/qb/u_path_resolver.gd")

@export_group("Source")
@export var field_path: String = ""

@export_group("Match")
@export_enum("normalize", "equals", "not_equals") var match_mode: String = "normalize"
@export var match_value_string: String = ""

@export_group("Normalize")
@export var range_min: float = 0.0
@export var range_max: float = 1.0

func _evaluate_raw(context: Dictionary) -> float:
	var value: Variant = context if field_path.is_empty() else U_PATH_RESOLVER.resolve(context, field_path)
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
