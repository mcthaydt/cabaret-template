@icon("res://resources/editor_icons/utility.svg")
extends "res://scripts/ui/base/base_overlay.gd"
class_name UI_InputRebindingOverlay

const U_InputActions := preload("res://scripts/state/actions/u_input_actions.gd")
const U_InputRebindUtils := preload("res://scripts/utils/u_input_rebind_utils.gd")
const U_InputCaptureGuard := preload("res://scripts/utils/u_input_capture_guard.gd")
const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_NavigationSelectors := preload("res://scripts/state/selectors/u_navigation_selectors.gd")
const U_FocusConfigurator := preload("res://scripts/ui/helpers/u_focus_configurator.gd")
const U_InputSelectors := preload("res://scripts/state/selectors/u_input_selectors.gd")
const U_ButtonPromptRegistry := preload("res://scripts/ui/u_button_prompt_registry.gd")
const M_InputDeviceManager := preload("res://scripts/managers/m_input_device_manager.gd")
const U_RebindActionListBuilder := preload("res://scripts/ui/helpers/u_rebind_action_list_builder.gd")
const U_RebindCaptureHandler := preload("res://scripts/ui/helpers/u_rebind_capture_handler.gd")
const U_RebindFocusNavigation := preload("res://scripts/ui/helpers/u_rebind_focus_navigation.gd")
const U_ServiceLocator := preload("res://scripts/core/u_service_locator.gd")
const DEFAULT_REBIND_SETTINGS: Resource = preload("res://resources/input/rebind_settings/default_rebind_settings.tres")

@onready var _action_list: VBoxContainer = %ActionList
@onready var _status_label: Label = %StatusLabel
@onready var _search_box: LineEdit = %SearchBox
@onready var _close_button: Button = %CloseButton
@onready var _reset_button: Button = %ResetButton
@onready var _scroll: ScrollContainer = $CenterContainer/Panel/VBox/Scroll
@onready var _conflict_dialog: ConfirmationDialog = %ConflictDialog
@onready var _reset_confirm_dialog: ConfirmationDialog = %ResetConfirmDialog
@onready var _error_dialog: AcceptDialog = %ErrorDialog

@export var input_profile_manager: Node = null

const INPUT_PROFILE_MANAGER_SERVICE := StringName("input_profile_manager")

var _profile_manager: Node = null
var _rebind_settings: RS_RebindSettings = null
var _is_capturing: bool = false
var _pending_action: StringName = StringName()
var _pending_event: InputEvent = null
var _pending_conflict: StringName = StringName()
var _action_rows: Dictionary = {}  # StringName -> {container: VBoxContainer, name_label: Label, binding_container: HBoxContainer, replace_button: Button, add_button: Button, reset_button: Button, category_header: Label}
var _capture_mode: String = U_InputActions.REBIND_MODE_REPLACE
var _search_filter: String = ""
var _focused_action_index: int = -1
var _focusable_actions: Array[StringName] = []
var _capture_guard_active: bool = false
var _is_on_bottom_row: bool = false
var _bottom_button_index: int = 0
var _row_button_index: int = 0

func _on_panel_ready() -> void:
	_profile_manager = _resolve_input_profile_manager()
	if _profile_manager != null and "store_ref" in _profile_manager:
		var manager_store: Variant = _profile_manager.store_ref
		if manager_store is M_StateStore:
			_store = manager_store
	if _store == null:
		_store = _resolve_preferred_store()
	if _store == null:
		_store = get_store()
	if DEFAULT_REBIND_SETTINGS != null:
		_rebind_settings = DEFAULT_REBIND_SETTINGS.duplicate(true)
	else:
		_rebind_settings = RS_RebindSettings.new()

	_close_button.pressed.connect(_on_close_pressed)
	if _reset_button != null:
		_reset_button.pressed.connect(_on_reset_pressed)
	_conflict_dialog.confirmed.connect(_on_conflict_confirmed)
	_conflict_dialog.canceled.connect(_on_conflict_canceled)
	_reset_confirm_dialog.confirmed.connect(_on_reset_confirmed)
	_reset_confirm_dialog.canceled.connect(_on_reset_canceled)
	_error_dialog.confirmed.connect(_on_error_dismissed)

	# Connect search box
	if _search_box != null:
		_search_box.text_changed.connect(_on_search_changed)

	_connect_profile_signals()
	_build_action_rows()
	_update_status("Select an action to rebind.")
	_set_reset_button_enabled(_profile_manager != null)

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

