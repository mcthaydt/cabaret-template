@icon("res://resources/editor_icons/utility.svg")
extends "res://scripts/ui/base/base_overlay.gd"
class_name UI_InputProfileSelector

const U_InputSelectors := preload("res://scripts/state/selectors/u_input_selectors.gd")
const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_NavigationSelectors := preload("res://scripts/state/selectors/u_navigation_selectors.gd")
const U_FocusConfigurator := preload("res://scripts/ui/helpers/u_focus_configurator.gd")
const U_InputRebindUtils := preload("res://scripts/utils/u_input_rebind_utils.gd")
const RS_InputProfile := preload("res://scripts/input/resources/rs_input_profile.gd")
const U_ButtonPromptRegistry := preload("res://scripts/ui/u_button_prompt_registry.gd")
const M_InputDeviceManager := preload("res://scripts/managers/m_input_device_manager.gd")
const U_ServiceLocator := preload("res://scripts/core/u_service_locator.gd")

@onready var _profile_button: Button = $CenterContainer/Panel/MainContainer/ProfileRow/ProfileButton
@onready var _apply_button: Button = %ApplyButton
@onready var _cancel_button: Button = %CancelButton
@onready var _reset_button: Button = %ResetButton
@onready var _header_label: Label = $CenterContainer/Panel/MainContainer/PreviewContainer/HeaderLabel
@onready var _description_label: Label = $CenterContainer/Panel/MainContainer/PreviewContainer/DescriptionLabel
@onready var _bindings_container: VBoxContainer = $CenterContainer/Panel/MainContainer/PreviewContainer/BindingsContainer

@export var debug_nav_logs: bool = false

@export var input_profile_manager: Node = null

const INPUT_PROFILE_MANAGER_SERVICE := StringName("input_profile_manager")

var _manager: Node = null
var _available_profiles: Array[String] = []
var _current_index: int = 0

func _nav_log(message: String) -> void:
	if not debug_nav_logs:
		return
	print("[UI_InputProfileSelector] %s" % message)

func _describe_node(node: Node) -> String:
	if node == null:
		return "<null>"
	return "%s(%s)" % [node.name, node.get_class()]

func _on_panel_ready() -> void:
	if _profile_button != null and not _profile_button.pressed.is_connected(_on_profile_button_pressed):
		_profile_button.pressed.connect(_on_profile_button_pressed)
	if _apply_button != null and not _apply_button.pressed.is_connected(_on_apply_pressed):
		_apply_button.pressed.connect(_on_apply_pressed)
	if _cancel_button != null and not _cancel_button.pressed.is_connected(_on_cancel_pressed):
		_cancel_button.pressed.connect(_on_cancel_pressed)
	if _reset_button != null and not _reset_button.pressed.is_connected(_on_reset_pressed):
		_reset_button.pressed.connect(_on_reset_pressed)

	_manager = _resolve_input_profile_manager()
	if _manager == null:
		push_warning("InputProfileSelector: M_InputProfileManager not found")
		_update_preview()
		return
	if _manager.has_signal("profile_switched") and not _manager.profile_switched.is_connected(_on_manager_profile_switched):
		_manager.profile_switched.connect(_on_manager_profile_switched)
	_populate_profiles()
	_configure_focus_neighbors()
	_nav_log("ready manager=%s profiles=%d current_index=%d focused=%s" % [
		_describe_node(_manager),
		_available_profiles.size(),
		_current_index,
		_describe_node(get_viewport().gui_get_focus_owner() if get_viewport() != null else null)
	])
	_update_preview()

func _resolve_input_profile_manager() -> Node:
	if input_profile_manager != null and is_instance_valid(input_profile_manager):
		return input_profile_manager

	var manager := U_ServiceLocator.try_get_service(INPUT_PROFILE_MANAGER_SERVICE)
	if manager != null:
		return manager

	var tree := get_tree()
	if tree == null:
		return null

	return tree.get_first_node_in_group("input_profile_manager")

func _on_manager_profile_switched(profile_id: String) -> void:
	if _available_profiles.is_empty():
		_populate_profiles()
		return
	var idx := _available_profiles.find(profile_id)
	if idx != -1:
		_current_index = idx
		_update_button_text()
	else:
		_populate_profiles()

func _navigate_focus(direction: StringName) -> void:
	# Override to handle navigation within this overlay
	var focused := get_viewport().gui_get_focus_owner()
	_nav_log("_navigate_focus(%s) focused=%s" % [direction, _describe_node(focused)])

	# Handle left/right on ProfileButton: cycle profiles (matches slider UX pattern)
	if focused == _profile_button and (direction == "ui_left" or direction == "ui_right"):
		if direction == "ui_left":
			_cycle_profile(-1)
		else:
			_cycle_profile(1)
		return

	# For any other navigation, use default behavior (focus neighbors handle button navigation)
	super._navigate_focus(direction)

