@icon("res://resources/editor_icons/utility.svg")
extends "res://scripts/ui/base/base_overlay.gd"
class_name UI_SaveLoadMenu

## Save/Load Menu - Combined overlay for saving and loading game slots
##
## Modes:
## - "save": Show save actions (Save/Overwrite, Delete)
## - "load": Show load actions (Load, Delete)
##
## Mode is determined by navigation.save_load_mode in Redux state.

const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_NavigationSelectors := preload("res://scripts/state/selectors/u_navigation_selectors.gd")
const U_FocusConfigurator := preload("res://scripts/ui/helpers/u_focus_configurator.gd")
const U_ServiceLocator := preload("res://scripts/core/u_service_locator.gd")
const U_ECSEventBus := preload("res://scripts/ecs/u_ecs_event_bus.gd")
const M_SaveManager := preload("res://scripts/managers/m_save_manager.gd")

## Current mode: "save" or "load"
var _mode: StringName = StringName("")

## Reference to M_SaveManager
var _save_manager: Node = null  # M_SaveManager

## Cached slot metadata
var _cached_metadata: Array[Dictionary] = []


## Confirmation dialog state
var _pending_action: Dictionary = {}  # {action: "save"|"delete", slot_id: StringName}

## UI References (set via @onready once scene is created)
@onready var _mode_label: Label = %ModeLabel
@onready var _slot_list_container: VBoxContainer = %SlotListContainer
@onready var _back_button: Button = %BackButton
@onready var _confirmation_dialog: ConfirmationDialog = %ConfirmationDialog
@onready var _loading_spinner: Control = %LoadingSpinner

func _ready() -> void:
	await super._ready()
	_discover_save_manager()
	_subscribe_to_events()
	_refresh_ui()

func _discover_save_manager() -> void:
	_save_manager = U_ServiceLocator.try_get_service(StringName("save_manager"))
	if _save_manager == null:
		push_error("UI_SaveLoadMenu: M_SaveManager not found in ServiceLocator")

func _subscribe_to_events() -> void:
	# Subscribe to save events for UI updates
	U_ECSEventBus.subscribe(StringName("save_started"), _on_save_started)
	U_ECSEventBus.subscribe(StringName("save_completed"), _on_save_completed)
	U_ECSEventBus.subscribe(StringName("save_failed"), _on_save_failed)

	# Subscribe to load events for spinner and button state
	U_ECSEventBus.subscribe(StringName("load_started"), _on_load_started)
	U_ECSEventBus.subscribe(StringName("load_completed"), _on_load_completed)
	U_ECSEventBus.subscribe(StringName("load_failed"), _on_load_failed)

func _exit_tree() -> void:
	# Unsubscribe from save events
	U_ECSEventBus.unsubscribe(StringName("save_started"), _on_save_started)
	U_ECSEventBus.unsubscribe(StringName("save_completed"), _on_save_completed)
	U_ECSEventBus.unsubscribe(StringName("save_failed"), _on_save_failed)

	# Unsubscribe from load events
	U_ECSEventBus.unsubscribe(StringName("load_started"), _on_load_started)
	U_ECSEventBus.unsubscribe(StringName("load_completed"), _on_load_completed)
	U_ECSEventBus.unsubscribe(StringName("load_failed"), _on_load_failed)

	# Disconnect from store
	var store := get_store()
	if store != null and store.slice_updated.is_connected(_on_slice_updated):
		store.slice_updated.disconnect(_on_slice_updated)

func _on_store_ready(store_ref: I_StateStore) -> void:
	if store_ref != null:
		store_ref.slice_updated.connect(_on_slice_updated)
		_read_mode_from_state()

func _on_slice_updated(slice_name: StringName, _slice_state: Dictionary) -> void:
	if slice_name == StringName("navigation"):
		_read_mode_from_state()

func _read_mode_from_state() -> void:
	var store := get_store()
	if store == null:
		return

	var state: Dictionary = store.get_state()
	var nav_slice: Dictionary = state.get("navigation", {})
	var new_mode: StringName = nav_slice.get("save_load_mode", StringName(""))

	if new_mode != _mode:
		_mode = new_mode
		_refresh_ui()