func _connect_profile_signals() -> void:
	if _profile_manager == null:
		return
	if _profile_manager.has_signal("profile_switched"):
		_profile_manager.profile_switched.connect(func(_id): _on_profile_switched())
	if _profile_manager.has_signal("bindings_reset"):
		_profile_manager.bindings_reset.connect(_on_bindings_reset)
	if _profile_manager.has_signal("custom_binding_added"):
		_profile_manager.custom_binding_added.connect(func(_action, _event): _refresh_bindings())

func _on_profile_switched() -> void:
	_build_action_rows()
	_update_status("Profile switched. Select an action to rebind.")

func _on_bindings_reset() -> void:
	_refresh_bindings()
	_update_status("Bindings reset to defaults.")

func _build_action_rows() -> void:
	U_RebindActionListBuilder.build_action_rows(
		self,
		_action_list,
		_action_rows,
		_focusable_actions,
		_search_filter
	)

func _get_active_profile() -> RS_InputProfile:
	if _profile_manager == null:
		return null
	if _profile_manager.has_method("get_active_profile"):
		return _profile_manager.get_active_profile()
	if "active_profile" in _profile_manager:
		return _profile_manager.active_profile
	return null

func _refresh_bindings() -> void:
	U_RebindActionListBuilder.refresh_bindings(self, _action_rows)

func _begin_capture(action: StringName, mode: String) -> void:
	U_RebindCaptureHandler.begin_capture(self, action, mode)

func _cancel_capture(message: String = "Select an action to rebind.") -> void:
	U_RebindCaptureHandler.cancel_capture(self, message)

func _input(event: InputEvent) -> void:
	U_RebindCaptureHandler.handle_input(self, event)

func _handle_captured_event(event: InputEvent) -> void:
	U_RebindCaptureHandler.handle_captured_event(self, event)

func _apply_binding(event: InputEvent, conflict_action: StringName) -> void:
	await U_RebindCaptureHandler.apply_binding(self, event, conflict_action)

func _resolve_preferred_store() -> I_StateStore:
	var stores := get_tree().get_nodes_in_group("state_store")
	var fallback_store: I_StateStore = null
	for entry in stores:
		var candidate := entry as I_StateStore
		if candidate == null:
			continue
		if "dispatched_actions" in candidate:
			return candidate
		if fallback_store == null:
			fallback_store = candidate
	return fallback_store

func _ensure_store_reference() -> void:
	if _store != null and is_instance_valid(_store):
		return
	var resolved := _resolve_preferred_store()
	if resolved != null:
		_store = resolved
		return
	_store = get_store()

func _get_action_events(action: StringName) -> Array[InputEvent]:
	return U_RebindCaptureHandler.get_action_events(self, action)

func _build_final_target_events(existing: Array[InputEvent], event: InputEvent, replace_existing: bool) -> Array[InputEvent]:
	return U_RebindCaptureHandler.build_final_target_events(existing, event, replace_existing)

func _build_final_conflict_events(conflict_existing: Array[InputEvent], previous_target: Array[InputEvent], new_event: InputEvent, replace_existing: bool) -> Array[InputEvent]:
	return U_RebindCaptureHandler.build_final_conflict_events(
		conflict_existing,
		previous_target,
		new_event,
		replace_existing
	)

func _append_unique_event(events: Array[InputEvent], candidate: InputEvent) -> void:
	U_RebindCaptureHandler.append_unique_event(events, candidate)

func _clone_event(source: InputEvent) -> InputEvent:
	return U_RebindCaptureHandler.clone_event(source)

func _get_active_device_category() -> String:
	_ensure_store_reference()
	if _store == null:
		return "keyboard"
	var state: Dictionary = _store.get_state()
	var device_type: int = U_InputSelectors.get_active_device_type(state)
	match device_type:
		1:
			return "gamepad"
		_:
			# Treat keyboard + mouse + touchscreen as keyboard-style bindings in this overlay.
			return "keyboard"

func _events_match(a: InputEvent, b: InputEvent) -> bool:
	return U_RebindCaptureHandler.events_match(a, b)

func _show_error(message: String) -> void:
	_error_dialog.dialog_text = message
	_error_dialog.popup_centered()

