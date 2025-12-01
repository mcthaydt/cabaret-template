@icon("res://resources/editor_icons/utility.svg")
extends "res://scripts/ui/base/base_overlay.gd"
class_name InputRebindingOverlay

const U_InputActions := preload("res://scripts/state/actions/u_input_actions.gd")
const U_InputRebindUtils := preload("res://scripts/utils/u_input_rebind_utils.gd")
const U_InputCaptureGuard := preload("res://scripts/utils/u_input_capture_guard.gd")
const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_FocusConfigurator := preload("res://scripts/ui/helpers/u_focus_configurator.gd")
const U_InputSelectors := preload("res://scripts/state/selectors/u_input_selectors.gd")
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

var _profile_manager: Node = null
var _rebind_settings: RS_RebindSettings = null
var _is_capturing: bool = false
var _pending_action: StringName = StringName()
var _pending_event: InputEvent = null
var _pending_conflict: StringName = StringName()
var _action_rows: Dictionary = {}  # StringName -> {container: VBoxContainer, name_label: Label, binding_label: Label, replace_button: Button, add_button: Button, reset_button: Button, category_header: Label}
var _capture_mode: String = U_InputActions.REBIND_MODE_REPLACE
var _search_filter: String = ""
var _focused_action_index: int = -1
var _focusable_actions: Array[StringName] = []
var _capture_guard_active: bool = false
var _is_on_bottom_row: bool = false
var _bottom_button_index: int = 0
var _row_button_index: int = 0

const REPLACE_BUTTON_TEXT := "Replace"
const ADD_BUTTON_TEXT := "Add Binding"
const RESET_BUTTON_TEXT := "Reset"
const ROW_SPACING := 8
const CATEGORY_SPACING := 16

# Action categories for grouping
const ACTION_CATEGORIES := {
	"movement": ["move_left", "move_right", "move_forward", "move_backward", "jump", "crouch", "sprint"],
	"combat": ["attack", "defend", "special_attack"],
	"ui": ["pause", "interact", "menu", "inventory"],
	"camera": ["camera_up", "camera_down", "camera_left", "camera_right", "zoom_in", "zoom_out"]
}

# Actions to exclude from the overlay (built-in Godot actions users shouldn't rebind)
const EXCLUDED_ACTIONS := [
	# Built-in UI navigation
	"ui_accept", "ui_select", "ui_cancel", "ui_focus_next", "ui_focus_prev",
	"ui_left", "ui_right", "ui_up", "ui_down", "ui_page_up", "ui_page_down",
	"ui_home", "ui_end",
	# Text editing
	"ui_text_completion_query", "ui_text_completion_accept", "ui_text_completion_replace",
	"ui_text_newline", "ui_text_newline_blank", "ui_text_newline_above",
	"ui_text_indent", "ui_text_dedent", "ui_text_backspace", "ui_text_backspace_word",
	"ui_text_backspace_word.macos", "ui_text_backspace_all_to_left", "ui_text_backspace_all_to_left.macos",
	"ui_text_delete", "ui_text_delete_word", "ui_text_delete_word.macos",
	"ui_text_delete_all_to_right", "ui_text_delete_all_to_right.macos",
	"ui_text_caret_left", "ui_text_caret_word_left", "ui_text_caret_word_left.macos",
	"ui_text_caret_right", "ui_text_caret_word_right", "ui_text_caret_word_right.macos",
	"ui_text_caret_up", "ui_text_caret_down",
	"ui_text_caret_line_start", "ui_text_caret_line_start.macos",
	"ui_text_caret_line_end", "ui_text_caret_line_end.macos",
	"ui_text_caret_page_up", "ui_text_caret_page_down",
	"ui_text_caret_document_start", "ui_text_caret_document_start.macos",
	"ui_text_caret_document_end", "ui_text_caret_document_end.macos",
	"ui_text_caret_add_below", "ui_text_caret_add_below.macos",
	"ui_text_caret_add_above", "ui_text_caret_add_above.macos",
	"ui_text_scroll_up", "ui_text_scroll_up.macos",
	"ui_text_scroll_down", "ui_text_scroll_down.macos",
	"ui_text_select_all", "ui_text_select_word_under_caret", "ui_text_select_word_under_caret.macos",
	"ui_text_add_selection_for_next_occurrence", "ui_text_skip_selection_for_next_occurrence",
	"ui_text_clear_carets_and_selection", "ui_text_toggle_insert_mode",
	"ui_menu", "ui_text_submit",
	# Copy/paste/undo
	"ui_cut", "ui_copy", "ui_paste", "ui_undo", "ui_redo",
	# Accessibility and other built-ins
	"ui_accessibility_drag_and_drop", "ui_focus_mode", "ui_unicode_start",
	"ui_graph_duplicate", "ui_graph_delete", "ui_graph_follow_left", "ui_graph_follow_left.macos",
	"ui_graph_follow_right", "ui_graph_follow_right.macos",
	"ui_filedialog_up_one_level", "ui_filedialog_refresh", "ui_filedialog_show_hidden",
	"ui_swap_input_direction", "ui_colorpicker_delete_preset",
	# Editor-specific
	"editor", "editor_forward", "editor_backward"
]

