@icon("res://assets/editor_icons/icn_resource.svg")
extends "res://scripts/resources/qb/rs_base_condition.gd"
class_name RS_ConditionEventName

@export_group("Source")
@export var expected_event_name: StringName

@export_group("Match")
@export_enum("equals", "not_equals") var match_mode: String = "equals"

func _evaluate_raw(context: Dictionary) -> float:
	var event_variant: Variant = _get_dict_value_string_or_name(context, "event_name")
	var actual_event_name: StringName = _to_string_name(event_variant)
	if actual_event_name == StringName():
		return 0.0
	if expected_event_name == StringName():
		return 0.0

	match match_mode:
		"equals":
			return 1.0 if actual_event_name == expected_event_name else 0.0
		"not_equals":
			return 0.0 if actual_event_name == expected_event_name else 1.0
		_:
			return 0.0

func _to_string_name(value: Variant) -> StringName:
	if value is StringName:
		return value
	if value is String:
		var text: String = value
		if not text.is_empty():
			return StringName(text)
	return StringName()