func _on_conflict_confirmed() -> void:
	if _pending_event == null or _pending_action == StringName():
		_cancel_capture("Rebind cancelled.")
		return
	var event := _pending_event.duplicate(true)
	var conflict := _pending_conflict
	_pending_event = null
	_pending_conflict = StringName()
	_apply_binding(event, conflict)

func _on_conflict_canceled() -> void:
	_pending_event = null
	_pending_conflict = StringName()
	_cancel_capture("Rebind cancelled.")

func _on_error_dismissed() -> void:
	if not _is_capturing:
		_refresh_bindings()

func _update_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text

func _on_close_pressed() -> void:
	if _is_capturing:
		_cancel_capture()
	_ensure_store_reference()
	var store := _store
	if store == null:
		_transition_back_to_settings_scene()
		return

	var nav_slice: Dictionary = store.get_state().get("navigation", {})
	var overlay_stack: Array = U_NavigationSelectors.get_overlay_stack(nav_slice)
	var shell: StringName = U_NavigationSelectors.get_shell(nav_slice)

	if not overlay_stack.is_empty():
		store.dispatch(U_NavigationActions.close_top_overlay())
	else:
		# Main menu path: when opened from the main menu settings panel,
		# navigation overlays are not used. Prefer a direct transition back
		# to the standalone settings scene so the Scene Manager can keep
		# navigation/base_scene_id in sync.
		if shell == StringName("main_menu"):
			_transition_back_to_settings_scene()
		else:
			store.dispatch(U_NavigationActions.set_shell(StringName("main_menu"), StringName("settings_menu")))

func _on_back_pressed() -> void:
	_on_close_pressed()

func _transition_back_to_settings_scene() -> void:
	var store := get_store()
	if store == null:
		return
	store.dispatch(U_NavigationActions.navigate_to_ui_screen(StringName("settings_menu"), "fade", 2))

func _process(delta: float) -> void:
	super._process(delta)
	_update_right_stick_scroll(delta)

func _update_right_stick_scroll(delta: float) -> void:
	if _scroll == null:
		return

	var axis_x: float = 0.0
	var axis_y: float = 0.0
	var found_device: bool = false

	for device in Input.get_connected_joypads():
		axis_x = Input.get_joy_axis(device, JOY_AXIS_RIGHT_X)
		axis_y = Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y)
		if abs(axis_x) > BaseMenuScreen.STICK_DEADZONE or abs(axis_y) > BaseMenuScreen.STICK_DEADZONE:
			found_device = true
			break

	if not found_device:
		return

	# Horizontal: axis_x > 0 scrolls right, < 0 scrolls left.
	# Vertical: axis_y > 0 scrolls down, < 0 scrolls up.
	var scroll_speed: float = 800.0
	var new_h: float = float(_scroll.scroll_horizontal) + axis_x * scroll_speed * delta
	var new_v: float = float(_scroll.scroll_vertical) + axis_y * scroll_speed * delta
	_scroll.scroll_horizontal = int(new_h)
	_scroll.scroll_vertical = int(new_v)

func _on_reset_pressed() -> void:
	if _is_capturing:
		_cancel_capture()
	# Show confirmation dialog before resetting
	if _reset_confirm_dialog != null:
		_reset_confirm_dialog.popup_centered()

func _on_reset_confirmed() -> void:
	_set_reset_button_enabled(false)
	if _profile_manager != null and _profile_manager.has_method("reset_to_defaults"):
		_profile_manager.reset_to_defaults()
		# Note: bindings_reset signal will trigger _refresh_bindings() automatically
	else:
		_show_error("Reset to defaults unavailable.")
	_set_reset_button_enabled(_profile_manager != null and not _is_capturing)

func _on_reset_canceled() -> void:
	# User canceled the reset, do nothing
	pass

func _set_reset_button_enabled(enabled: bool) -> void:
	if _reset_button == null:
		return
	var allow_reset := enabled and _profile_manager != null
	_reset_button.disabled = not allow_reset

func _is_reserved(action: StringName) -> bool:
	return U_InputRebindUtils.is_reserved_action(action, _rebind_settings)

