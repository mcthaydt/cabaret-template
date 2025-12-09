@icon("res://resources/editor_icons/utility.svg")
extends "res://scripts/ui/base/base_overlay.gd"
class_name UI_InputProfileSelector

const U_InputSelectors := preload("res://scripts/state/selectors/u_input_selectors.gd")
const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_NavigationSelectors := preload("res://scripts/state/selectors/u_navigation_selectors.gd")
const U_FocusConfigurator := preload("res://scripts/ui/helpers/u_focus_configurator.gd")
const U_InputRebindUtils := preload("res://scripts/utils/u_input_rebind_utils.gd")
const RS_InputProfile := preload("res://scripts/ecs/resources/rs_input_profile.gd")
const U_ButtonPromptRegistry := preload("res://scripts/ui/u_button_prompt_registry.gd")
const M_InputDeviceManager := preload("res://scripts/managers/m_input_device_manager.gd")

@onready var _profile_button: Button = $HBoxContainer/ProfileButton
@onready var _apply_button: Button = $HBoxContainer/ApplyButton
@onready var _header_label: Label = $PreviewContainer/HeaderLabel
@onready var _description_label: Label = $PreviewContainer/DescriptionLabel
@onready var _bindings_container: VBoxContainer = $PreviewContainer/BindingsContainer

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
	# Start from all available profiles, then filter by active device type when possible.
	var all_ids: Array[String] = _manager.get_available_profile_ids()
	var filtered_ids: Array[String] = all_ids

	var store := get_store()
	if store != null and "available_profiles" in _manager:
		var state: Dictionary = store.get_state()
		var device_type: int = U_InputSelectors.get_active_device_type(state)
		var profiles_dict: Dictionary = _manager.available_profiles
		var device_filtered: Array[String] = []
		for id_key in profiles_dict.keys():
			var profile: RS_InputProfile = profiles_dict[id_key]
			if profile == null:
				continue
			if profile.device_type == device_type:
				device_filtered.append(String(id_key))
		if not device_filtered.is_empty():
			device_filtered.sort()
			filtered_ids = device_filtered

	_available_profiles = filtered_ids

	# Find currently active profile from settings
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
	if store == null:
		_transition_back_to_settings_scene()
		return

	var nav_slice: Dictionary = store.get_state().get("navigation", {})
	var overlay_stack: Array = U_NavigationSelectors.get_overlay_stack(nav_slice)
	var shell: StringName = U_NavigationSelectors.get_shell(nav_slice)

	if not overlay_stack.is_empty():
		store.dispatch(U_NavigationActions.close_top_overlay())
	else:
		if shell == StringName("main_menu"):
			_transition_back_to_settings_scene()
		else:
			store.dispatch(U_NavigationActions.set_shell(StringName("main_menu"), StringName("settings_menu")))

func _on_back_pressed() -> void:
	_close_overlay()

func _transition_back_to_settings_scene() -> void:
	var store := get_store()
	if store == null:
		return
	store.dispatch(U_NavigationActions.navigate_to_ui_screen(StringName("settings_menu"), "fade", 2))

func _update_preview() -> void:
	if _header_label == null or _description_label == null or _bindings_container == null:
		return
	if _manager == null or _available_profiles.is_empty():
		_header_label.text = ""
		_description_label.text = ""
		_clear_bindings_container()
		return

	var profile := _get_selected_profile()
	if profile == null:
		_header_label.text = ""
		_description_label.text = ""
		_clear_bindings_container()
		return

	_header_label.text = profile.profile_name
	# Only show description for touchscreen profiles (device_type 2)
	# For keyboard/gamepad, the visual bindings are self-explanatory
	if profile.device_type == 2:  # TOUCHSCREEN
		_description_label.text = profile.description
	else:
		_description_label.text = ""
	_build_bindings_preview(profile)

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

func _clear_bindings_container() -> void:
	if _bindings_container == null:
		return
	for child in _bindings_container.get_children():
		child.queue_free()

