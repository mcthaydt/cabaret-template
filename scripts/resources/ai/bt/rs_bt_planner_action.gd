@icon("res://assets/editor_icons/icn_resource.svg")
extends RS_BTNode
class_name RS_BTPlannerAction

var _preconditions: Array[I_Condition] = []
var _effects: Array[RS_WorldStateEffect] = []
var _child: RS_BTNode = null

@export var preconditions: Array[I_Condition] = []:
	get:
		return _preconditions
	set(value):
		_preconditions = _coerce_preconditions(value)

@export var effects: Array[RS_WorldStateEffect] = []:
	get:
		return _effects
	set(value):
		_effects = _coerce_effects(value)

@export var cost: float = 1.0

@export var child: RS_BTNode = null:
	get:
		return _child
	set(value):
		_child = value if value is RS_BTNode else null

func is_applicable(state: Dictionary) -> bool:
	if cost <= 0.0:
		push_error("RS_BTPlannerAction.is_applicable: cost must be > 0.0")
		return false
	for condition: I_Condition in _preconditions:
		if condition == null:
			continue
		if condition.evaluate(state) <= 0.0:
			return false
	return true

func tick(context: Dictionary, state_bag: Dictionary) -> Status:
	if _child == null:
		push_error("RS_BTPlannerAction.tick: child is null")
		return Status.FAILURE
	return _child.tick(context, state_bag)

func _coerce_preconditions(value: Variant) -> Array[I_Condition]:
	var coerced: Array[I_Condition] = []
	if not (value is Array):
		return coerced
	for condition_variant in value as Array:
		if condition_variant is I_Condition:
			coerced.append(condition_variant as I_Condition)
	return coerced

func _coerce_effects(value: Variant) -> Array[RS_WorldStateEffect]:
	var coerced: Array[RS_WorldStateEffect] = []
	if not (value is Array):
		return coerced
	for effect_variant in value as Array:
		if effect_variant is RS_WorldStateEffect:
			coerced.append(effect_variant as RS_WorldStateEffect)
	return coerced
