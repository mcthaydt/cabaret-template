extends RefCounted

class_name SessionReducer

static func get_slice_name() -> StringName:
	return StringName("session")

static func get_initial_state() -> Dictionary:
	return {
		"slot": 0,
		"last_saved_tick": 0,
		"flags": {},
	}

static func get_persistable() -> bool:
	return true

static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
	var normalized := _normalize_state(state)
	var action_type: StringName = action.get("type", StringName(""))

	match action_type:
		StringName("@@INIT"):
			return get_initial_state()
		StringName("session/set_slot"):
			return _apply_set_slot(normalized, action)
		StringName("session/set_last_saved_tick"):
			return _apply_set_last_saved_tick(normalized, action)
		StringName("session/set_flag"):
			return _apply_set_flag(normalized, action)
		StringName("session/clear_flag"):
			return _apply_clear_flag(normalized, action)
		_:
			return normalized

static func _normalize_state(state: Dictionary) -> Dictionary:
	if typeof(state) != TYPE_DICTIONARY or state.is_empty():
		return get_initial_state()

	return {
		"slot": int(state.get("slot", 0)),
		"last_saved_tick": int(state.get("last_saved_tick", 0)),
		"flags": _duplicate_dictionary(state.get("flags", {})),
	}

static func _apply_set_slot(state: Dictionary, action: Dictionary) -> Dictionary:
	var next := state.duplicate(true)
	next["slot"] = int(action.get("payload", 0))
	return next

static func _apply_set_last_saved_tick(state: Dictionary, action: Dictionary) -> Dictionary:
	var next := state.duplicate(true)
	next["last_saved_tick"] = int(action.get("payload", 0))
	return next

static func _apply_set_flag(state: Dictionary, action: Dictionary) -> Dictionary:
	var next := state.duplicate(true)
	var flags: Dictionary = next.get("flags", {}).duplicate(true)
	var payload_variant: Variant = action.get("payload", {})
	if typeof(payload_variant) != TYPE_DICTIONARY:
		next["flags"] = flags
		return next
	var payload: Dictionary = payload_variant
	var key_variant: Variant = payload.get("key")
	if key_variant == null:
		next["flags"] = flags
		return next
	var value_variant: Variant = payload.get("value", false)
	flags[key_variant] = value_variant
	next["flags"] = flags
	return next

static func _apply_clear_flag(state: Dictionary, action: Dictionary) -> Dictionary:
	var next := state.duplicate(true)
	var flags: Dictionary = next.get("flags", {}).duplicate(true)
	var key_variant: Variant = action.get("payload")
	if key_variant != null:
		flags.erase(key_variant)
	next["flags"] = flags
	return next

static func _duplicate_dictionary(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	return {}
