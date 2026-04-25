@icon("res://assets/core/editor_icons/icn_resource.svg")
extends RS_BTNode
class_name RS_BTPlannerAction

var _preconditions: Array[I_Condition] = []
var _effects: Array[RS_WorldStateEffect] = []
var _runtime_preconditions: Array[Object] = []
var _runtime_effects: Array[Object] = []
var _child: RS_BTNode = null

@export var preconditions: Array = []:
	get:
		return _preconditions
	set(value):
		_preconditions = _coerce_preconditions(value)
		_runtime_preconditions = _coerce_runtime_preconditions(value)

@export var effects: Array = []:
	get:
		return _effects
	set(value):
		_effects = _coerce_effects(value)
		_runtime_effects = _coerce_runtime_effects(value)

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
	for condition_variant in _get_runtime_preconditions():
		if not (condition_variant is Object):
			continue
		var condition: Object = condition_variant as Object
		if condition == null or not condition.has_method("evaluate"):
			continue
		var score_variant: Variant = condition.call("evaluate", state)
		if not (score_variant is float or score_variant is int):
			return false
		if float(score_variant) <= 0.0:
			return false
	return true

func get_effect_sequence() -> Array:
	if not _effects.is_empty():
		var typed_effects: Array = []
		typed_effects.append_array(_effects)
		return typed_effects
	return _runtime_effects.duplicate()

func _validate_property(property: Dictionary) -> void:
	var name: String = str(property.get("name", ""))
	if name == "preconditions":
		property["hint_string"] = "Array[I_Condition]"
	elif name == "effects":
		property["hint_string"] = "Array[RS_WorldStateEffect]"

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

func _coerce_runtime_preconditions(value: Variant) -> Array[Object]:
	var coerced: Array[Object] = []
	if not (value is Array):
		return coerced
	for condition_variant in value as Array:
		if not (condition_variant is Object):
			continue
		var condition: Object = condition_variant as Object
		if condition == null or not condition.has_method("evaluate"):
			continue
		coerced.append(condition)
	return coerced

func _coerce_runtime_effects(value: Variant) -> Array[Object]:
	var coerced: Array[Object] = []
	if not (value is Array):
		return coerced
	for effect_variant in value as Array:
		if not (effect_variant is Object):
			continue
		var effect: Object = effect_variant as Object
		if effect == null or not effect.has_method("apply_to"):
			continue
		coerced.append(effect)
	return coerced

func _get_runtime_preconditions() -> Array[Object]:
	if not _preconditions.is_empty():
		var typed_conditions: Array[Object] = []
		for condition: I_Condition in _preconditions:
			if condition == null:
				continue
			typed_conditions.append(condition as Object)
		return typed_conditions
	return _runtime_preconditions.duplicate()
