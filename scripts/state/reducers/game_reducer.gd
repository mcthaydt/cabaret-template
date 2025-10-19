extends RefCounted

class_name GameReducer

static func get_slice_name() -> StringName:
	return StringName("game")

static func get_initial_state() -> Dictionary:
	return {
		"score": 0,
		"level": 1,
		"unlocks": [],
	}

static func get_persistable() -> bool:
	return true

static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
	var normalized := _normalize_state(state)
	var action_type: StringName = action.get("type", StringName(""))

	match action_type:
		StringName("@@INIT"):
			return get_initial_state()
		StringName("game/add_score"):
			return _apply_add_score(normalized, action)
		StringName("game/set_score"):
			return _apply_set_score(normalized, action)
		StringName("game/level_up"):
			return _apply_level_up(normalized)
		StringName("game/unlock"):
			return _apply_unlock(normalized, action)
		_:
			return normalized

static func _normalize_state(state: Dictionary) -> Dictionary:
	if typeof(state) != TYPE_DICTIONARY or state.is_empty():
		return get_initial_state()

	var normalized: Dictionary = {
		"score": int(state.get("score", 0)),
		"level": int(state.get("level", 1)),
		"unlocks": [],
	}

	var unlocks_variant: Variant = state.get("unlocks", [])
	if typeof(unlocks_variant) == TYPE_ARRAY:
		normalized["unlocks"] = (unlocks_variant as Array).duplicate(true)
	else:
		normalized["unlocks"] = []

	return normalized

static func _apply_add_score(state: Dictionary, action: Dictionary) -> Dictionary:
	var next := state.duplicate(true)
	var delta: int = int(action.get("payload", 0))
	next["score"] = int(next.get("score", 0)) + delta
	return next

static func _apply_set_score(state: Dictionary, action: Dictionary) -> Dictionary:
	var next := state.duplicate(true)
	next["score"] = int(action.get("payload", 0))
	return next

static func _apply_level_up(state: Dictionary) -> Dictionary:
	var next := state.duplicate(true)
	next["level"] = int(next.get("level", 1)) + 1
	return next

static func _apply_unlock(state: Dictionary, action: Dictionary) -> Dictionary:
	var next := state.duplicate(true)
	var unlocks: Array = next.get("unlocks", [])
	var updated_unlocks: Array = unlocks.duplicate(true)
	var item_variant: Variant = action.get("payload")
	if item_variant == null:
		return next
	var item_value: String = str(item_variant)
	if item_value == "":
		return next
	if !updated_unlocks.has(item_value):
		updated_unlocks.append(item_value)
	next["unlocks"] = updated_unlocks
	return next
