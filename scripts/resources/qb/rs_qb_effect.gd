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

@export var effect_type: EffectType = EffectType.SET_QUALITY
@export var target: String = ""
@export var payload: Dictionary = {}

func get_payload_operation() -> StringName:
	return StringName(payload.get("operation", OPERATION_SET))

func get_payload_value_type() -> int:
	return int(payload.get("value_type", QB_CONDITION.ValueType.BOOL))

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