func _refresh_ui() -> void:
	if not is_inside_tree():
		return

	# Update mode label
	_update_mode_label()

	# Refresh slot list
	_refresh_slot_list()

func _update_mode_label() -> void:
	if _mode_label == null:
		return

	if _mode == StringName("save"):
		_mode_label.text = "Save Game"
	elif _mode == StringName("load"):
		_mode_label.text = "Load Game"
	else:
		_mode_label.text = "Save / Load"

func _refresh_slot_list() -> void:
	if _save_manager == null or _slot_list_container == null:
		return

	# Store which slot index had focus before refresh
	var focused_slot_index: int = _get_focused_slot_index()

	# Get all slot metadata from M_SaveManager
	_cached_metadata = _save_manager.get_all_slot_metadata()

	# Clear existing slot items
	_clear_slot_list()

	# Create slot items
	for slot_meta in _cached_metadata:
		_create_slot_item(slot_meta)

	# Configure focus chain
	_configure_slot_focus()

	# Restore focus to the same slot (or first available if previous was deleted)
	_restore_focus_to_slot(focused_slot_index)

func _clear_slot_list() -> void:
	if _slot_list_container == null:
		return

	for child in _slot_list_container.get_children():
		child.queue_free()

func _create_slot_item(slot_meta: Dictionary) -> void:
	var slot_id: StringName = slot_meta.get("slot_id", StringName(""))
	var exists: bool = slot_meta.get("exists", false)
	var is_autosave: bool = (slot_id == M_SaveManager.SLOT_AUTOSAVE)

	# Create container for slot (main button + delete button)
	var slot_container := HBoxContainer.new()
	slot_container.name = "Slot_" + str(slot_id)

	# Create main save/load button (takes most of the space)
	var main_button := Button.new()
	main_button.name = "MainButton"
	main_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_button.alignment = HORIZONTAL_ALIGNMENT_LEFT

	if exists:
		# Populated slot - show metadata
		var timestamp: String = slot_meta.get("timestamp", "")
		var area_name: String = slot_meta.get("area_name", "Unknown")
		var playtime: int = slot_meta.get("playtime_seconds", 0)

		# Format display text with timestamp, area, and playtime
		var formatted_time: String = _format_timestamp(timestamp)
		var formatted_playtime: String = _format_playtime(playtime)

		# Multi-line text: Line 1 = slot name, Line 2 = metadata
		var slot_display_name: String = "AUTOSAVE" if is_autosave else slot_id.to_upper()
		main_button.text = "%s\n%s | %s | %s" % [
			slot_display_name,
			formatted_time,
			area_name,
			formatted_playtime
		]
	else:
		# Empty slot
		var slot_display_name: String = "AUTOSAVE" if is_autosave else slot_id.to_upper()
		if _mode == StringName("save"):
			main_button.text = "%s\n[New Save]" % slot_display_name
		else:
			main_button.text = "%s\n[Empty]" % slot_display_name
			main_button.disabled = true  # Can't load empty slots

	# Connect main button press (save/load action)
	main_button.pressed.connect(_on_slot_item_pressed.bind(slot_id, exists))

	# Create delete button (only for populated slots, hidden for autosave)
	var delete_button := Button.new()
	delete_button.name = "DeleteButton"
	delete_button.text = "Delete"
	delete_button.custom_minimum_size = Vector2(80, 0)

	# Show delete button only if slot is populated AND not autosave
	delete_button.visible = exists and not is_autosave
	delete_button.disabled = not exists or is_autosave

	# Connect delete button press
	if exists and not is_autosave:
		delete_button.pressed.connect(_on_delete_button_pressed.bind(slot_id))

	# Add buttons to container
	slot_container.add_child(main_button)
	slot_container.add_child(delete_button)

	_slot_list_container.add_child(slot_container)

func _format_playtime(seconds: int) -> String:
	var hours: int = seconds / 3600
	var minutes: int = (seconds % 3600) / 60
	var secs: int = seconds % 60
	return "%02d:%02d:%02d" % [hours, minutes, secs]

