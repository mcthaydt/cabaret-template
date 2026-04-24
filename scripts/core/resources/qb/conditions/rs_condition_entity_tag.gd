@icon("res://assets/editor_icons/icn_resource.svg")
extends "res://scripts/core/resources/qb/rs_base_condition.gd"
class_name RS_ConditionEntityTag

@export var tag_name: StringName

func _evaluate_raw(context: Dictionary) -> float:
	var tags_variant: Variant = _get_dict_value_string_or_name(context, "entity_tags")
	if not (tags_variant is Array):
		return 0.0

	var tags: Array = tags_variant as Array
	for tag_variant in tags:
		if tag_variant == tag_name:
			return 1.0
		if tag_variant is String and StringName(tag_variant) == tag_name:
			return 1.0

	return 0.0