func _unhandled_input(event: InputEvent) -> void:
	# Note: Analog stick motion (InputEventJoypadMotion) is handled by
	# _navigate_focus() via the analog stick repeater from BaseMenuScreen.
	# Only handle discrete button presses (keyboard, D-pad) here.
	#
	# Analog stick motion should NOT be handled here with is_action_pressed()
	# as that bypasses debouncing and causes rapid cycling.

	# Skip analog stick motion events - let the repeater handle them
	if event is InputEventJoypadMotion:
		super._unhandled_input(event)
		return

	var viewport := get_viewport()
	var focused := viewport.gui_get_focus_owner() if viewport != null else null

	# Handle discrete button presses for profile cycling (left/right like sliders)
	if focused == _profile_button:
		if event.is_action_pressed("ui_left"):
			_cycle_profile(-1)
			if viewport != null:
				viewport.set_input_as_handled()
			return
		if event.is_action_pressed("ui_right"):
			_cycle_profile(1)
			if viewport != null:
				viewport.set_input_as_handled()
			return

	var action := ""
	if event.is_action_pressed("ui_up"):
		action = "ui_up"
	elif event.is_action_pressed("ui_down"):
		action = "ui_down"
	elif event.is_action_pressed("ui_left"):
		action = "ui_left"
	elif event.is_action_pressed("ui_right"):
		action = "ui_right"
	elif event.is_action_pressed("ui_accept"):
		action = "ui_accept"

	if not action.is_empty():
		_nav_log("_unhandled_input action=%s event=%s focused=%s" % [
			action,
			event.get_class(),
			_describe_node(focused)
		])

	super._unhandled_input(event)

func _configure_focus_neighbors() -> void:
	# Configure button row horizontal focus
	var buttons: Array[Control] = []
	if _cancel_button != null:
		buttons.append(_cancel_button)
	if _reset_button != null:
		buttons.append(_reset_button)
	if _apply_button != null:
		buttons.append(_apply_button)

	if not buttons.is_empty():
		U_FocusConfigurator.configure_horizontal_focus(buttons, true)
		# Connect profile button to button row
		if _profile_button != null:
			_profile_button.focus_neighbor_bottom = _profile_button.get_path_to(buttons[0])
			for button in buttons:
				button.focus_neighbor_top = button.get_path_to(_profile_button)
				button.focus_neighbor_bottom = button.get_path_to(_profile_button)

func _populate_profiles() -> void:
	if _manager == null:
		return
	# Start from all available profiles, then filter by active device type when possible.
	var all_ids: Array[String] = _manager.get_available_profile_ids()
	var filtered_ids: Array[String] = all_ids

	var store := get_store()
	var active_id := ""
	if store != null:
		var state: Dictionary = store.get_state()
		active_id = U_InputSelectors.get_active_profile_id(state)

	if store != null and "available_profiles" in _manager:
		var state: Dictionary = store.get_state()
		var device_type: int = U_InputSelectors.get_active_device_type(state)
		var profiles_dict: Dictionary = _manager.available_profiles
		var device_filtered: Array[String] = []
		for id_key in profiles_dict.keys():
			var profile: RS_InputProfile = profiles_dict[id_key]
			if profile == null:
				continue
			# On mobile, never show "default" (keyboard/mouse profile)
			if OS.has_feature("mobile") and String(id_key) == "default":
				continue
			if profile.device_type == device_type:
				device_filtered.append(String(id_key))
		if not device_filtered.is_empty():
			device_filtered.sort()
			filtered_ids = device_filtered
			# Ensure the current active profile is shown even if it doesn't match the current device filter
			# EXCEPT: never show "default" on mobile
			var should_include_active := not active_id.is_empty() and not filtered_ids.has(active_id) and all_ids.has(active_id)
			var is_default_on_mobile := OS.has_feature("mobile") and active_id == "default"
			if should_include_active and not is_default_on_mobile:
				filtered_ids.insert(0, active_id)

	_available_profiles = filtered_ids

	# Find currently active profile from settings
	if store == null:
		_current_index = 0
	else:
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
	U_UISoundPlayer.play_slider_tick()
	# Cycle in the given direction with wrap-around
	_current_index = (_current_index + direction) % _available_profiles.size()
	if _current_index < 0:
		_current_index = _available_profiles.size() - 1
	_nav_log("_cycle_profile(%d) -> current_index=%d selected=%s" % [
		direction,
		_current_index,
		_available_profiles[_current_index] if not _available_profiles.is_empty() else ""
	])
	_update_button_text()

func _on_profile_button_pressed() -> void:
	# Pressing the button also cycles forward (for mouse/touch users)
	_cycle_profile(1)

func _on_apply_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	if _manager == null:
		_manager = _resolve_input_profile_manager()
	if _manager != null and _available_profiles.is_empty():
		_populate_profiles()
	if _manager == null or _available_profiles.is_empty():
		return
	var selected_profile := _available_profiles[_current_index]
	_manager.switch_profile(selected_profile)
	_close_overlay()

func _on_cancel_pressed() -> void:
	U_UISoundPlayer.play_cancel()
	_close_overlay()

func _on_reset_pressed() -> void:
	U_UISoundPlayer.play_confirm()

	# Get the default profile for the current device type
	var store := get_store()
	if store == null:
		return

	var state: Dictionary = store.get_state()
	var device_type: int = U_InputSelectors.get_active_device_type(state)

	# Get default profile ID based on device type
	var default_profile_id: String = ""
	if device_type == 0:  # KEYBOARD_MOUSE
		# On mobile, never use "default" (keyboard/mouse profile)
		if OS.has_feature("mobile"):
			default_profile_id = "default_touchscreen"
		else:
			default_profile_id = "default"
	elif device_type == 1:  # GAMEPAD
		default_profile_id = "default_gamepad"
	elif device_type == 2:  # TOUCHSCREEN
		default_profile_id = "default_touchscreen"

	# Update UI to show the default profile (user must press Apply to confirm)
	if _available_profiles.has(default_profile_id):
		_current_index = _available_profiles.find(default_profile_id)
		_update_button_text()
		_update_preview()
	else:
		push_warning("UI_InputProfileSelector: Default profile '%s' not found for device type %d" % [default_profile_id, device_type])

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
	# Back button behavior matches Cancel button
	_on_cancel_pressed()

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
