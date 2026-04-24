@icon("res://assets/editor_icons/icn_resource.svg")
extends "res://scripts/core/resources/qb/rs_base_condition.gd"
class_name RS_ConditionEventPayload

const U_PATH_RESOLVER := preload("res://scripts/utils/qb/u_path_resolver.gd")

@export_group("Source")
@export var field_path: String = ""

@export_group("Match")
@export_enum("exists", "normalize", "equals", "not_equals") var match_mode: String = "exists"
@export var match_value_string: String = ""

@export_group("Normalize")
@export var range_min: float = 0.0
@export var range_max: float = 1.0

func _evaluate_raw(context: Dictionary) -> float:
	var payload: Dictionary = _get_event_payload(context)
	if payload.is_empty():
		return 0.0

	var value: Variant = payload if field_path.is_empty() else U_PATH_RESOLVER.resolve(payload, field_path)
	match match_mode:
		"exists":
			return 1.0 if value != null else 0.0
		"normalize":
			if value == null:
				return 0.0
			return _score_numeric_or_bool(value, range_min, range_max)
		"equals":
			if value == null:
				return 0.0
			return 1.0 if _matches_string(value, match_value_string) else 0.0
		"not_equals":
			if value == null:
				return 0.0
			return 0.0 if _matches_string(value, match_value_string) else 1.0
		_:
			return 0.0

func _get_event_payload(context: Dictionary) -> Dictionary:
	var payload_variant: Variant = _get_dict_value_string_or_name(context, "event_payload")
	if payload_variant is Dictionary:
		return payload_variant as Dictionary

	var event_variant: Variant = _get_dict_value_string_or_name(context, "event")
	if event_variant is Dictionary:
		var event_dictionary: Dictionary = event_variant as Dictionary
		var nested_payload: Variant = _get_dict_value_string_or_name(event_dictionary, "payload")
		if nested_payload is Dictionary:
			return nested_payload as Dictionary

	return {}
