extends GutTest

## Tests for ActionRegistry validation system

func before_each() -> void:
	# Store existing registered actions to restore after test
	pass

func after_each() -> void:
	# Don't clear - other tests depend on U_GameplayActions being registered
	pass

func test_register_action_adds_to_registry() -> void:
	var action_type := StringName("test/action")
	
	ActionRegistry.register_action(action_type)
	
	assert_true(ActionRegistry.is_registered(action_type), "Action should be registered")

func test_is_registered_returns_false_for_unregistered() -> void:
	var action_type := StringName("test/unknown")
	
	assert_false(ActionRegistry.is_registered(action_type), "Unknown action should not be registered")

func test_validate_action_accepts_registered_type() -> void:
	var action_type := StringName("test/valid")
	ActionRegistry.register_action(action_type)
	
	var action: Dictionary = {"type": action_type, "payload": null}
	
	assert_true(ActionRegistry.validate_action(action), "Valid action should pass validation")

func test_validate_action_rejects_unregistered_type() -> void:
	gut.p("Expect error: Unregistered action type")
	var action: Dictionary = {"type": StringName("test/unregistered"), "payload": null}
	
	assert_false(ActionRegistry.validate_action(action), "Unregistered action should fail validation")

func test_validate_action_rejects_missing_type() -> void:
	gut.p("Expect error: Action missing 'type' field")
	var action: Dictionary = {"payload": "no type"}
	
	assert_false(ActionRegistry.validate_action(action), "Action without type should fail validation")

func test_validate_action_rejects_empty_type() -> void:
	gut.p("Expect error: Action type is empty")
	var action: Dictionary = {"type": StringName(), "payload": null}
	
	assert_false(ActionRegistry.validate_action(action), "Action with empty type should fail validation")

func test_get_registered_actions_returns_all_types() -> void:
	var existing_count := ActionRegistry.get_registered_actions().size()
	
	var type1 := StringName("test/action1")
	var type2 := StringName("test/action2")
	
	ActionRegistry.register_action(type1)
	ActionRegistry.register_action(type2)
	
	var registered: Array[StringName] = ActionRegistry.get_registered_actions()
	
	assert_eq(registered.size(), existing_count + 2, "Should have added 2 registered actions")
	assert_true(registered.has(type1), "Should contain action1")
	assert_true(registered.has(type2), "Should contain action2")

func test_clear_removes_all_registrations() -> void:
	# Save existing actions
	var existing_actions := ActionRegistry.get_registered_actions().duplicate()
	
	ActionRegistry.register_action(StringName("test/action1"))
	ActionRegistry.register_action(StringName("test/action2"))
	
	ActionRegistry.clear()
	
	var registered: Array[StringName] = ActionRegistry.get_registered_actions()
	assert_eq(registered.size(), 0, "All actions should be cleared")
	
	# Restore gameplay actions that were registered via _static_init()
	for action_type in existing_actions:
		ActionRegistry.register_action(action_type)

func test_validate_with_schema_accepts_valid_payload() -> void:
	var action_type := StringName("test/with_schema")
	var schema: Dictionary = {"required_fields": ["name", "value"]}
	
	ActionRegistry.register_action(action_type, schema)
	
	var action: Dictionary = {
		"type": action_type,
		"payload": {"name": "test", "value": 123}
	}
	
	assert_true(ActionRegistry.validate_action(action), "Action with valid payload should pass")

func test_validate_with_schema_rejects_missing_field() -> void:
	gut.p("Expect error: Missing required payload field")
	var action_type := StringName("test/with_schema")
	var schema: Dictionary = {"required_fields": ["name", "value"]}
	
	ActionRegistry.register_action(action_type, schema)
	
	var action: Dictionary = {
		"type": action_type,
		"payload": {"name": "test"}  # Missing 'value'
	}
	
	assert_false(ActionRegistry.validate_action(action), "Action missing required field should fail")

func test_register_action_with_empty_type_errors() -> void:
	gut.p("Expect error: action_type is empty")
	var before_count := ActionRegistry.get_registered_actions().size()
	
	ActionRegistry.register_action(StringName())
	
	# Should not register - count should not increase
	var after_count := ActionRegistry.get_registered_actions().size()
	assert_eq(after_count, before_count, "Empty type should not register")
