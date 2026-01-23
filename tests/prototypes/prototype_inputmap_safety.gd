extends RefCounted

## Research helper that validates runtime InputMap modifications.
##
## Wraps InputMap calls via an adapter so we can capture defaults, mutate
## bindings, and restore them safely without corrupting `project.godot`.

var _adapter: RefCounted

func _init(adapter: RefCounted = null) -> void:
	_adapter = adapter if adapter != null else InputMapAdapter.new()

func capture_defaults(actions: Array[StringName]) -> Dictionary:
	var defaults: Dictionary = {}
	for action_name in actions:
		if not _adapter.has_action(action_name):
			continue
		defaults[action_name] = _duplicate_events(_adapter.action_get_events(action_name))
	return defaults

func apply_binding(action_name: StringName, event: InputEvent) -> void:
	if event == null:
		return
	if not _adapter.has_action(action_name):
		_adapter.add_action(action_name)
	_adapter.action_add_event(action_name, event)

func remove_binding(action_name: StringName, event: InputEvent) -> void:
	if event == null:
		return
	if not _adapter.has_action(action_name):
		return
	_adapter.action_erase_event(action_name, event)

func restore_defaults(defaults: Dictionary) -> void:
	for action_name in defaults.keys():
		var events: Array = defaults[action_name]
		if not _adapter.has_action(action_name):
			_adapter.add_action(action_name)
		_adapter.action_erase_all_events(action_name)
		for event in events:
			_adapter.action_add_event(action_name, event.duplicate(true))

func ensure_interact_action(default_events: Array[InputEvent]) -> void:
	var action_name := StringName("interact")
	if not _adapter.has_action(action_name):
		_adapter.add_action(action_name)
	if _adapter.action_get_events(action_name).is_empty():
		for event in default_events:
			if event != null:
				_adapter.action_add_event(action_name, event.duplicate(true))

func snapshot_actions(action_names: Array[StringName]) -> Dictionary:
	var snapshot: Dictionary = {}
	for action_name in action_names:
		if not _adapter.has_action(action_name):
			continue
		snapshot[action_name] = _duplicate_events(_adapter.action_get_events(action_name))
	return snapshot

func _duplicate_events(events: Array) -> Array:
	var copies: Array = []
	for event in events:
		if event != null:
			copies.append(event.duplicate(true))
	return copies

class InputMapAdapter extends RefCounted:
	func has_action(action_name: StringName) -> bool:
		return InputMap.has_action(action_name)

	func add_action(action_name: StringName) -> void:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)

	func action_get_events(action_name: StringName) -> Array:
		return InputMap.action_get_events(action_name)

	func action_add_event(action_name: StringName, event: InputEvent) -> void:
		InputMap.action_add_event(action_name, event)

	func action_erase_event(action_name: StringName, event: InputEvent) -> void:
		InputMap.action_erase_event(action_name, event)

	func action_erase_all_events(action_name: StringName) -> void:
		var events := InputMap.action_get_events(action_name)
		for event in events:
			InputMap.action_erase_event(action_name, event)
