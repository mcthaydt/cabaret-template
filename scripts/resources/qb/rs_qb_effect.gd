@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_QBEffect

const QB_CONDITION := preload("res://scripts/resources/qb/rs_qb_condition.gd")

enum EffectType {
	DISPATCH_ACTION,
	PUBLISH_EVENT,
	SET_COMPONENT_FIELD,
	SET_QUALITY,
}

const OPERATION_SET := StringName("set")
const OPERATION_ADD := StringName("add")
const INVALID_VALUE_TYPE := -1
const VALUE_TYPE_NAME_BY_ID := {
	QB_CONDITION.ValueType.FLOAT: StringName("FLOAT"),
	QB_CONDITION.ValueType.INT: StringName("INT"),
	QB_CONDITION.ValueType.STRING: StringName("STRING"),
	QB_CONDITION.ValueType.BOOL: StringName("BOOL"),
	QB_CONDITION.ValueType.STRING_NAME: StringName("STRING_NAME"),
}
const VALUE_TYPE_ID_BY_NAME := {
	StringName("FLOAT"): QB_CONDITION.ValueType.FLOAT,
	StringName("INT"): QB_CONDITION.ValueType.INT,
	StringName("STRING"): QB_CONDITION.ValueType.STRING,
	StringName("BOOL"): QB_CONDITION.ValueType.BOOL,
	StringName("STRING_NAME"): QB_CONDITION.ValueType.STRING_NAME,
}

@export var effect_type: EffectType = EffectType.SET_QUALITY
@export var target: String = ""
@export var payload: Dictionary = {}

func get_payload_operation() -> StringName:
	return StringName(payload.get("operation", OPERATION_SET))

func get_payload_value_type() -> int:
	return parse_payload_value_type(payload.get("value_type", QB_CONDITION.ValueType.BOOL))

func get_payload_typed_value() -> Variant:
	var payload_value_type := get_payload_value_type()
	match payload_value_type:
		QB_CONDITION.ValueType.FLOAT:
			return float(payload.get("value_float", 0.0))
		QB_CONDITION.ValueType.INT:
			return int(payload.get("value_int", 0))
		QB_CONDITION.ValueType.STRING:
			return String(payload.get("value_string", ""))
		QB_CONDITION.ValueType.BOOL:
			return bool(payload.get("value_bool", false))
		QB_CONDITION.ValueType.STRING_NAME:
			return StringName(payload.get("value_string_name", &""))
	return null

static func parse_payload_value_type(raw_value: Variant, fallback: int = QB_CONDITION.ValueType.BOOL) -> int:
	var parsed: int = try_parse_payload_value_type(raw_value)
	if parsed == INVALID_VALUE_TYPE:
		return fallback
	return parsed

static func try_parse_payload_value_type(raw_value: Variant) -> int:
	if raw_value is int:
		var value_type: int = int(raw_value)
		if VALUE_TYPE_NAME_BY_ID.has(value_type):
			return value_type
		return INVALID_VALUE_TYPE

	if raw_value is String or raw_value is StringName:
		var normalized_name: StringName = _normalize_value_type_name(raw_value)
		if normalized_name != &"" and VALUE_TYPE_ID_BY_NAME.has(normalized_name):
			return int(VALUE_TYPE_ID_BY_NAME.get(normalized_name))
		return INVALID_VALUE_TYPE

	return INVALID_VALUE_TYPE

static func _normalize_value_type_name(raw_value: Variant) -> StringName:
	var value_type_name: String = String(raw_value).strip_edges().to_upper()
	if value_type_name.is_empty():
		return &""

	var dot_index: int = value_type_name.rfind(".")
	if dot_index != -1 and dot_index < value_type_name.length() - 1:
		value_type_name = value_type_name.substr(dot_index + 1)

	return StringName(value_type_name)