func _build_bindings_preview(profile: RS_InputProfile) -> void:
	_clear_bindings_container()
	if profile == null:
		return

	var device_type_for_registry: int = M_InputDeviceManager.DeviceType.KEYBOARD_MOUSE
	if profile.device_type == 1:  # GAMEPAD
		device_type_for_registry = M_InputDeviceManager.DeviceType.GAMEPAD

	# Movement actions
	var move_actions := [
		StringName("move_forward"),
		StringName("move_backward"),
		StringName("move_left"),
		StringName("move_right")
	]
	_add_action_group_row("Move", move_actions, profile, device_type_for_registry)

	# Individual actions
	var single_actions := [
		{ "action": StringName("jump"), "label": "Jump" },
		{ "action": StringName("sprint"), "label": "Sprint" },
		{ "action": StringName("interact"), "label": "Interact" },
		{ "action": StringName("pause"), "label": "Pause" }
	]

	for entry in single_actions:
		var action_name: StringName = entry["action"]
		var label: String = entry["label"]
		_add_action_row(label, action_name, profile, device_type_for_registry)

func _add_action_group_row(group_label: String, actions: Array, profile: RS_InputProfile, device_type: int) -> void:
	if profile == null or _bindings_container == null:
		return

	var has_any_binding := false
	for action_name in actions:
		var events := profile.get_events_for_action(action_name)
		if not events.is_empty():
			has_any_binding = true
			break

	if not has_any_binding:
		return

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var label := Label.new()
	label.text = group_label + ":"
	label.custom_minimum_size = Vector2(100, 0)
	row.add_child(label)

	var icons_container := HBoxContainer.new()
	icons_container.add_theme_constant_override("separation", 4)
	row.add_child(icons_container)

	for action_name in actions:
		_add_binding_icons_for_action(icons_container, action_name, profile, device_type)

	_bindings_container.add_child(row)

func _add_action_row(action_label: String, action_name: StringName, profile: RS_InputProfile, device_type: int) -> void:
	if profile == null or _bindings_container == null:
		return

	var events := profile.get_events_for_action(action_name)
	if events.is_empty():
		return

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var label := Label.new()
	label.text = action_label + ":"
	label.custom_minimum_size = Vector2(100, 0)
	row.add_child(label)

	var icons_container := HBoxContainer.new()
	icons_container.add_theme_constant_override("separation", 4)
	row.add_child(icons_container)

	_add_binding_icons_for_action(icons_container, action_name, profile, device_type)

	_bindings_container.add_child(row)

func _add_binding_icons_for_action(container: HBoxContainer, action: StringName, profile: RS_InputProfile, device_type: int) -> void:
	if container == null or profile == null:
		return

	# Show the actual events from this profile (not the registry defaults)
	var events := profile.get_events_for_action(action)
	for i in range(events.size()):
		var event: InputEvent = events[i]
		if event == null:
			continue

		# Try to get texture for individual keys
		var texture: Texture2D = U_InputRebindUtils.get_texture_for_event(event)

		# Display texture or fallback to text
		if texture != null:
			var texture_rect := TextureRect.new()
			texture_rect.texture = texture
			texture_rect.custom_minimum_size = Vector2(24, 24)
			texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			container.add_child(texture_rect)
		else:
			# Fallback to text label
			var event_label := Label.new()
			event_label.text = _format_binding_label(U_InputRebindUtils.format_event_label(event))
			event_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
			container.add_child(event_label)

		# Add separator comma between bindings (except last)
		if i < events.size() - 1:
			var separator := Label.new()
			separator.text = ", "
			separator.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1.0))
			container.add_child(separator)

func _format_binding_label(binding_text: String) -> String:
	var trimmed := binding_text.strip_edges()
	if trimmed.begins_with("Key "):
		trimmed = trimmed.substr(4, trimmed.length() - 4)
	return trimmed
