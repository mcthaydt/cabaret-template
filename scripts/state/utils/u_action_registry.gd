extends RefCounted
class_name U_ActionRegistry

## Static action type registry for validation
##
## Validates that dispatched actions use registered action types.
## Actions must be registered via register_action() before use.

static var _registered_actions: Dictionary = {}

## Create an action with the given type and payload
static func create_action(type: StringName, payload: Variant = null) -> Dictionary:
	return {
		"type": type,
		"payload": payload
	}

## Register an action type with optional schema
## Schema can define required payload fields for validation
static func register_action(action_type: StringName, schema: Dictionary = {}) -> void:
	if action_type == StringName():
		push_error("U_ActionRegistry.register_action: action_type is empty")
		return
	
	_registered_actions[action_type] = schema

## Check if an action type is registered
static func is_registered(action_type: StringName) -> bool:
	return _registered_actions.has(action_type)

## Validate an action has correct structure and registered type
## Returns true if valid, false otherwise
static func validate_action(action: Dictionary) -> bool:
	if not action.has("type"):
		push_error("U_ActionRegistry.validate_action: Action missing 'type' field")
		return false
	
	var action_type: StringName = action.get("type")
	if action_type == StringName():
		push_error("U_ActionRegistry.validate_action: Action type is empty")
		return false
	
	if not is_registered(action_type):
		push_error("U_ActionRegistry.validate_action: Unregistered action type: ", action_type)
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
## Schema format: {"required_fields": ["field1", "field2"], "required_root_fields": ["fieldA"]}
static func _validate_schema(action: Dictionary, schema: Dictionary) -> bool:
	var required_root_fields: Array = schema.get("required_root_fields", [])
	for field in required_root_fields:
		if not action.has(field):
			push_error("ActionRegistry: Missing required root field: ", field)
			return false
		var root_value: Variant = action.get(field)
		if root_value is StringName and root_value == StringName():
			push_error("ActionRegistry: Required root field is empty: ", field)
			return false
		if root_value is String and (root_value as String).is_empty():
			push_error("ActionRegistry: Required root field is empty: ", field)
			return false

	var required_fields: Array = schema.get("required_fields", [])

	if not action.has("payload"):
		return true  # Payload is optional

	var payload: Variant = action.get("payload")
	if payload == null:
		return true  # Null payload is valid

	if not payload is Dictionary:
		return true  # Non-dict payloads are valid (e.g., primitive values)

	var payload_dict: Dictionary = payload as Dictionary
	for field in required_fields:
		if not payload_dict.has(field):
			push_error("ActionRegistry: Missing required payload field: ", field)
			return false
		var payload_value: Variant = payload_dict.get(field)
		if payload_value is StringName and payload_value == StringName():
			push_error("ActionRegistry: Required payload field is empty: ", field)
			return false
		if payload_value is String and (payload_value as String).is_empty():
			push_error("ActionRegistry: Required payload field is empty: ", field)
			return false
	
	return true