func _format_binding_text(events: Array) -> String:
	var labels: Array[String] = []
	for ev in events:
		if ev is InputEvent:
			var event := ev as InputEvent
			labels.append(U_InputRebindUtils.format_event_label(event))
		elif ev is Dictionary:
			var reconstructed := U_InputRebindUtils.dict_to_event(ev)
			if reconstructed is InputEvent:
				labels.append(U_InputRebindUtils.format_event_label(reconstructed as InputEvent))
	return ", ".join(labels)

func _format_binding_label(binding_text: String) -> String:
	var trimmed := binding_text.strip_edges()
	if trimmed.begins_with("Key "):
		trimmed = trimmed.substr(4, trimmed.length() - 4)
	return trimmed

func _reset_single_action(action: StringName) -> void:
	if _is_reserved(action):
		_show_error("Cannot reset reserved action.")
		return
	if _profile_manager != null and _profile_manager.has_method("reset_action"):
		_profile_manager.reset_action(action)
		_refresh_bindings()
		_update_status("Action '{action}' reset to default.".format({
			"action": U_RebindActionListBuilder.format_action_name(action)
		}))
	else:
		_show_error("Reset action unavailable.")

# Helper functions for UX improvements

func _categorize_actions(actions: Array[StringName]) -> Dictionary:
	return U_RebindActionListBuilder._categorize_actions(actions)

func _matches_search_filter(action: StringName) -> bool:
	return U_RebindActionListBuilder._matches_search_filter(action, _search_filter)

func _on_search_changed(new_text: String) -> void:
	_search_filter = new_text
	_build_action_rows()

func _add_spacer(height: int) -> void:
	U_RebindActionListBuilder._add_spacer(_action_list, height)

func _is_binding_custom(action: StringName) -> bool:
	_ensure_store_reference()
	if _store == null:
		return false
	var state := _store.get_state()
	if state == null:
		return false
	var settings_variant: Variant = state.get("settings", {})
	if not (settings_variant is Dictionary):
		return false
	var input_variant: Variant = (settings_variant as Dictionary).get("input_settings", {})
	if not (input_variant is Dictionary):
		return false
	var bindings_variant: Variant = (input_variant as Dictionary).get("custom_bindings", {})
	if bindings_variant is Dictionary:
		return (bindings_variant as Dictionary).has(action)
	return false

func _configure_focus_neighbors() -> void:
	U_RebindFocusNavigation.configure_focus_neighbors(self)

func _get_first_focusable() -> Control:
	var first := U_RebindFocusNavigation.get_first_focusable(self)
	if first != null:
		return first
	return super._get_first_focusable()

func _unhandled_input(event: InputEvent) -> void:
	# Handle gamepad navigation separately so keyboard continues to use
	# the existing _unhandled_key_input path.
	if _is_capturing:
		super._unhandled_input(event)
		return

	# Let default UI navigation (neighbors) handle D-pad and keyboard,
	# so behavior matches other menus.
	super._unhandled_input(event)

func _exit_tree() -> void:
	if _capture_guard_active:
		U_InputCaptureGuard.end_capture()
	_capture_guard_active = false

func _focus_next_action() -> void:
	U_RebindFocusNavigation.focus_next_action(self)

func _focus_previous_action() -> void:
	U_RebindFocusNavigation.focus_previous_action(self)

func _apply_focus() -> void:
	U_RebindFocusNavigation.apply_focus(self)

func _cycle_row_button(direction: int) -> void:
	U_RebindFocusNavigation.cycle_row_button(self, direction)

func _ensure_row_visible(row: Control) -> void:
	U_RebindFocusNavigation.ensure_row_visible(self, row)

func _connect_row_focus_handlers(row: Control, add_button: Button, replace_button: Button, reset_button: Button) -> void:
	U_RebindFocusNavigation.connect_row_focus_handlers(self, row, add_button, replace_button, reset_button)

func _cycle_bottom_button(direction: int) -> void:
	U_RebindFocusNavigation.cycle_bottom_button(self, direction)

func _navigate(direction: StringName) -> void:
	U_RebindFocusNavigation.navigate(self, direction)

func _navigate_focus(direction: StringName) -> void:
	# Defer to BaseMenuScreen neighbor-based navigation for analog sticks
	# so movement feels consistent with other menus.
	super._navigate_focus(direction)

## Returns device type category for an InputEvent.
## Returns: "keyboard", "mouse", "gamepad", or "unknown"
func _get_event_device_type(event: InputEvent) -> String:
	return U_RebindActionListBuilder.get_event_device_type(event)
