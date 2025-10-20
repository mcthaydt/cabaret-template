@icon("res://editor_icons/utility.svg")
extends RefCounted
class_name U_ActionUtils

const _SEPARATOR := "/"
static var _registry: Dictionary = {}

static func create_action(action_type: Variant, payload: Variant = null) -> Dictionary:
	var normalized_type := _normalize_type(action_type)
	if !_registry.has(normalized_type):
		_registry[normalized_type] = true
	return {
		"type": normalized_type,
		"payload": payload,
	}

static func is_action(candidate: Variant) -> bool:
	if typeof(candidate) != TYPE_DICTIONARY:
		return false
	if !candidate.has("type") or !candidate.has("payload"):
		return false
	return typeof(candidate["type"]) == TYPE_STRING_NAME

static func define(domain: String, action: String) -> StringName:
	var trimmed_namespace := domain.strip_edges()
	var trimmed_name := action.strip_edges()
	assert(trimmed_namespace != "", "Action namespace must not be empty")
	assert(trimmed_name != "", "Action name must not be empty")
	assert(!trimmed_namespace.contains(_SEPARATOR), "Action namespace must not contain '/' characters")
	assert(!trimmed_name.contains(_SEPARATOR), "Action name must not contain '/' characters")
	var key := "%s%s%s" % [trimmed_namespace, _SEPARATOR, trimmed_name]
	var string_name := StringName(key)
	if !_registry.has(string_name):
		_registry[string_name] = true
	return string_name

static func get_registered_types() -> Array[StringName]:
	var results: Array[StringName] = []
	for key in _registry.keys():
		results.append(key)
	return results

static func clear_registry() -> void:
	_registry.clear()

static func _normalize_type(action_type: Variant) -> StringName:
	match typeof(action_type):
		TYPE_STRING_NAME:
			return action_type
		TYPE_STRING:
			return StringName(action_type)
		_:
			assert(false, "Action type must be String or StringName")
			return StringName()
