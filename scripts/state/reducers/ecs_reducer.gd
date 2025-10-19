extends RefCounted

class_name EcsReducer

const CONSTANTS := preload("res://scripts/state/state_constants.gd")
const STATE_UTILS := preload("res://scripts/state/u_state_utils.gd")

static func get_slice_name() -> StringName:
	return StringName("ecs")

static func get_initial_state() -> Dictionary:
	return {
		"components": {},
		"systems": {},
		"dirty": false,
	}

static func get_persistable() -> bool:
	return false

static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
	var normalized := _normalize_state(state)
	var action_type: StringName = action.get("type", StringName(""))

	match action_type:
		CONSTANTS.INIT_ACTION:
			return get_initial_state()
		StringName("ecs/register_component"):
			return _apply_register_component(normalized, action)
		StringName("ecs/unregister_component"):
			return _apply_unregister_component(normalized, action)
		StringName("ecs/register_system"):
			return _apply_register_system(normalized, action)
		StringName("ecs/clear_dirty"):
			return _apply_clear_dirty(normalized)
		_:
			return normalized

static func _normalize_state(state: Dictionary) -> Dictionary:
	if typeof(state) != TYPE_DICTIONARY or state.is_empty():
		return get_initial_state()

	var components_dict: Variant = STATE_UTILS.safe_duplicate(state.get("components", {}))
	var systems_dict: Variant = STATE_UTILS.safe_duplicate(state.get("systems", {}))
	return {
		"components": components_dict if typeof(components_dict) == TYPE_DICTIONARY else {},
		"systems": systems_dict if typeof(systems_dict) == TYPE_DICTIONARY else {},
		"dirty": bool(state.get("dirty", false)),
	}

static func _apply_register_component(state: Dictionary, action: Dictionary) -> Dictionary:
	var next: Dictionary = STATE_UTILS.safe_duplicate(state)
	var components: Dictionary = STATE_UTILS.safe_duplicate(next.get("components", {}))
	var payload_variant: Variant = action.get("payload", {})
	if typeof(payload_variant) != TYPE_DICTIONARY:
		next["components"] = components
		return next
	var payload: Dictionary = payload_variant
	var id_value: Variant = payload.get("id")
	if id_value == null:
		next["components"] = components
		return next
	var component_data: Dictionary = STATE_UTILS.safe_duplicate(payload)
	components[id_value] = component_data
	next["components"] = components
	next["dirty"] = true
	return next

static func _apply_unregister_component(state: Dictionary, action: Dictionary) -> Dictionary:
	var next: Dictionary = STATE_UTILS.safe_duplicate(state)
	var components: Dictionary = STATE_UTILS.safe_duplicate(next.get("components", {}))
	var id_value: Variant = action.get("payload")
	if id_value == null:
		next["components"] = components
		return next
	if components.erase(id_value):
		next["dirty"] = true
	next["components"] = components
	return next

static func _apply_register_system(state: Dictionary, action: Dictionary) -> Dictionary:
	var next: Dictionary = STATE_UTILS.safe_duplicate(state)
	var systems: Dictionary = STATE_UTILS.safe_duplicate(next.get("systems", {}))
	var payload_variant: Variant = action.get("payload", {})
	if typeof(payload_variant) != TYPE_DICTIONARY:
		next["systems"] = systems
		return next
	var payload: Dictionary = payload_variant
	var system_name: Variant = payload.get("name")
	if system_name == null:
		next["systems"] = systems
		return next
	systems[system_name] = STATE_UTILS.safe_duplicate(payload)
	next["systems"] = systems
	next["dirty"] = true
	return next

static func _apply_clear_dirty(state: Dictionary) -> Dictionary:
	var next: Dictionary = STATE_UTILS.safe_duplicate(state)
	next["dirty"] = false
	return next
