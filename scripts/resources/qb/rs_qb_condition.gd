@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_QBCondition

enum Source {
	COMPONENT,
	REDUX,
	EVENT_PAYLOAD,
	ENTITY_TAG,
	CUSTOM,
}

enum Operator {
	EQUALS,
	NOT_EQUALS,
	GREATER_THAN,
	LESS_THAN,
	GTE,
	LTE,
	HAS,
	NOT_HAS,
	IS_TRUE,
	IS_FALSE,
}

enum ValueType {
	FLOAT,
	INT,
	STRING,
	BOOL,
	STRING_NAME,
}

@export_group("Source")
@export var source: Source = Source.CUSTOM
@export var quality_path: String = ""

@export_group("Comparison")
@export var operator: Operator = Operator.EQUALS
@export var negate: bool = false

@export_group("Value")
@export var value_type: ValueType = ValueType.BOOL
@export var value_float: float = 0.0
@export var value_int: int = 0
@export var value_string: String = ""
@export var value_bool: bool = false
@export var value_string_name: StringName = &""

func get_typed_value() -> Variant:
	match value_type:
		ValueType.FLOAT:
			return value_float
		ValueType.INT:
			return value_int
		ValueType.STRING:
			return value_string
		ValueType.BOOL:
			return value_bool
		ValueType.STRING_NAME:
			return value_string_name
	return null
