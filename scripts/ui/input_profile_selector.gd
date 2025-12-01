@icon("res://resources/editor_icons/utility.svg")
extends "res://scripts/ui/base/base_overlay.gd"
class_name InputProfileSelector

const U_InputSelectors := preload("res://scripts/state/selectors/u_input_selectors.gd")
const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_FocusConfigurator := preload("res://scripts/ui/helpers/u_focus_configurator.gd")
const RS_InputProfile := preload("res://scripts/ecs/resources/rs_input_profile.gd")

@onready var _profile_button: Button = $HBoxContainer/ProfileButton
@onready var _apply_button: Button = $HBoxContainer/ApplyButton
@onready var _preview_label: Label = $"PreviewLabel"

var _manager: Node = null
var _available_profiles: Array[String] = []
var _current_index: int = 0

func _on_panel_ready() -> void:
	_manager = get_tree().get_first_node_in_group("input_profile_manager")
	if _manager == null:
		push_warning("InputProfileSelector: M_InputProfileManager not found")
		return
	_populate_profiles()
	_configure_focus_neighbors()
	if _profile_button != null and not _profile_button.pressed.is_connected(_on_profile_button_pressed):
		_profile_button.pressed.connect(_on_profile_button_pressed)
	if _apply_button != null and not _apply_button.pressed.is_connected(_on_apply_pressed):
		_apply_button.pressed.connect(_on_apply_pressed)
	_update_preview()

func _navigate_focus(direction: StringName) -> void:
	# Override to handle navigation within this overlay
	var focused := get_viewport().gui_get_focus_owner()

	# Handle up/down on ProfileButton: cycle profiles
	if focused == _profile_button and (direction == "ui_up" or direction == "ui_down"):
		if direction == "ui_up":
			_cycle_profile(-1)
		else:
			_cycle_profile(1)
		return

	# Handle left/right navigation between ProfileButton and ApplyButton
	if focused == _profile_button and (direction == "ui_left" or direction == "ui_right"):
		if _apply_button != null:
			_apply_button.grab_focus()
		return

	if focused == _apply_button and (direction == "ui_left" or direction == "ui_right"):
		if _profile_button != null:
			_profile_button.grab_focus()
		return

	# For any other navigation, use default behavior
	super._navigate_focus(direction)

func _configure_focus_neighbors() -> void:
	# Don't set focus neighbors - we handle all navigation in _navigate_focus override
	# This prevents the parent menu's repeater from also processing navigation
	pass

func _populate_profiles() -> void:
	if _manager == null:
		return
	_available_profiles = _manager.get_available_profile_ids()

	# Find currently active profile from settings
	var store := get_store()
	if store == null:
		_current_index = 0
	else:
		var state: Dictionary = store.get_state()
		var active_id := U_InputSelectors.get_active_profile_id(state)
		_current_index = _available_profiles.find(active_id)
		if _current_index == -1:
			_current_index = 0

	_update_button_text()
	_update_preview()

func _update_button_text() -> void:
	if _profile_button == null or _available_profiles.is_empty():
		return
	_profile_button.text = _available_profiles[_current_index]
	_update_preview()

func _cycle_profile(direction: int) -> void:
	if _available_profiles.is_empty():
		return
	# Cycle in the given direction with wrap-around
	_current_index = (_current_index + direction) % _available_profiles.size()
	if _current_index < 0:
		_current_index = _available_profiles.size() - 1
	_update_button_text()

func _on_profile_button_pressed() -> void:
	# Pressing the button also cycles forward (for mouse/touch users)
	_cycle_profile(1)

func _on_apply_pressed() -> void:
	if _manager == null or _available_profiles.is_empty():
		return
	var selected_profile := _available_profiles[_current_index]
	_manager.switch_profile(selected_profile)
	_close_overlay()

func _close_overlay() -> void:
	var store := get_store()
	if store != null:
		store.dispatch(U_NavigationActions.close_top_overlay())

func _on_back_pressed() -> void:
	_close_overlay()

func _update_preview() -> void:
	if _preview_label == null:
		return
	if _manager == null or _available_profiles.is_empty():
		_preview_label.text = ""
		return

	var profile := _get_selected_profile()
	if profile == null:
		_preview_label.text = ""
		return

	var header := profile.profile_name
	var description := profile.description
	var details := _build_bindings_preview(profile)

	var lines: Array[String] = []
	if not header.is_empty():
		lines.append(header)
	if not description.is_empty():
		lines.append(description)
	if not details.is_empty():
		lines.append(details)

	_preview_label.text = "\n".join(lines)

func _get_selected_profile() -> RS_InputProfile:
	if _manager == null:
		return null
	if _available_profiles.is_empty():
		return null
	if _current_index < 0 or _current_index >= _available_profiles.size():
		return null

	var profile_id := _available_profiles[_current_index]
	if not _manager.has_method("get_active_profile") and not ("available_profiles" in _manager):
		return null

	if "available_profiles" in _manager:
		var profiles_dict: Dictionary = _manager.available_profiles
		if profiles_dict.has(profile_id):
			var profile: RS_InputProfile = profiles_dict.get(profile_id)
			return profile
	return null

func _build_bindings_preview(profile: RS_InputProfile) -> String:
	if profile == null:
		return ""

	var segments: Array[String] = []

	var move_labels: Array[String] = []
	move_labels.append_array(_collect_action_labels(profile, [
		StringName("move_forward"),
		StringName("move_backward"),
		StringName("move_left"),
		StringName("move_right")
	]))
	if not move_labels.is_empty():
		segments.append("Move: %s" % ", ".join(move_labels))

	var single_actions := [
		{ "action": StringName("jump"), "label": "Jump" },
		{ "action": StringName("sprint"), "label": "Sprint" },
		{ "action": StringName("interact"), "label": "Interact" },
		{ "action": StringName("pause"), "label": "Pause" }
	]

	for entry in single_actions:
		var action_name: StringName = entry["action"]
		var label: String = entry["label"]
		var action_labels := _collect_action_labels(profile, [action_name])
		if not action_labels.is_empty():
			segments.append("%s: %s" % [label, ", ".join(action_labels)])

	return " • ".join(segments)

func _collect_action_labels(profile: RS_InputProfile, actions: Array[StringName]) -> Array[String]:
	var labels: Array[String] = []
	if profile == null:
		return labels

	for action_name in actions:
		var events := profile.get_events_for_action(action_name)
		if events.is_empty():
			continue
		var display_events: Array = []
		for event in events:
			display_events.append(event)
		var binding_text := _format_binding_text(display_events)
		if not binding_text.is_empty():
			labels.append(binding_text)
	return labels

func _format_binding_text(events: Array) -> String:
	var labels: Array[String] = []
	for ev in events:
		if ev is InputEvent:
			var event := ev as InputEvent
			labels.append(_format_binding_label(event.as_text()))
	return ", ".join(labels)

func _format_binding_label(binding_text: String) -> String:
	var trimmed := binding_text.strip_edges()
	if trimmed.begins_with("Key "):
		trimmed = trimmed.substr(4, trimmed.length() - 4)
	return trimmed