func _on_panel_ready() -> void:
	_profile_manager = get_tree().get_first_node_in_group("input_profile_manager")
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
	_update_status("Select an action to rebind. Use Tab/Arrow keys to navigate.")
	_set_reset_button_enabled(_profile_manager != null)

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
	for child in _action_list.get_children():
		child.queue_free()
	_action_rows.clear()
	_focusable_actions.clear()

	var actions := _collect_actions()
	var categorized_actions := _categorize_actions(actions)

	for category in categorized_actions.keys():
		var category_actions: Array = categorized_actions[category]
		if category_actions.is_empty():
			continue

		# Add category header
		var category_header := Label.new()
		category_header.text = category.capitalize()
		category_header.add_theme_font_size_override("font_size", 16)
		category_header.modulate = Color(0.8, 0.8, 1.0, 1.0)
		_action_list.add_child(category_header)

		# Add spacing after header
		_add_spacer(CATEGORY_SPACING / 2)

		for action in category_actions:
			# Skip if filtered out by search
			if not _matches_search_filter(action):
				continue

			_focusable_actions.append(action)

			# Use VBoxContainer to stack label row and button row vertically
			var row := VBoxContainer.new()
			row.name = String(action)
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.focus_mode = Control.FOCUS_ALL

			# Top row: Action name and current binding
			var label_row := HBoxContainer.new()
			label_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			var name_label := Label.new()
			name_label.text = _format_action_name(action)
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_label.add_theme_font_size_override("font_size", 14)

			var bindings_label := Label.new()
			bindings_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bindings_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			bindings_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))

			label_row.add_child(name_label)
			label_row.add_child(bindings_label)

			# Bottom row: Buttons
			var button_row := HBoxContainer.new()
			button_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			var add_button := Button.new()
			add_button.text = ADD_BUTTON_TEXT
			add_button.custom_minimum_size = Vector2(100, 32)
			add_button.tooltip_text = "Add an additional binding for this action"
			add_button.pressed.connect(func(): _begin_capture(action, U_InputActions.REBIND_MODE_ADD))
			button_row.add_child(add_button)

			var replace_button := Button.new()
			replace_button.text = REPLACE_BUTTON_TEXT
			replace_button.custom_minimum_size = Vector2(80, 32)
			replace_button.tooltip_text = "Replace all bindings for this action"
			replace_button.pressed.connect(func(): _begin_capture(action, U_InputActions.REBIND_MODE_REPLACE))
			button_row.add_child(replace_button)

			var reset_button := Button.new()
			reset_button.text = RESET_BUTTON_TEXT
			reset_button.custom_minimum_size = Vector2(60, 32)
			reset_button.tooltip_text = "Reset this action to default binding"
			reset_button.pressed.connect(func(): _reset_single_action(action))
			button_row.add_child(reset_button)

			row.add_child(label_row)
			row.add_child(button_row)

			# Add separator
			var separator := HSeparator.new()
			separator.modulate = Color(0.3, 0.3, 0.3, 0.5)
			row.add_child(separator)

			_action_list.add_child(row)

			_action_rows[action] = {
				"container": row,
				"name_label": name_label,
				"binding_label": bindings_label,
				"add_button": add_button,
				"replace_button": replace_button,
				"reset_button": reset_button,
				"category_header": category_header
			}

			# Ensure rows remain visible when focused via keyboard/gamepad.
			_connect_row_focus_handlers(row, add_button, replace_button, reset_button)

			if _is_reserved(action):
				add_button.disabled = true
				replace_button.disabled = true
				reset_button.disabled = true
				add_button.text = "Reserved"
				replace_button.text = "Reserved"
				reset_button.text = "Reserved"

			# Add spacing between rows
			_add_spacer(ROW_SPACING)

	_refresh_bindings()
	_set_reset_button_enabled(_profile_manager != null and not _is_capturing)

	_configure_focus_neighbors()

	# Initialize focus on the first action when available so gamepad/keyboard
	# navigation starts from the list instead of the search box.
	if not _focusable_actions.is_empty():
		_focused_action_index = 0
		_is_on_bottom_row = false
		_row_button_index = 0
		_apply_focus()
	else:
		_focused_action_index = -1
		_is_on_bottom_row = false

