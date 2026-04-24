@icon("res://assets/editor_icons/icn_resource.svg")
extends "res://scripts/resources/qb/rs_base_effect.gd"
class_name RS_EffectSetContextValue

@export var context_key: StringName
@export_enum("float", "int", "bool", "string", "string_name") var value_type: String = "bool"
@export var float_value: float = 0.0
@export var int_value: int = 0
@export var bool_value: bool = false
@export var string_value: String = ""
@export var string_name_value: StringName

func execute(context: Dictionary) -> void:
	if context_key.is_empty():
		return

	context[context_key] = _resolve_literal_value()

func _resolve_literal_value() -> Variant:
	match value_type:
		"float":
			return float_value
		"int":
			return int_value
		"bool":
			return bool_value
		"string":
			return string_value
		"string_name":
			return string_name_value
		_:
			return null
