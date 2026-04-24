@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_Rule

var _conditions: Array[I_Condition] = []
var _effects: Array[I_Effect] = []

@export_group("Identity")
@export var rule_id: StringName
@export_multiline var description: String = ""

@export_group("Trigger")
@export_enum("tick", "event", "both") var trigger_mode: String = "tick"

@export_group("Evaluation")
@export var conditions: Array[I_Condition] = []:
	get:
		return _conditions
	set(value):
		_conditions = _coerce_conditions(value)
@export var effects: Array[I_Effect] = []:
	get:
		return _effects
	set(value):
		_effects = _coerce_effects(value)
@export var score_threshold: float = 0.0

@export_group("Selection")
@export var decision_group: StringName
@export var priority: int = 0

@export_group("Behavior")
@export var cooldown: float = 0.0
@export var one_shot: bool = false
@export var requires_rising_edge: bool = false


func _coerce_conditions(value: Variant) -> Array[I_Condition]:
	var coerced: Array[I_Condition] = []
	if not (value is Array):
		return coerced
	for condition_variant in value as Array:
		if condition_variant is I_Condition:
			coerced.append(condition_variant as I_Condition)
	return coerced


func _coerce_effects(value: Variant) -> Array[I_Effect]:
	var coerced: Array[I_Effect] = []
	if not (value is Array):
		return coerced
	for effect_variant in value as Array:
		if effect_variant is I_Effect:
			coerced.append(effect_variant as I_Effect)
	return coerced
