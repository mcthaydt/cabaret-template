@icon("res://assets/editor_icons/icn_resource.svg")
extends "res://scripts/resources/qb/rs_base_effect.gd"
class_name RS_EffectSetField

const U_PATH_RESOLVER := preload("res://scripts/utils/qb/u_path_resolver.gd")

@export_group("Target")
@export var component_type: StringName
@export var field_name: StringName

@export_group("Value")
@export_enum("set", "add") var operation: String = "set"
@export_enum("float", "int", "bool", "string", "string_name") var value_type: String = "float"
@export var float_value: float = 0.0
@export var int_value: int = 0
@export var bool_value: bool = false
@export var string_value: String = ""
@export var string_name_value: StringName

@export_group("Dynamic Value")
@export var use_context_value: bool = false
@export var context_value_path: String = ""

@export_group("Clamp")
@export var use_clamp: bool = false
@export var clamp_min: float = 0.0
@export var clamp_max: float = 1.0

func execute(context: Dictionary) -> void:
	if component_type.is_empty() or field_name.is_empty():
		return

	var components_variant: Variant = _get_dict_value_string_or_name(context, "components")
	if not (components_variant is Dictionary):
		return
	var components: Dictionary = components_variant as Dictionary

	var component_value: Variant = null
	if components.has(component_type):
		component_value = components.get(component_type)
	else:
		component_value = _get_dict_value_string_or_name(components, String(component_type))
	if component_value == null:
		return

	var base_value: Variant = _resolve_value(context)
	if base_value == null:
		return

	var next_value: Variant = base_value
	match operation:
		"set":
			pass
		"add":
			var current_value: Variant = _read_field_value(component_value, field_name)
			if not _is_numeric(current_value) or not _is_numeric(base_value):
				return
			next_value = float(current_value) + float(base_value)
			if current_value is int and base_value is int:
				next_value = int(next_value)
		_:
			return

	if use_clamp:
		if not _is_numeric(next_value):
			return
		var clamped_value: float = clampf(float(next_value), clamp_min, clamp_max)
		next_value = int(clamped_value) if next_value is int else clamped_value

	_write_field_value(component_value, field_name, next_value)

func _resolve_value(context: Dictionary) -> Variant:
	if use_context_value:
		if context_value_path.is_empty():
			return null
		return U_PATH_RESOLVER.resolve(context, context_value_path)

	return _resolve_literal_value()

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

func _read_field_value(component: Variant, target_field_name: StringName) -> Variant:
	var key_text: String = String(target_field_name)
	if component is Dictionary:
		var dictionary: Dictionary = component as Dictionary
		if dictionary.has(target_field_name):
			return dictionary.get(target_field_name)
		if dictionary.has(key_text):
			return dictionary.get(key_text)
		return null

	if component is Object:
		var object_value: Object = component as Object
		if not _object_has_property(object_value, key_text):
			return null
		return object_value.get(key_text)

	return null

func _write_field_value(component: Variant, target_field_name: StringName, value: Variant) -> void:
	var key_text: String = String(target_field_name)
	if component is Dictionary:
		var dictionary: Dictionary = component as Dictionary
		if dictionary.has(target_field_name):
			dictionary[target_field_name] = value
			return
		dictionary[key_text] = value
		return

	if component is Object:
		var object_value: Object = component as Object
		if not _object_has_property(object_value, key_text):
			return
		object_value.set(key_text, value)

func _object_has_property(object_value: Object, property_name: String) -> bool:
	var properties: Array[Dictionary] = object_value.get_property_list()
	for property_info in properties:
		var name_value: Variant = property_info.get("name", "")
		if str(name_value) == property_name:
			return true
	return false

func _is_numeric(value: Variant) -> bool:
	return value is int or value is float

func _get_dict_value_string_or_name(dictionary: Dictionary, key: String) -> Variant:
	if dictionary.has(key):
		return dictionary.get(key)

	var key_name: StringName = StringName(key)
	if dictionary.has(key_name):
		return dictionary.get(key_name)

	return null