func _format_timestamp(iso_timestamp: String) -> String:
	# Convert ISO 8601 timestamp to human-readable format
	# Input: "2025-12-26T14:30:00Z"
	# Output: "Dec 26, 2025 2:30 PM"

	if iso_timestamp.is_empty():
		return "Unknown Date"

	# Parse ISO 8601 format: YYYY-MM-DDTHH:MM:SSZ
	var parts: PackedStringArray = iso_timestamp.split("T")
	if parts.size() < 2:
		return iso_timestamp  # Fallback to raw string if parsing fails

	var date_part: String = parts[0]
	var time_part: String = parts[1].replace("Z", "")

	# Parse date: YYYY-MM-DD
	var date_components: PackedStringArray = date_part.split("-")
	if date_components.size() < 3:
		return iso_timestamp

	var year: String = date_components[0]
	var month_num: int = date_components[1].to_int()
	var day: String = date_components[2]

	# Parse time: HH:MM:SS
	var time_components: PackedStringArray = time_part.split(":")
	if time_components.size() < 2:
		return iso_timestamp

	var hour: int = time_components[0].to_int()
	var minute: String = time_components[1]

	# Convert to 12-hour format
	var am_pm: String = "AM"
	var hour_12: int = hour
	if hour >= 12:
		am_pm = "PM"
		if hour > 12:
			hour_12 = hour - 12
	elif hour == 0:
		hour_12 = 12

	# Month names
	var month_names: Array[String] = [
		"Jan", "Feb", "Mar", "Apr", "May", "Jun",
		"Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
	]
	var month_name: String = month_names[month_num - 1] if month_num >= 1 and month_num <= 12 else "???"

	return "%s %s, %s %d:%s %s" % [month_name, day, year, hour_12, minute, am_pm]

func _is_delete_button_focusable(delete_button: Button) -> bool:
	## Helper to determine if a delete button should be in the focus chain
	## Returns true if the button is visible AND enabled
	return delete_button != null and delete_button.visible and not delete_button.disabled

func _configure_slot_focus() -> void:
	if _slot_list_container == null or _back_button == null:
		return

	# Phase 1: Collect focusable controls per slot
	var main_buttons_vertical: Array[Control] = []  # For vertical chain
	var delete_buttons_vertical: Array[Control] = []  # For vertical chain (with null placeholders)

	for container in _slot_list_container.get_children():
		if container is HBoxContainer:
			var main_btn := container.get_node_or_null("MainButton") as Button
			var delete_btn := container.get_node_or_null("DeleteButton") as Button

			# Only include focusable main buttons
			if main_btn != null and not main_btn.disabled:
				main_buttons_vertical.append(main_btn)
				# Track delete button if it's focusable (visible AND enabled)
				if _is_delete_button_focusable(delete_btn):
					delete_buttons_vertical.append(delete_btn)
				else:
					delete_buttons_vertical.append(null)  # Placeholder for alignment

	# Phase 2: Configure vertical navigation
	# Configure vertical chain for main buttons
	if not main_buttons_vertical.is_empty():
		U_FocusConfigurator.configure_vertical_focus(main_buttons_vertical, true)

	# Configure vertical chain for delete buttons (only focusable ones)
	var focusable_delete_buttons: Array[Control] = []
	for delete_btn in delete_buttons_vertical:
		if delete_btn != null:
			focusable_delete_buttons.append(delete_btn)

	if not focusable_delete_buttons.is_empty():
		U_FocusConfigurator.configure_vertical_focus(focusable_delete_buttons, true)

	# Phase 3: Configure horizontal navigation (main ↔ delete) within each slot
	for i in range(main_buttons_vertical.size()):
		var main_btn: Control = main_buttons_vertical[i]
		var delete_btn: Control = delete_buttons_vertical[i] if i < delete_buttons_vertical.size() else null

		if delete_btn != null:  # Only if focusable
			# Main button → right → delete button
			main_btn.focus_neighbor_right = main_btn.get_path_to(delete_btn)
			# Delete button → left → main button
			delete_btn.focus_neighbor_left = delete_btn.get_path_to(main_btn)
		else:
			# No horizontal navigation if delete is not focusable
			main_btn.focus_neighbor_right = NodePath()

	# Phase 4: Add back button and configure its vertical neighbor
	if not main_buttons_vertical.is_empty():
		var last_main_btn: Control = main_buttons_vertical[-1]
		last_main_btn.focus_neighbor_bottom = last_main_btn.get_path_to(_back_button)
		_back_button.focus_neighbor_top = _back_button.get_path_to(main_buttons_vertical[0])

