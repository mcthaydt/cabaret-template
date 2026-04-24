@icon("res://assets/editor_icons/icn_resource.svg")
extends "res://scripts/resources/qb/rs_base_condition.gd"
class_name RS_ConditionComponentField

const U_PATH_RESOLVER := preload("res://scripts/utils/qb/u_path_resolver.gd")

@export_group("Source")
@export var component_type: StringName
@export var field_path: String = ""

@export_group("Normalize")
@export var range_min: float = 0.0
@export var range_max: float = 1.0

func _evaluate_raw(context: Dictionary) -> float:
	var components_variant: Variant = _get_dict_value_string_or_name(context, "components")
	if not (components_variant is Dictionary):
		return 0.0

	if component_type.is_empty():
		return 0.0

	var components: Dictionary = components_variant as Dictionary
	var component_value: Variant = null
	if components.has(component_type):
		component_value = components.get(component_type)
	else:
		var component_key: String = String(component_type)
		component_value = _get_dict_value_string_or_name(components, component_key)

	if component_value == null:
		return 0.0

	var resolved_value: Variant = component_value if field_path.is_empty() else U_PATH_RESOLVER.resolve(component_value, field_path)
	if resolved_value == null:
		return 0.0

	return _score_numeric_or_bool(resolved_value, range_min, range_max)