func _collect_actions() -> Array[StringName]:
	var actions: Array[StringName] = []
	var seen: Dictionary = {}

	# Always show all InputMap actions (includes system actions like pause)
	for action_name in InputMap.get_actions():
		var action := StringName(action_name)
		# Skip excluded built-in actions
		if String(action) in EXCLUDED_ACTIONS:
			continue
		if not seen.has(action):
			actions.append(action)
			seen[action] = true

	# Also include any additional actions from the profile that might not be in InputMap
	var profile := _get_active_profile()
	if profile != null:
		for key in profile.action_mappings.keys():
			var action := StringName(key)
			# Skip excluded built-in actions
			if String(action) in EXCLUDED_ACTIONS:
				continue
			if not seen.has(action):
				actions.append(action)
				seen[action] = true

	actions.sort_custom(func(a: StringName, b: StringName) -> bool:
		var str_a := String(a)
		var str_b := String(b)
		var lower_a := str_a.to_lower()
		var lower_b := str_b.to_lower()
		if lower_a == lower_b:
			return str_a < str_b
		return lower_a < lower_b
	)
	return actions

func _get_active_profile() -> RS_InputProfile:
	if _profile_manager == null:
		return null
	if _profile_manager.has_method("get_active_profile"):
		return _profile_manager.get_active_profile()
	if "active_profile" in _profile_manager:
		return _profile_manager.active_profile
	return null

func _refresh_bindings() -> void:
	var device_category: String = _get_active_device_category()

	for action in _action_rows.keys():
		var data: Dictionary = _action_rows[action]
		var binding_label: Label = data.get("binding_label")
		var name_label: Label = data.get("name_label")
		if binding_label == null:
			continue
		var events := InputMap.action_get_events(action)
		var filtered_events: Array[InputEvent] = []
		for event in events:
			if event is InputEvent:
				var device_type: String = _get_event_device_type(event as InputEvent)
				if device_category == "gamepad":
					if device_type == "gamepad":
						filtered_events.append(event)
				else:
					if device_type == "keyboard" or device_type == "mouse" or device_type == "unknown":
						filtered_events.append(event)

		var display_events: Array = filtered_events
		if display_events.is_empty():
			display_events = events

		if display_events.is_empty():
			binding_label.text = "Unbound"
		else:
			binding_label.text = _format_binding_text(display_events)

		# Add visual indicator for custom bindings
		var is_custom := _is_binding_custom(action)
		if is_custom and name_label != null:
			name_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4, 1.0))  # Gold color for custom
			binding_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4, 1.0))
		elif name_label != null:
			name_label.remove_theme_color_override("font_color")
			binding_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))

		var add_button: Button = data.get("add_button")
		var replace_button: Button = data.get("replace_button")
		var reset_button: Button = data.get("reset_button")
		var reserved := _is_reserved(action)
		if add_button != null:
			if reserved:
				add_button.disabled = true
				add_button.text = "Reserved"
			else:
				if _is_capturing:
					if action == _pending_action and _capture_mode == U_InputActions.REBIND_MODE_ADD:
						add_button.text = "Listening..."
					else:
						add_button.text = ADD_BUTTON_TEXT
					add_button.disabled = true
				else:
					add_button.disabled = false
					add_button.text = ADD_BUTTON_TEXT
		if replace_button != null:
			if reserved:
				replace_button.disabled = true
				replace_button.text = "Reserved"
			else:
				if _is_capturing:
					if action == _pending_action and _capture_mode == U_InputActions.REBIND_MODE_REPLACE:
						replace_button.text = "Listening..."
					else:
						replace_button.text = REPLACE_BUTTON_TEXT
					replace_button.disabled = true
				else:
					replace_button.disabled = false
					replace_button.text = REPLACE_BUTTON_TEXT
		if reset_button != null:
			if reserved:
				reset_button.disabled = true
			else:
				reset_button.disabled = _is_capturing
	if not _is_capturing:
		_set_reset_button_enabled(_profile_manager != null)