func _get_focused_slot_index() -> int:
	# Returns the index of the currently focused slot container, or -1 if none
	var viewport := get_viewport()
	if viewport == null:
		return -1

	var focused_control := viewport.gui_get_focus_owner()
	if focused_control == null:
		return -1

	# Check if focused control is a main button inside a slot container
	var parent := focused_control.get_parent()
	if parent is HBoxContainer and parent.get_parent() == _slot_list_container:
		return parent.get_index()

	return -1

func _restore_focus_to_slot(slot_index: int) -> void:
	# Restore focus to the slot at the given index, or first available slot
	if _slot_list_container == null:
		return

	await get_tree().process_frame  # Wait for UI to settle

	var target_index: int = slot_index
	var slot_count: int = _slot_list_container.get_child_count()

	# Clamp to valid range
	if target_index >= slot_count:
		target_index = slot_count - 1
	if target_index < 0:
		target_index = 0

	# Find the main button in the target slot
	if target_index < slot_count:
		var slot_container := _slot_list_container.get_child(target_index)
		if slot_container is HBoxContainer:
			var main_button: Button = slot_container.get_node_or_null("MainButton") as Button
			if main_button != null and not main_button.disabled and main_button.is_inside_tree():
				main_button.grab_focus()
				return

	# Fallback: focus first available button
	for container in _slot_list_container.get_children():
		if container is HBoxContainer:
			var main_button: Button = container.get_node_or_null("MainButton") as Button
			if main_button != null and not main_button.disabled and main_button.is_inside_tree():
				main_button.grab_focus()
				return

func _on_slot_item_pressed(slot_id: StringName, exists: bool) -> void:
	if _mode == StringName("save"):
		if exists:
			# Show overwrite confirmation
			_show_confirmation(
				"Overwrite existing save?",
				{"action": "save", "slot_id": slot_id}
			)
		else:
			# Save directly to empty slot
			_perform_save(slot_id)
	elif _mode == StringName("load"):
		if exists:
			# Load from slot
			_perform_load(slot_id)
		# Empty slots are disabled in load mode, so this shouldn't happen

func _on_delete_button_pressed(slot_id: StringName) -> void:
	# Show delete confirmation
	_show_confirmation(
		"Delete this save file?",
		{"action": "delete", "slot_id": slot_id}
	)

func _show_confirmation(message: String, action_data: Dictionary) -> void:
	if _confirmation_dialog == null:
		return

	_pending_action = action_data
	_confirmation_dialog.dialog_text = message
	_confirmation_dialog.popup_centered()

func _on_confirmation_ok() -> void:
	var action: String = _pending_action.get("action", "")
	var slot_id: StringName = _pending_action.get("slot_id", StringName(""))

	match action:
		"save":
			_perform_save(slot_id)
		"delete":
			_perform_delete(slot_id)

	_pending_action = {}

func _on_confirmation_cancel() -> void:
	_pending_action = {}

func _perform_save(slot_id: StringName) -> void:
	if _save_manager == null:
		push_error("UI_SaveLoadMenu: Cannot save, M_SaveManager not found")
		return

	var result: Error = _save_manager.save_to_slot(slot_id)

	if result != OK:
		push_warning("UI_SaveLoadMenu: Save failed with error code %d" % result)
		# TODO: Show error toast or inline message
	else:
		# Refresh UI to show updated metadata
		call_deferred("_refresh_slot_list")

