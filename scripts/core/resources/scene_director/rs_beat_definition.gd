@icon("res://assets/core/editor_icons/icn_resource.svg")
extends Resource
class_name RS_BeatDefinition

## Scene Director beat definition resource.

enum WaitMode {
	INSTANT = 0,
	TIMED = 1,
	SIGNAL = 2,
}

var _preconditions: Array[I_Condition] = []
var _effects: Array[I_Effect] = []

@export var beat_id: StringName = StringName("")
@export_multiline var description: String = ""
@export var preconditions: Array[I_Condition] = []:
	get:
		return _preconditions
	set(value):
		_preconditions = _sanitize_conditions(value)
@export var effects: Array[I_Effect] = []:
	get:
		return _effects
	set(value):
		_effects = _sanitize_effects(value)
@export var wait_mode: WaitMode = WaitMode.INSTANT
@export_range(0.0, 600.0, 0.01, "or_greater") var duration: float = 0.0
@export var wait_event: StringName = StringName("")

@export_group("Flow Control")
@export var next_beat_id: StringName = StringName("")
@export var next_beat_id_on_failure: StringName = StringName("")

@export_group("Parallel")
@export var parallel_beat_ids: Array[StringName] = []
@export var parallel_join_beat_id: StringName = StringName("")


func _sanitize_conditions(value: Variant) -> Array[I_Condition]:
	var sanitized: Array[I_Condition] = []
	if not (value is Array):
		return sanitized
	for condition_variant in value as Array:
		if condition_variant is I_Condition:
			sanitized.append(condition_variant as I_Condition)
	return sanitized


func _sanitize_effects(value: Variant) -> Array[I_Effect]:
	var sanitized: Array[I_Effect] = []
	if not (value is Array):
		return sanitized
	for effect_variant in value as Array:
		if effect_variant is I_Effect:
			sanitized.append(effect_variant as I_Effect)
	return sanitized