func _begin_capture(action: StringName, mode: String) -> void:
	if _is_capturing:
		return
	if _is_reserved(action):
		_show_error("Cannot rebind reserved action.")
		return

	_is_capturing = true
	_capture_guard_active = true
	U_InputCaptureGuard.begin_capture()
	_pending_action = action
	_pending_event = null
	_pending_conflict = StringName()
	_capture_mode = mode

	for key in _action_rows.keys():
		var row: Dictionary = _action_rows[key]
		var add_button: Button = row.get("add_button")
		var replace_button: Button = row.get("replace_button")
		var is_reserved := _is_reserved(key)
		if add_button != null:
			if is_reserved:
				add_button.text = "Reserved"
			elif key == action and mode == U_InputActions.REBIND_MODE_ADD:
				add_button.text = "Listening..."
			else:
				add_button.text = ADD_BUTTON_TEXT
			add_button.disabled = true
		if replace_button != null:
			if is_reserved:
				replace_button.text = "Reserved"
			elif key == action and mode == U_InputActions.REBIND_MODE_REPLACE:
				replace_button.text = "Listening..."
			else:
				replace_button.text = REPLACE_BUTTON_TEXT
			replace_button.disabled = true
	_update_status("Press new input for {action} (Esc to cancel).".format({"action": _format_action_name(action)}))
	_set_reset_button_enabled(false)

func _cancel_capture(message: String = "Select an action to rebind.") -> void:
	if _capture_guard_active:
		U_InputCaptureGuard.end_capture()
	_capture_guard_active = false
	_is_capturing = false
	_pending_action = StringName()
	_pending_event = null
	_pending_conflict = StringName()
	_capture_mode = U_InputActions.REBIND_MODE_REPLACE
	_refresh_bindings()
	_update_status(message)
	_set_reset_button_enabled(_profile_manager != null)

func _input(event: InputEvent) -> void:
	if not _is_capturing:
		return
	if event == null:
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		if key_event.keycode == Key.KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_cancel_capture("Rebind cancelled.")
			return
		_handle_captured_event(key_event)
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed:
			return
		_handle_captured_event(mouse_event)
	elif event is InputEventJoypadButton:
		var joy_button := event as InputEventJoypadButton
		if not joy_button.pressed:
			return
		_handle_captured_event(joy_button)
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if abs(motion.axis_value) < 0.5:
			return
		var motion_copy := motion.duplicate(true) as InputEventJoypadMotion
		motion_copy.axis_value = signf(motion_copy.axis_value)
		_handle_captured_event(motion_copy)

