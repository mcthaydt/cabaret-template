extends RefCounted
class_name M_InputProfileLoader

const RS_InputProfile = preload("res://scripts/input/resources/rs_input_profile.gd")

func load_available_profiles() -> Dictionary:
	var profiles: Dictionary = {}

	var default_res := load("res://resources/input/profiles/default_keyboard.tres")
	if default_res is RS_InputProfile:
		profiles["default"] = default_res

	var alternate_res := load("res://resources/input/profiles/alternate_keyboard.tres")
	if alternate_res is RS_InputProfile:
		profiles["alternate"] = alternate_res

	var accessibility_res := load("res://resources/input/profiles/accessibility_keyboard.tres")
	if accessibility_res is RS_InputProfile:
		profiles["accessibility"] = accessibility_res

	var default_gamepad_res := load("res://resources/input/profiles/default_gamepad.tres")
	if default_gamepad_res is RS_InputProfile:
		profiles["default_gamepad"] = default_gamepad_res

	var accessibility_gamepad_res := load("res://resources/input/profiles/accessibility_gamepad.tres")
	if accessibility_gamepad_res is RS_InputProfile:
		profiles["accessibility_gamepad"] = accessibility_gamepad_res

	var default_touchscreen_res := load("res://resources/input/profiles/default_touchscreen.tres")
	if default_touchscreen_res is RS_InputProfile:
		profiles["default_touchscreen"] = default_touchscreen_res

	return profiles

func load_profile(available_profiles: Dictionary, profile_id: String) -> RS_InputProfile:
	if not available_profiles.has(profile_id):
		push_error("Input profile not found: %s" % profile_id)
		return null

	var profile := available_profiles[profile_id] as RS_InputProfile
	if profile == null:
		return null

	return profile

func apply_profile_to_input_map(profile: RS_InputProfile) -> void:
	if profile == null:
		return

	for action_key in profile.action_mappings.keys():
		var action: StringName = StringName(action_key)
		if not InputMap.has_action(action):
			InputMap.add_action(action)

		var existing := InputMap.action_get_events(action)
		for e in existing:
			if _is_same_device_type(e, profile.device_type):
				InputMap.action_erase_event(action, e)

		var events: Array = profile.get_events_for_action(action)
		for ev in events:
			if ev is InputEvent:
				InputMap.action_add_event(action, ev)

func apply_profile_accessibility(
	profile_id: String,
	profile: RS_InputProfile,
	state_store: M_StateStore,
	update_accessibility_callable: Callable
) -> void:
	if profile == null:
		return
	if state_store == null or not is_instance_valid(state_store):
		return

	var id_str := String(profile_id)
	if not id_str.begins_with("accessibility"):
		return

	if update_accessibility_callable == Callable() or not update_accessibility_callable.is_valid():
		return

	var accessibility_updates := [
		update_accessibility_callable.call("jump_buffer_time", profile.jump_buffer_time),
		update_accessibility_callable.call("sprint_toggle_mode", profile.sprint_toggle_mode),
		update_accessibility_callable.call("interact_hold_duration", profile.interact_hold_duration),
	]

	for action in accessibility_updates:
		state_store.dispatch(action)

func _is_same_device_type(event: InputEvent, device_type: int) -> bool:
	match device_type:
		0:
			return event is InputEventKey or event is InputEventMouse or event is InputEventMouseButton
		1:
			return event is InputEventJoypadButton or event is InputEventJoypadMotion
		2:
			return event is InputEventScreenTouch or event is InputEventScreenDrag
		_:
			return false
