extends RefCounted
class_name ActionRegistry

## Static action type registry for validation
##
## Validates that dispatched actions use registered action types.
## Actions must be registered via register_action() before use.

static var _registered_actions: Dictionary = {}

## Register an action type with optional schema
## Schema can define required payload fields for validation
static func register_action(action_type: StringName, schema: Dictionary = {}) -> void:
	if action_type == StringName():
		push_error("ActionRegistry.register_action: action_type is empty")
		return
	
	_registered_actions[action_type] = schema
	
	if OS.is_debug_build():
		print("[ActionRegistry] Registered action: ", action_type)

## Check if an action type is registered
static func is_registered(action_type: StringName) -> bool:
	return _registered_actions.has(action_type)

## Validate an action has correct structure and registered type
## Returns true if valid, false otherwise
static func validate_action(action: Dictionary) -> bool:
	if not action.has("type"):
		push_error("ActionRegistry.validate_action: Action missing 'type' field")
		return false
	
	var action_type: StringName = action.get("type")
	if action_type == StringName():
		push_error("ActionRegistry.validate_action: Action type is empty")
		return false
	
	if not is_registered(action_type):
		push_error("ActionRegistry.validate_action: Unregistered action type: ", action_type)
		return false
	
	# Optional: validate payload schema if defined
	var schema: Dictionary = _registered_actions.get(action_type, {})
	if not schema.is_empty():
		return _validate_schema(action, schema)
	
	return true

## Get list of all registered action types
static func get_registered_actions() -> Array[StringName]:
	var types: Array[StringName] = []
	for key in _registered_actions.keys():
		types.append(key as StringName)
	return types

## Clear all registered actions (primarily for testing)
static func clear() -> void:
	_registered_actions.clear()

## Validate action payload against schema
## Schema format: {"required_fields": ["field1", "field2"]}
static func _validate_schema(action: Dictionary, schema: Dictionary) -> bool:
	if not action.has("payload"):
		return true  # Payload is optional
	
	var payload: Variant = action.get("payload")
	if payload == null:
		return true  # Null payload is valid
	
	if not payload is Dictionary:
		return true  # Non-dict payloads are valid (e.g., primitive values)
	
	var payload_dict: Dictionary = payload as Dictionary
	var required_fields: Array = schema.get("required_fields", [])
	
	for field in required_fields:
		if not payload_dict.has(field):
			push_error("ActionRegistry: Missing required payload field: ", field)
			return false
	
	return true