func _handle_captured_event(event: InputEvent) -> void:
	if not _is_capturing or _pending_action == StringName():
		return
	get_viewport().set_input_as_handled()
	_is_capturing = false
	var event_copy := event.duplicate(true)
	var replace_existing := (_capture_mode == U_InputActions.REBIND_MODE_REPLACE)
	var validation := U_InputRebindUtils.validate_rebind(
		_pending_action,
		event_copy,
		_rebind_settings,
		replace_existing,
		_get_active_profile(),
		EXCLUDED_ACTIONS
	)
	if not validation.valid:
		_show_error(validation.error if not validation.error.is_empty() else "Rebind failed.")
		_cancel_capture("Rebind failed.")
		return

	if validation.conflict_action != StringName():
		_pending_event = event_copy
		_pending_conflict = validation.conflict_action
		var conflict_name := _format_action_name(validation.conflict_action)
		var binding_text := _format_binding_text([event_copy])
		_conflict_dialog.dialog_text = "{binding} is already bound to {action}. Replace binding?".format({
			"binding": _format_binding_label(binding_text),
			"action": conflict_name
		})
		_conflict_dialog.popup_centered()
	else:
		_apply_binding(event_copy, StringName())

func _apply_binding(event: InputEvent, conflict_action: StringName) -> void:
	var action := _pending_action
	var replace_existing := (_capture_mode == U_InputActions.REBIND_MODE_REPLACE)
	var target_existing := _get_action_events(action)
	var conflict_existing: Array[InputEvent] = []
	if conflict_action != StringName():
		conflict_existing = _get_action_events(conflict_action)

	var final_target := _build_final_target_events(target_existing, event, replace_existing)
	var final_conflict: Array[InputEvent] = []
	if conflict_action != StringName():
		final_conflict = _build_final_conflict_events(conflict_existing, target_existing, event, replace_existing)

	_ensure_store_reference()
	if _store == null:
		_show_error("State store not available.")
		_cancel_capture("Rebind failed.")
		return

	var dispatch_event := event
	if dispatch_event != null:
		dispatch_event = dispatch_event.duplicate(true)

	_store.dispatch(U_InputActions.rebind_action(action, dispatch_event, _capture_mode, final_target))

	if conflict_action != StringName():
		var conflict_event: InputEvent = null
		if not final_conflict.is_empty():
			conflict_event = final_conflict[0].duplicate(true)
		_store.dispatch(U_InputActions.rebind_action(conflict_action, conflict_event, U_InputActions.REBIND_MODE_REPLACE, final_conflict))

	await get_tree().process_frame

	var binding_text := _format_binding_text(final_target)
	_cancel_capture("{action} bound to {binding}.".format({
		"action": _format_action_name(action),
		"binding": _format_binding_label(binding_text)
	}))

func _resolve_preferred_store() -> M_StateStore:
	var stores := get_tree().get_nodes_in_group("state_store")
	var fallback_store: M_StateStore = null
	for entry in stores:
		var candidate := entry as M_StateStore
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
	var results: Array[InputEvent] = []
	if action == StringName():
		return results
	if not InputMap.has_action(action):
		return results
	for existing in InputMap.action_get_events(action):
		if existing is InputEvent:
			var cloned := _clone_event(existing)
			if cloned != null:
				results.append(cloned)
	return results

func _build_final_target_events(existing: Array[InputEvent], event: InputEvent, replace_existing: bool) -> Array[InputEvent]:
	var final_events: Array[InputEvent] = []
	if replace_existing:
		# Device-type aware replace:
		# 1. Preserve events from OTHER device types only
		# 2. Replace ALL events of the SAME device type with the new event
		if event != null:
			var new_device_type := _get_event_device_type(event)
			# Keep existing events ONLY from different device types
			for existing_event in existing:
				var existing_device_type := _get_event_device_type(existing_event)
				if existing_device_type != new_device_type:
					_append_unique_event(final_events, existing_event)
			# Add the new event (replaces all events of same device type)
			_append_unique_event(final_events, event)
		return final_events
	# Add mode: keep all existing + add new
	for existing_event in existing:
		_append_unique_event(final_events, existing_event)
	_append_unique_event(final_events, event)
	return final_events

func _build_final_conflict_events(conflict_existing: Array[InputEvent], previous_target: Array[InputEvent], new_event: InputEvent, replace_existing: bool) -> Array[InputEvent]:
	var final_events: Array[InputEvent] = []
	for conflict_event in conflict_existing:
		if new_event != null and _events_match(conflict_event, new_event):
			continue
		_append_unique_event(final_events, conflict_event)
	if replace_existing:
		for previous_event in previous_target:
			if new_event != null and _events_match(previous_event, new_event):
				continue
			_append_unique_event(final_events, previous_event)
	return final_events