func _perform_load(slot_id: StringName) -> void:
	if _save_manager == null:
		push_error("UI_SaveLoadMenu: Cannot load, M_SaveManager not found")
		return

	# Close the save/load menu immediately
	# M_SceneManager's loading screen will take over
	var store := get_store()
	if store != null:
		store.dispatch(U_NavigationActions.close_top_overlay())

	# Perform the load (scene transition + loading screen handled by M_SceneManager)
	var result: Error = _save_manager.load_from_slot(slot_id)

	if result != OK:
		push_warning("UI_SaveLoadMenu: Load failed with error code %d" % result)
		# TODO: Show error toast in gameplay (overlay already closed)

func _perform_delete(slot_id: StringName) -> void:
	if _save_manager == null:
		push_error("UI_SaveLoadMenu: Cannot delete, M_SaveManager not found")
		return

	var result: Error = _save_manager.delete_slot(slot_id)

	if result != OK:
		push_warning("UI_SaveLoadMenu: Delete failed with error code %d" % result)
		# TODO: Show error toast or inline message
	else:
		# Refresh UI to remove deleted slot
		_refresh_slot_list()

## Event handlers for save events

func _on_save_started(_event: Dictionary) -> void:
	# Save started - could show a brief "Saving..." indicator
	pass

func _on_save_completed(_event: Dictionary) -> void:
	# Save completed - refresh slot list to show updated metadata
	call_deferred("_refresh_slot_list")

func _on_save_failed(_event: Dictionary) -> void:
	# Save failed - could show error message
	var payload: Dictionary = _event.get("payload", {})
	var error_code: int = payload.get("error_code", 0)
	push_warning("UI_SaveLoadMenu: Save failed with error code %d" % error_code)

## Event handlers for load events

func _on_load_started(_event: Dictionary) -> void:
	# Load started - show spinner and disable all buttons
	_show_loading_spinner()
	_set_buttons_enabled(false)

func _on_load_completed(_event: Dictionary) -> void:
	# Load completed - hide spinner and re-enable buttons
	_hide_loading_spinner()
	_set_buttons_enabled(true)

func _on_load_failed(_event: Dictionary) -> void:
	# Load failed - hide spinner and re-enable buttons
	_hide_loading_spinner()
	_set_buttons_enabled(true)

	var payload: Dictionary = _event.get("payload", {})
	var error_code: int = payload.get("error_code", 0)
	push_warning("UI_SaveLoadMenu: Load failed with error code %d" % error_code)

## Helper methods for spinner and button state

func _show_loading_spinner() -> void:
	if _loading_spinner != null:
		_loading_spinner.visible = true

func _hide_loading_spinner() -> void:
	if _loading_spinner != null:
		_loading_spinner.visible = false

func _set_buttons_enabled(enabled: bool) -> void:
	# Disable/enable back button
	if _back_button != null:
		_back_button.disabled = not enabled

	# Disable/enable all slot buttons
	if _slot_list_container != null:
		for container in _slot_list_container.get_children():
			if container is HBoxContainer:
				var main_button := container.get_node_or_null("MainButton") as Button
				if main_button != null:
					main_button.disabled = not enabled

				var delete_button := container.get_node_or_null("DeleteButton") as Button
				if delete_button != null:
					delete_button.disabled = not enabled

func _on_panel_ready() -> void:
	_connect_buttons()
	_read_mode_from_state()

func _connect_buttons() -> void:
	if _back_button != null and not _back_button.pressed.is_connected(_on_back_pressed_button):
		_back_button.pressed.connect(_on_back_pressed_button)

	if _confirmation_dialog != null:
		if not _confirmation_dialog.confirmed.is_connected(_on_confirmation_ok):
			_confirmation_dialog.confirmed.connect(_on_confirmation_ok)
		if not _confirmation_dialog.canceled.is_connected(_on_confirmation_cancel):
			_confirmation_dialog.canceled.connect(_on_confirmation_cancel)

func _on_back_pressed_button() -> void:
	_on_back_pressed()

func _on_back_pressed() -> void:
	# Close this overlay and return to pause menu
	var store := get_store()
	if store != null:
		store.dispatch(U_NavigationActions.close_top_overlay())
