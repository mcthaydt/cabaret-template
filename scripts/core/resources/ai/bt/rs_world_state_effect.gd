class_name RS_WorldStateEffect
extends Resource

enum Op {
	SET,
	ADD,
	REMOVE,
}

@export var key: StringName = &""
@export var value: Variant
@export var op: Op = Op.SET

func apply_to(state: Dictionary) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	match op:
		Op.SET:
			next_state[key] = value
		Op.ADD:
			var current_value: Variant = next_state.get(key, 0)
			if not _is_numeric(current_value):
				push_error("RS_WorldStateEffect.apply_to: ADD requires numeric current value for key '%s'" % String(key))
				return next_state
			if not _is_numeric(value):
				push_error("RS_WorldStateEffect.apply_to: ADD requires numeric value for key '%s'" % String(key))
				return next_state
			next_state[key] = current_value + value
		Op.REMOVE:
			next_state.erase(key)
		_:
			push_error("RS_WorldStateEffect.apply_to: unsupported operation %s" % [op])
	return next_state

static func apply_all(state: Dictionary, effects: Array[RS_WorldStateEffect]) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	for effect: RS_WorldStateEffect in effects:
		if effect == null:
			push_error("RS_WorldStateEffect.apply_all: null effect in effects array")
			continue
		next_state = effect.apply_to(next_state)
	return next_state

func _is_numeric(candidate: Variant) -> bool:
	return candidate is int or candidate is float