func _append_unique_event(events: Array[InputEvent], candidate: InputEvent) -> void:
	if candidate == null:
		return
	for existing in events:
		if _events_match(existing, candidate):
			return
	var clone := _clone_event(candidate)
	if clone != null:
		events.append(clone)

func _clone_event(source: InputEvent) -> InputEvent:
	if source == null:
		return null
	var dict := U_InputRebindUtils.event_to_dict(source)
	if dict.is_empty():
		return null
	return U_InputRebindUtils.dict_to_event(dict)

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
	if a == null or b == null:
		return false
	return a.is_match(b) and b.is_match(a)

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
	var store := get_store()
	if store != null:
		store.dispatch(U_NavigationActions.close_top_overlay())
	else:
		queue_free()

func _on_back_pressed() -> void:
	_on_close_pressed()

func _process(delta: float) -> void:
	# Preserve base menu behavior (analog repeat on left stick)
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

func _format_action_name(action: StringName) -> String:
	var text := String(action)
	text = text.replace("_", " ")
	if text.is_empty():
		return ""
	var words := text.split(" ", false)
	for i in range(words.size()):
		var word := words[i]
		if word.is_empty():
			continue
		words[i] = word.left(1).to_upper() + word.substr(1).to_lower()
	return " ".join(words)

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
		_update_status("Action '{action}' reset to default.".format({"action": _format_action_name(action)}))
	else:
		_show_error("Reset action unavailable.")

# Helper functions for UX improvements

func _categorize_actions(actions: Array[StringName]) -> Dictionary:
	var categorized: Dictionary = {}
	var uncategorized: Array[StringName] = []

	# Initialize categories
	for category in ACTION_CATEGORIES.keys():
		categorized[category] = []

	# Sort actions into categories
	for action in actions:
		var found := false
		for category in ACTION_CATEGORIES.keys():
			if action in ACTION_CATEGORIES[category]:
				categorized[category].append(action)
				found = true
				break
		if not found:
			uncategorized.append(action)

	# Add uncategorized actions to "other" category
	if not uncategorized.is_empty():
		categorized["other"] = uncategorized

	return categorized

func _matches_search_filter(action: StringName) -> bool:
	if _search_filter.is_empty():
		return true
	var action_name := _format_action_name(action).to_lower()
	return action_name.contains(_search_filter.to_lower())

func _on_search_changed(new_text: String) -> void:
	_search_filter = new_text
	_build_action_rows()

func _add_spacer(height: int) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	_action_list.add_child(spacer)

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
	# Horizontal neighbors for per-row buttons
	for action in _focusable_actions:
		if not _action_rows.has(action):
			continue
		var row_data: Dictionary = _action_rows[action]
		var add_button: Button = row_data.get("add_button")
		var replace_button: Button = row_data.get("replace_button")
		var reset_button: Button = row_data.get("reset_button")

		var row_buttons: Array[Control] = []
		if add_button != null:
			row_buttons.append(add_button)
		if replace_button != null:
			row_buttons.append(replace_button)
		if reset_button != null:
			row_buttons.append(reset_button)
		if not row_buttons.is_empty():
			U_FocusConfigurator.configure_horizontal_focus(row_buttons, false)

	# Vertical neighbors for primary controls (Add buttons)
	var add_buttons: Array[Button] = []
	for action in _focusable_actions:
		var row: Dictionary = _action_rows.get(action, {}) as Dictionary
		var add_button: Button = row.get("add_button")
		if add_button != null:
			add_buttons.append(add_button)

	var count: int = add_buttons.size()
	for i in range(count):
		var btn: Button = add_buttons[i]
		if btn == null:
			continue
		# Previous row
		if i > 0:
			btn.focus_neighbor_top = btn.get_path_to(add_buttons[i - 1])
		# Next row
		if i < count - 1:
			btn.focus_neighbor_bottom = btn.get_path_to(add_buttons[i + 1])

	# Bottom-row buttons (Reset to Defaults / Close)
	var bottom_buttons: Array[Control] = []
	if _reset_button != null:
		bottom_buttons.append(_reset_button)
	if _close_button != null:
		bottom_buttons.append(_close_button)

	if not bottom_buttons.is_empty():
		U_FocusConfigurator.configure_horizontal_focus(bottom_buttons, true)
		# Link last Add button to bottom row
		if count > 0:
			var last_add: Button = add_buttons[count - 1]
			if last_add != null:
				last_add.focus_neighbor_bottom = last_add.get_path_to(bottom_buttons[0])
				for bottom in bottom_buttons:
					if bottom != null:
						bottom.focus_neighbor_top = bottom.get_path_to(last_add)

