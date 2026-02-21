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

@export_group("Scoring")
## Optional response curve. Null = binary scoring (1.0 if pass, 0.0 if fail).
@export var score_curve: Curve = null
## Minimum value mapped to 0.0 on the curve input. Ignored for boolean conditions.
@export var normalize_min: float = 0.0
## Maximum value mapped to 1.0 on the curve input. Ignored for boolean conditions.
@export var normalize_max: float = 1.0

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

## Returns the score for this condition given the resolved quality value.
## Requires the condition to have already passed its boolean evaluation.
## Null curve = binary 1.0. Boolean values bypass normalization.
func get_score(quality_value: Variant) -> float:
	if score_curve == null:
		return 1.0

	if quality_value is bool:
		var bool_normalized: float = 1.0 if bool(quality_value) else 0.0
		return clampf(score_curve.sample_baked(bool_normalized), 0.0, 1.0)

	var numeric: float = float(quality_value) if (quality_value is float or quality_value is int) else 0.0
	var normalized: float
	if normalize_min == normalize_max:
		normalized = 1.0 if numeric >= normalize_max else 0.0
	else:
		normalized = clampf((numeric - normalize_min) / (normalize_max - normalize_min), 0.0, 1.0)
	return clampf(score_curve.sample_baked(normalized), 0.0, 1.0)
