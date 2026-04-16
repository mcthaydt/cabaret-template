@icon("res://assets/editor_icons/icn_resource.svg")
extends I_AIAction
class_name RS_AIActionSetField

const U_PATH_RESOLVER := preload("res://scripts/utils/qb/u_path_resolver.gd")

@export_group("Target")
@export var field_path: String = ""

@export_group("Value")
@export_enum("float", "int", "bool", "string", "string_name") var value_type: String = "float"
@export var float_value: float = 0.0
@export var int_value: int = 0
@export var bool_value: bool = false
@export var string_value: String = ""
@export var string_name_value: StringName

func start(context: Dictionary, task_state: Dictionary) -> void:
	_apply_value(context)
	task_state[U_AITaskStateKeys.COMPLETED] = true

func tick(_context: Dictionary, _task_state: Dictionary, _delta: float) -> void:
	pass

func is_complete(_context: Dictionary, task_state: Dictionary) -> bool:
	return bool(task_state.get(U_AITaskStateKeys.COMPLETED, false))

func _apply_value(context: Dictionary) -> void:
	if field_path.is_empty():
		return

	var segments: PackedStringArray = field_path.split(".")
	if segments.is_empty():
		return

	var target_key: String = segments[segments.size() - 1]
	if target_key.is_empty():
		return

	var parent: Variant = context
	if segments.size() > 1:
		var parent_path: String = ".".join(segments.slice(0, segments.size() - 1))
		parent = U_PATH_RESOLVER.resolve(context, parent_path)

	if parent == null:
		return

	var value: Variant = _resolve_value()
	_write_value(parent, target_key, value)

func _resolve_value() -> Variant:
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

func _write_value(target: Variant, key: String, value: Variant) -> void:
	if target is Dictionary:
		var dictionary: Dictionary = target as Dictionary
		if dictionary.has(key):
			dictionary[key] = value
			return

		var key_name: StringName = StringName(key)
		if dictionary.has(key_name):
			dictionary[key_name] = value
			return

		dictionary[key] = value
		return

	if target is Object:
		var object_target: Object = target as Object
		if not _object_has_property(object_target, key):
			return
		object_target.set(key, value)

func _object_has_property(object_value: Object, property_name: String) -> bool:
	for property_info in object_value.get_property_list():
		var name_value: Variant = property_info.get("name", "")
		if str(name_value) == property_name:
			return true
	return false