func _get_first_focusable() -> Control:
	# Prefer focusing the first row's Add button rather than the search box
	# so gamepad users land on an action immediately.
	if not _focusable_actions.is_empty():
		var first_action := _focusable_actions[0]
		if _action_rows.has(first_action):
			var row_data: Dictionary = _action_rows[first_action]
			var add_button: Button = row_data.get("add_button")
			if add_button != null:
				return add_button
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
	if _focusable_actions.is_empty():
		return
	_row_button_index = 0
	_focused_action_index = (_focused_action_index + 1) % _focusable_actions.size()
	_apply_focus()

func _focus_previous_action() -> void:
	if _focusable_actions.is_empty():
		return
	_row_button_index = 0
	_focused_action_index -= 1
	if _focused_action_index < 0:
		_focused_action_index = _focusable_actions.size() - 1
	_apply_focus()

func _apply_focus() -> void:
	# When on the bottom button row, focus the appropriate bottom button.
	if _is_on_bottom_row:
		var buttons: Array[Button] = []
		if _reset_button != null and not _reset_button.disabled:
			buttons.append(_reset_button)
		if _close_button != null and not _close_button.disabled:
			buttons.append(_close_button)

		if buttons.is_empty():
			_is_on_bottom_row = false
		else:
			if _bottom_button_index < 0 or _bottom_button_index >= buttons.size():
				_bottom_button_index = clampi(_bottom_button_index, 0, buttons.size() - 1)
			var button := buttons[_bottom_button_index]
			if button != null:
				button.grab_focus()

		# Dim all action rows when bottom buttons are focused.
		for action_key in _action_rows.keys():
			var data: Dictionary = _action_rows[action_key]
			var row_container: Control = data.get("container")
			if row_container != null:
				row_container.modulate = Color(1, 1, 1, 0.7)
		if _is_on_bottom_row:
			return

	if _focused_action_index < 0 or _focused_action_index >= _focusable_actions.size():
		return

	var action := _focusable_actions[_focused_action_index]
	if not _action_rows.has(action):
		return

	var row_data: Dictionary = _action_rows[action]
	var add_button: Button = row_data.get("add_button")
	var replace_button: Button = row_data.get("replace_button")
	var reset_button: Button = row_data.get("reset_button")

	var row_buttons: Array[Button] = []
	if add_button != null and not add_button.disabled:
		row_buttons.append(add_button)
	if replace_button != null and not replace_button.disabled:
		row_buttons.append(replace_button)
	if reset_button != null and not reset_button.disabled:
		row_buttons.append(reset_button)

	if not row_buttons.is_empty():
		if _row_button_index < 0 or _row_button_index >= row_buttons.size():
			_row_button_index = clampi(_row_button_index, 0, row_buttons.size() - 1)
		var focused_button := row_buttons[_row_button_index]
		if focused_button != null:
			focused_button.grab_focus()
	else:
		var container: Control = row_data.get("container")
		if container != null:
			container.grab_focus()

	# Highlight focused row
	for other_action in _action_rows.keys():
		var other_data: Dictionary = _action_rows[other_action]
		var other_container: Control = other_data.get("container")
		if other_container != null:
			other_container.modulate = Color(1, 1, 1, 1) if other_action == action else Color(1, 1, 1, 0.7)

