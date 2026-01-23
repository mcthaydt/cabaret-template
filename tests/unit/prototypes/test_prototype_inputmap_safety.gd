extends GutTest

const PrototypeInputMapSafety := preload("res://tests/prototypes/prototype_inputmap_safety.gd")

func test_capture_and_restore_preserves_defaults() -> void:
	var adapter := MockInputMapAdapter.new()
	var action := StringName("jump")
	adapter.add_action(action)
	var default_event := _make_key_event(KEY_SPACE)
	adapter.action_add_event(action, default_event)

	var prototype := PrototypeInputMapSafety.new(adapter)
	var defaults := prototype.capture_defaults([action])

	var new_event := _make_key_event(KEY_Z)
	prototype.apply_binding(action, new_event)
	prototype.remove_binding(action, default_event.duplicate())
	assert_eq(adapter.get_events(action).size(), 1)
	assert_true(adapter.event_exists(action, new_event))

	prototype.restore_defaults(defaults)
	var restored := adapter.get_events(action)
	assert_eq(restored.size(), 1)
	assert_true(restored[0].is_match(default_event))

func test_remove_binding_matches_equivalent_event_instances() -> void:
	var adapter := MockInputMapAdapter.new()
	var action := StringName("dash")
	adapter.add_action(action)
	var default_event := _make_key_event(KEY_SHIFT)
	adapter.action_add_event(action, default_event)

	var prototype := PrototypeInputMapSafety.new(adapter)
	var equivalent_event := _make_key_event(KEY_SHIFT)
	prototype.remove_binding(action, equivalent_event)
	assert_false(adapter.event_exists(action, default_event))

func test_interact_action_is_recreated_with_defaults() -> void:
	var adapter := MockInputMapAdapter.new()
	var prototype := PrototypeInputMapSafety.new(adapter)
	var interact_default := _make_key_event(KEY_E)

	prototype.ensure_interact_action([interact_default])
	assert_true(adapter.has_action(StringName("interact")))
	assert_true(adapter.event_exists(StringName("interact"), interact_default))

	adapter.erase_action(StringName("interact"))
	assert_false(adapter.has_action(StringName("interact")))

	prototype.ensure_interact_action([interact_default])
	assert_true(adapter.has_action(StringName("interact")))
	assert_true(adapter.event_exists(StringName("interact"), interact_default))

func test_snapshot_returns_deep_copies() -> void:
	var adapter := MockInputMapAdapter.new()
	var action := StringName("move_left")
	adapter.add_action(action)
	var event := _make_key_event(KEY_A)
	adapter.action_add_event(action, event)

	var prototype := PrototypeInputMapSafety.new(adapter)
	var snapshot := prototype.snapshot_actions([action])
	adapter.action_add_event(action, _make_key_event(KEY_LEFT))

	assert_eq(snapshot[action].size(), 1)
	assert_true(snapshot[action][0].is_match(event))
	assert_eq(adapter.get_events(action).size(), 2)

func _make_key_event(keycode: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	return event

class MockInputMapAdapter extends RefCounted:
	var _actions: Dictionary = {}

	func has_action(action_name: StringName) -> bool:
		return _actions.has(action_name)

	func add_action(action_name: StringName) -> void:
		if not _actions.has(action_name):
			_actions[action_name] = []

	func action_get_events(action_name: StringName) -> Array:
		if not _actions.has(action_name):
			return []
		return _duplicate_events(_actions[action_name])

	func action_add_event(action_name: StringName, event: InputEvent) -> void:
		add_action(action_name)
		_actions[action_name].append(event.duplicate(true))

	func action_erase_event(action_name: StringName, event: InputEvent) -> void:
		if not _actions.has(action_name):
			return
		var events: Array = _actions[action_name]
		for i in range(events.size()):
			var existing: InputEvent = events[i]
			if existing.is_match(event):
				events.remove_at(i)
				break

	func action_erase_all_events(action_name: StringName) -> void:
		if _actions.has(action_name):
			_actions[action_name] = []

	func erase_action(action_name: StringName) -> void:
		_actions.erase(action_name)

	func get_events(action_name: StringName) -> Array:
		return action_get_events(action_name)

	func event_exists(action_name: StringName, event: InputEvent) -> bool:
		for existing in _actions.get(action_name, []):
			if existing.is_match(event):
				return true
		return false

	func _duplicate_events(events: Array) -> Array:
		var copies: Array = []
		for event in events:
			copies.append(event.duplicate(true))
		return copies
