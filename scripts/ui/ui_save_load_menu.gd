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

## Current mode: "save" or "load"
var _mode: StringName = StringName("")

## Reference to M_SaveManager
var _save_manager: Node = null  # M_SaveManager

## Cached slot metadata
var _cached_metadata: Array[Dictionary] = []

## Loading state
var _is_loading: bool = false

## Confirmation dialog state
var _pending_action: Dictionary = {}  # {action: "save"|"delete", slot_id: StringName}

## UI References (set via @onready once scene is created)
@onready var _mode_label: Label = %ModeLabel
@onready var _slot_list_container: VBoxContainer = %SlotListContainer
@onready var _back_button: Button = %BackButton
@onready var _confirmation_dialog: ConfirmationDialog = %ConfirmationDialog
@onready var _loading_overlay: ColorRect = %LoadingOverlay
@onready var _loading_spinner: Control = %LoadingSpinner  # Could be AnimatedSprite2D or custom

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

func _exit_tree() -> void:
	# Unsubscribe from events
	U_ECSEventBus.unsubscribe(StringName("save_started"), _on_save_started)
	U_ECSEventBus.unsubscribe(StringName("save_completed"), _on_save_completed)
	U_ECSEventBus.unsubscribe(StringName("save_failed"), _on_save_failed)

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

	# Hide loading overlay
	_set_loading_state(false)

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

	# Get all slot metadata from M_SaveManager
	_cached_metadata = _save_manager.get_all_slot_metadata()

	# Clear existing slot items
	_clear_slot_list()

	# Create slot items
	for slot_meta in _cached_metadata:
		_create_slot_item(slot_meta)

	# Configure focus chain
	_configure_slot_focus()

func _clear_slot_list() -> void:
	if _slot_list_container == null:
		return

	for child in _slot_list_container.get_children():
		child.queue_free()

func _create_slot_item(slot_meta: Dictionary) -> void:
	# TODO: This will create UI_SaveSlotItem instances once that component is implemented
	# For now, create placeholder buttons
	var slot_id: StringName = slot_meta.get("slot_id", StringName(""))
	var exists: bool = slot_meta.get("exists", false)

	var item := Button.new()
	item.name = "Slot_" + str(slot_id)

	if exists:
		# Populated slot
		var timestamp: String = slot_meta.get("timestamp", "")
		var area_name: String = slot_meta.get("area_name", "Unknown")
		var playtime: int = slot_meta.get("playtime_seconds", 0)

		item.text = "%s - %s (%s)" % [slot_id, area_name, _format_playtime(playtime)]
	else:
		# Empty slot
		if _mode == StringName("save"):
			item.text = "%s - [New Save]" % slot_id
		else:
			item.text = "%s - [Empty]" % slot_id
			item.disabled = true  # Can't load empty slots

	# Connect button press
	item.pressed.connect(_on_slot_item_pressed.bind(slot_id, exists))

	_slot_list_container.add_child(item)

func _format_playtime(seconds: int) -> String:
	var hours: int = seconds / 3600
	var minutes: int = (seconds % 3600) / 60
	var secs: int = seconds % 60
	return "%02d:%02d:%02d" % [hours, minutes, secs]

func _configure_slot_focus() -> void:
	if _slot_list_container == null or _back_button == null:
		return

	var slot_buttons: Array[Control] = []
	for child in _slot_list_container.get_children():
		if child is Button and not child.disabled:
			slot_buttons.append(child as Control)

	if not slot_buttons.is_empty():
		slot_buttons.append(_back_button)
		U_FocusConfigurator.configure_vertical_focus(slot_buttons, true)

func _on_slot_item_pressed(slot_id: StringName, exists: bool) -> void:
	if _is_loading:
		return  # Ignore input during load

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

	# Show loading state
	_set_loading_state(true)

	var result: Error = _save_manager.load_from_slot(slot_id)

	if result != OK:
		push_warning("UI_SaveLoadMenu: Load failed with error code %d" % result)
		_set_loading_state(false)
		# TODO: Show error toast or inline message
	# If load succeeds, scene transition will close this overlay automatically

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

func _set_loading_state(loading: bool) -> void:
	_is_loading = loading

	if _loading_overlay != null:
		_loading_overlay.visible = loading

	if _loading_spinner != null:
		_loading_spinner.visible = loading

	# Disable all interactive elements during load
	if _slot_list_container != null:
		for child in _slot_list_container.get_children():
			if child is Button:
				child.disabled = loading

	if _back_button != null:
		_back_button.disabled = loading

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