func _cycle_row_button(direction: int) -> void:
	if _focused_action_index < 0 or _focused_action_index >= _focusable_actions.size():
		return
	var action := _focusable_actions[_focused_action_index]
	if not _action_rows.has(action):
		return

	var row_data: Dictionary = _action_rows[action]
	var add_button: Button = row_data.get("add_button")
	var replace_button: Button = row_data.get("replace_button")
	var reset_button: Button = row_data.get("reset_button")

	var row_buttons: Array[Button] = []
	if add_button != null and not add_button.disabled:
		row_buttons.append(add_button)
	if replace_button != null and not replace_button.disabled:
		row_buttons.append(replace_button)
	if reset_button != null and not reset_button.disabled:
		row_buttons.append(reset_button)
	if row_buttons.is_empty():
		return

	_row_button_index += direction
	if _row_button_index < 0:
		_row_button_index = row_buttons.size() - 1
	if _row_button_index >= row_buttons.size():
		_row_button_index = 0

	_apply_focus()

func _ensure_row_visible(row: Control) -> void:
	if row == null:
		return
	if _scroll == null:
		return
	if not row.is_inside_tree():
		return
	# Preserve horizontal scroll and only adjust vertical position so
	# moving focus up/down does not cause horizontal jitter.
	var original_horizontal: float = _scroll.scroll_horizontal
	_scroll.ensure_control_visible(row)
	_scroll.scroll_horizontal = original_horizontal

func _connect_row_focus_handlers(row: Control, add_button: Button, replace_button: Button, reset_button: Button) -> void:
	if row != null:
		row.focus_entered.connect(func() -> void:
			_ensure_row_visible(row)
		)
	if add_button != null:
		add_button.focus_entered.connect(func() -> void:
			_ensure_row_visible(row)
		)
	if replace_button != null:
		replace_button.focus_entered.connect(func() -> void:
			_ensure_row_visible(row)
		)
	if reset_button != null:
		reset_button.focus_entered.connect(func() -> void:
			_ensure_row_visible(row)
		)

func _cycle_bottom_button(direction: int) -> void:
	var buttons: Array[Button] = []
	if _reset_button != null and not _reset_button.disabled:
		buttons.append(_reset_button)
	if _close_button != null and not _close_button.disabled:
		buttons.append(_close_button)
	if buttons.is_empty():
		return

	_bottom_button_index += direction
	if _bottom_button_index < 0:
		_bottom_button_index = buttons.size() - 1
	if _bottom_button_index >= buttons.size():
		_bottom_button_index = 0

	_apply_focus()

func _navigate(direction: StringName) -> void:
	if _is_capturing:
		return

	match direction:
		StringName("ui_up"):
			if _is_on_bottom_row:
				_is_on_bottom_row = false
				if _focusable_actions.is_empty():
					return
				if _focused_action_index < 0 or _focused_action_index >= _focusable_actions.size():
					_focused_action_index = _focusable_actions.size() - 1
				_apply_focus()
			else:
				_focus_previous_action()
		StringName("ui_down"):
			if _is_on_bottom_row:
				return
			if _focusable_actions.is_empty():
				if _reset_button != null or _close_button != null:
					_is_on_bottom_row = true
					_bottom_button_index = 0
					_apply_focus()
				return
			if _focused_action_index < 0:
				_focused_action_index = 0
				_apply_focus()
				return
			if _focused_action_index < _focusable_actions.size() - 1:
				_focus_next_action()
			else:
				if _reset_button != null or _close_button != null:
					_is_on_bottom_row = true
					_bottom_button_index = 0
					_apply_focus()
		StringName("ui_left"):
			if _is_on_bottom_row:
				_cycle_bottom_button(-1)
			else:
				_cycle_row_button(-1)
		StringName("ui_right"):
			if _is_on_bottom_row:
				_cycle_bottom_button(1)
			else:
				_cycle_row_button(1)

func _navigate_focus(direction: StringName) -> void:
	# Defer to BaseMenuScreen neighbor-based navigation for analog sticks
	# so movement feels consistent with other menus.
	super._navigate_focus(direction)

## Returns device type category for an InputEvent.
## Returns: "keyboard", "mouse", "gamepad", or "unknown"
func _get_event_device_type(event: InputEvent) -> String:
	if event is InputEventKey:
		return "keyboard"
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		return "mouse"
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return "gamepad"
	else:
		return "unknown"
