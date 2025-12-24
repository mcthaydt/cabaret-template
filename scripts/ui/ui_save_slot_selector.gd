@icon("res://resources/editor_icons/utility.svg")
extends "res://scripts/ui/base/base_overlay.gd"
class_name UI_SaveSlotSelector

## Save Slot Selector Overlay - Multi-slot save/load UI
##
## Provides UI for saving/loading game state across 4 slots (Autosave + 3 manual).
## Implements two-tier focus navigation and bug prevention strategies from LESSONS_LEARNED.md.

const U_SaveActions := preload("res://scripts/state/actions/u_save_actions.gd")
const U_SaveSelectors := preload("res://scripts/state/selectors/u_save_selectors.gd")
const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")
const RS_SaveSlotMetadata := preload("res://scripts/state/resources/rs_save_slot_metadata.gd")
const U_SaveManager := preload("res://scripts/state/utils/u_save_manager.gd")

enum Mode {
	SAVE = 0,  ## User saving their game
	LOAD = 1   ## User loading a save
}

# Scene references - UI elements
@onready var _title_label: Label = %TitleLabel
@onready var _autosave_slot: Button = %AutosaveSlot
@onready var _slot_1: Button = %Slot1
@onready var _slot_2: Button = %Slot2
@onready var _slot_3: Button = %Slot3
@onready var _screenshot_preview: TextureRect = %ScreenshotPreview
@onready var _empty_slot_label: Label = %EmptySlotLabel
@onready var _scene_label: Label = %SceneLabel
@onready var _timestamp_label: Label = %TimestampLabel
@onready var _play_time_label: Label = %PlayTimeLabel
@onready var _health_label: Label = %HealthLabel
@onready var _death_count_label: Label = %DeathCountLabel
@onready var _action_button_1: Button = %ActionButton1
@onready var _delete_button: Button = %DeleteButton
@onready var _back_button: Button = %BackButton
@onready var _save_confirm_dialog: ConfirmationDialog = %SaveConfirmDialog
@onready var _delete_confirm_dialog: ConfirmationDialog = %DeleteConfirmDialog
@onready var _error_dialog: AcceptDialog = %ErrorDialog

# State
var _mode: Mode = Mode.LOAD
var _slot_metadata: Array[RS_SaveSlotMetadata] = []
var _selected_slot_index: int = 0
var _was_saving: bool = false
var _was_deleting: bool = false
var _screenshot_cache: Dictionary = {}  # slot_index -> ImageTexture


# ==============================================================================
# Lifecycle Methods
# ==============================================================================

func _ready() -> void:
	await super._ready()

	# Check store availability
	if get_store() == null:
		push_error("UI_SaveSlotSelector: No store available, cannot function")
		_show_error("Internal error: State store unavailable")
		return

	# Initialize UI
	_load_mode_from_state()
	_load_slot_metadata()
	_update_ui_for_mode()
	_update_slot_displays()
	_configure_focus_neighbors()
	_connect_button_signals()
	_connect_dialog_signals()
	_subscribe_to_state_updates()


func _on_panel_ready() -> void:
	# Hook from BasePanel - already handled in _ready()
	pass

func _apply_initial_focus() -> void:
	await _apply_initial_slot_focus()


func _input(event: InputEvent) -> void:
	var direction := StringName()

	if event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		if not button.pressed:
			return
		if button.is_action_pressed("ui_up"):
			direction = StringName("ui_up")
		elif button.is_action_pressed("ui_down"):
			direction = StringName("ui_down")
		elif button.is_action_pressed("ui_left"):
			direction = StringName("ui_left")
		elif button.is_action_pressed("ui_right"):
			direction = StringName("ui_right")
	elif event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed:
			return
		if key.is_action_pressed("ui_up"):
			direction = StringName("ui_up")
		elif key.is_action_pressed("ui_down"):
			direction = StringName("ui_down")
		elif key.is_action_pressed("ui_left"):
			direction = StringName("ui_left")
		elif key.is_action_pressed("ui_right"):
			direction = StringName("ui_right")

	if direction != StringName():
		_navigate_focus(direction)
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()

func _navigate_focus(direction: StringName) -> void:
	var viewport := get_viewport()
	var focused := viewport.gui_get_focus_owner() if viewport != null else null
	if focused == null:
		return
	if not is_ancestor_of(focused):
		return

	var slots: Array[Button] = [_slot_1, _slot_2, _slot_3, _autosave_slot]
	var actions: Array[Button] = [_action_button_1, _delete_button, _back_button]

	var slot_index := slots.find(focused)
	if slot_index != -1:
		_navigate_slots(direction, slot_index, slots, actions)
		return

	var action_index := actions.find(focused)
	if action_index != -1:
		_navigate_actions(direction, action_index, slots, actions)
		return

	super._navigate_focus(direction)

func _navigate_slots(direction: StringName, slot_index: int, slots: Array[Button], actions: Array[Button]) -> void:
	match direction:
		"ui_up":
			var prev_slot := _find_focusable_slot(slots, slot_index - 1, -1)
			if prev_slot != null:
				prev_slot.grab_focus()
		"ui_down":
			var next_slot := _find_focusable_slot(slots, slot_index + 1, 1)
			if next_slot != null:
				next_slot.grab_focus()
			else:
				_focus_first_action(actions)
		"ui_left", "ui_right":
			pass

func _navigate_actions(direction: StringName, action_index: int, slots: Array[Button], actions: Array[Button]) -> void:
	match direction:
		"ui_left":
			if action_index > 0:
				actions[action_index - 1].grab_focus()
		"ui_right":
			if action_index < actions.size() - 1:
				actions[action_index + 1].grab_focus()
		"ui_up":
			var last_slot := _find_focusable_slot(slots, slots.size() - 1, -1)
			if last_slot != null:
				last_slot.grab_focus()
		"ui_down":
			pass

func _find_focusable_slot(slots: Array[Button], start_index: int, step: int) -> Button:
	var i := start_index
	while i >= 0 and i < slots.size():
		var slot := slots[i]
		if _is_focusable_slot(slot):
			return slot
		i += step
	return null

func _focus_first_action(actions: Array[Button]) -> void:
	for action_button in actions:
		if _is_focusable_action(action_button):
			action_button.grab_focus()
			return

func _is_focusable_slot(slot: Button) -> bool:
	if slot == null:
		return false
	if slot.disabled:
		return false
	return slot.is_visible_in_tree()

func _is_focusable_action(action_button: Button) -> bool:
	if action_button == null:
		return false
	if action_button.disabled:
		return false
	return action_button.is_visible_in_tree()


func _on_back_pressed() -> void:
	var store := get_store()
	if store == null:
		return
	store.dispatch(U_NavigationActions.close_top_overlay())


func _exit_tree() -> void:
	var store := get_store()
	if store != null and store.slice_updated.is_connected(_on_slice_updated):
		store.slice_updated.disconnect(_on_slice_updated)


# ==============================================================================
# Initialization Methods
# ==============================================================================

func _load_mode_from_state() -> void:
	var store := get_store()
	if store == null:
		push_warning("UI_SaveSlotSelector: Store not ready, defaulting to LOAD mode")
		_mode = Mode.LOAD
		return

	var save_state: Dictionary = store.get_slice(StringName("save"))
	var mode_value: int = save_state.get("current_mode", Mode.LOAD)
	_mode = mode_value as Mode


func _load_slot_metadata() -> void:
	# Get all slots from U_SaveManager - already in order [Slot1, Slot2, Slot3, Autosave]
	_slot_metadata = U_SaveManager.get_all_slots()
	if _slot_metadata.size() != 4:
		push_error("UI_SaveSlotSelector: Expected 4 slots, got %d" % _slot_metadata.size())


func _update_ui_for_mode() -> void:
	match _mode:
		Mode.SAVE:
			_title_label.text = "Save Game"
			_autosave_slot.disabled = true
			_autosave_slot.tooltip_text = "Autosave is automatic"
			_action_button_1.text = "Save"
		Mode.LOAD:
			_title_label.text = "Load Game"
			_autosave_slot.disabled = false
			_autosave_slot.tooltip_text = ""
			_action_button_1.text = "Load"


func _configure_focus_neighbors() -> void:
	# Custom navigation handles focus traversal; only wire focus_entered for previews.
	var slots: Array[Button] = [_slot_1, _slot_2, _slot_3, _autosave_slot]
	for i in range(slots.size()):
		var slot := slots[i]
		if slot == null:
			continue
		if slot.focus_entered.is_connected(_on_slot_focused):
			continue
		slot.focus_entered.connect(_on_slot_focused.bind(i))

func _sort_slots_by_id(a: RS_SaveSlotMetadata, b: RS_SaveSlotMetadata) -> bool:
	return a.slot_id < b.slot_id


func _connect_button_signals() -> void:
	# Slot buttons - order is [Slot1, Slot2, Slot3, Autosave] matching _slot_metadata
	if not _slot_1.pressed.is_connected(_on_slot_pressed):
		_slot_1.pressed.connect(_on_slot_pressed.bind(0))
	if not _slot_2.pressed.is_connected(_on_slot_pressed):
		_slot_2.pressed.connect(_on_slot_pressed.bind(1))
	if not _slot_3.pressed.is_connected(_on_slot_pressed):
		_slot_3.pressed.connect(_on_slot_pressed.bind(2))
	if not _autosave_slot.pressed.is_connected(_on_slot_pressed):
		_autosave_slot.pressed.connect(_on_slot_pressed.bind(3))

	# Action buttons
	if not _action_button_1.pressed.is_connected(_on_action_button_pressed):
		_action_button_1.pressed.connect(_on_action_button_pressed)
	if not _delete_button.pressed.is_connected(_on_delete_pressed):
		_delete_button.pressed.connect(_on_delete_pressed)
	if not _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.connect(_on_back_pressed)


func _connect_dialog_signals() -> void:
	if not _save_confirm_dialog.confirmed.is_connected(_on_save_confirmed):
		_save_confirm_dialog.confirmed.connect(_on_save_confirmed)
	if not _save_confirm_dialog.canceled.is_connected(_on_save_canceled):
		_save_confirm_dialog.canceled.connect(_on_save_canceled)

	if not _delete_confirm_dialog.confirmed.is_connected(_on_delete_confirmed):
		_delete_confirm_dialog.confirmed.connect(_on_delete_confirmed)
	if not _delete_confirm_dialog.canceled.is_connected(_on_delete_canceled):
		_delete_confirm_dialog.canceled.connect(_on_delete_canceled)

	if not _error_dialog.confirmed.is_connected(_on_error_dismissed):
		_error_dialog.confirmed.connect(_on_error_dismissed)


func _subscribe_to_state_updates() -> void:
	var store := get_store()
	if store == null:
		return

	if not store.slice_updated.is_connected(_on_slice_updated):
		store.slice_updated.connect(_on_slice_updated)


func _apply_initial_slot_focus() -> void:
	# Focus first available slot
	await get_tree().process_frame
	var viewport := get_viewport()
	var focused := viewport.gui_get_focus_owner() if viewport != null else null
	if focused != null and is_ancestor_of(focused):
		return

	# Try slots in order, using _is_focusable_slot to skip hidden/disabled slots
	var slots: Array[Button] = [_slot_1, _slot_2, _slot_3, _autosave_slot]
	for slot in slots:
		if _is_focusable_slot(slot):
			slot.grab_focus()
			return


# ==============================================================================
# Slot Display Methods
# ==============================================================================

func _update_slot_displays() -> void:
	var buttons: Array[Button] = [_slot_1, _slot_2, _slot_3, _autosave_slot]

	for i in range(buttons.size()):
		var button := buttons[i]
		var metadata: RS_SaveSlotMetadata = _slot_metadata[i] if i < _slot_metadata.size() else null

		if metadata == null or metadata.is_empty:
			_set_empty_slot_display(button, i)
		else:
			_set_populated_slot_display(button, metadata)


func _set_empty_slot_display(button: Button, slot_index: int) -> void:
	# slot_index 3 is autosave (maps to slot_id 4)
	var slot_name := "Autosave" if slot_index == 3 else "Slot %d" % (slot_index + 1)
	button.text = "%s\n[Empty]" % slot_name


func _set_populated_slot_display(button: Button, metadata: RS_SaveSlotMetadata) -> void:
	var slot_name := "Autosave" if metadata.slot_type == RS_SaveSlotMetadata.SlotType.AUTO else "Slot %d" % metadata.slot_id

	# Multi-line format for slot button
	var display_text := "%s\n%s\n%s" % [
		slot_name,
		metadata.scene_name,
		metadata.formatted_timestamp
	]
	button.text = display_text


func _on_slot_focused(slot_index: int) -> void:
	_selected_slot_index = slot_index
	_update_preview_panel(slot_index)


func _update_preview_panel(slot_index: int) -> void:
	var metadata: RS_SaveSlotMetadata = _slot_metadata[slot_index] if slot_index < _slot_metadata.size() else null

	if metadata == null or metadata.is_empty:
		_show_empty_preview()
	else:
		_show_slot_preview(metadata)


# ==============================================================================
# Screenshot & Preview Methods
# ==============================================================================

func _show_slot_preview(metadata: RS_SaveSlotMetadata) -> void:
	# Update screenshot
	if metadata.screenshot_data.size() > 0:
		_load_screenshot(metadata.slot_id, metadata.screenshot_data)
	else:
		_show_empty_screenshot()

	# Update metadata labels
	_scene_label.text = "Scene: %s" % metadata.scene_name
	_timestamp_label.text = "Saved: %s" % metadata.formatted_timestamp
	_play_time_label.text = "Play Time: %s" % _format_play_time(metadata.play_time_seconds)
	_health_label.text = "Health: %.0f / %.0f" % [metadata.player_health, metadata.player_max_health]
	_death_count_label.text = "Deaths: %d" % metadata.death_count


func _show_empty_preview() -> void:
	_show_empty_screenshot()
	_scene_label.text = "Scene: ---"
	_timestamp_label.text = "Saved: ---"
	_play_time_label.text = "Play Time: ---"
	_health_label.text = "Health: ---"
	_death_count_label.text = "Deaths: ---"


func _load_screenshot(slot_index: int, screenshot_data: PackedByteArray) -> void:
	# Check cache first (Bug #2 Prevention - performance optimization)
	if _screenshot_cache.has(slot_index):
		_screenshot_preview.texture = _screenshot_cache[slot_index]
		_empty_slot_label.visible = false
		return

	# Load and cache
	if screenshot_data.size() == 0:
		_show_empty_screenshot()
		return

	var img := Image.new()
	var err := img.load_png_from_buffer(screenshot_data)

	if err != OK:
		push_warning("UI_SaveSlotSelector: Failed to load screenshot PNG for slot %d: %s" % [slot_index, error_string(err)])
		_show_empty_screenshot()
		return

	var texture := ImageTexture.create_from_image(img)
	_screenshot_cache[slot_index] = texture
	_screenshot_preview.texture = texture
	_empty_slot_label.visible = false


func _show_empty_screenshot() -> void:
	_screenshot_preview.texture = null
	_empty_slot_label.visible = true


func _format_play_time(seconds: float) -> String:
	var hours: int = int(seconds) / 3600
	var minutes: int = (int(seconds) % 3600) / 60
	var secs: int = int(seconds) % 60
	return "%02d:%02d:%02d" % [hours, minutes, secs]


# ==============================================================================
# Event Handlers - Slot Selection
# ==============================================================================

func _on_slot_pressed(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _slot_metadata.size():
		push_error("UI_SaveSlotSelector: Invalid slot index %d" % slot_index)
		return

	_selected_slot_index = slot_index
	var metadata := _slot_metadata[slot_index]

	match _mode:
		Mode.SAVE:
			_handle_save_request(metadata)
		Mode.LOAD:
			_handle_load_request(metadata)


func _on_action_button_pressed() -> void:
	# Action button 1 triggers same action as pressing a slot
	_on_slot_pressed(_selected_slot_index)


# ==============================================================================
# Event Handlers - Save Flow
# ==============================================================================

func _handle_save_request(metadata: RS_SaveSlotMetadata) -> void:
	# Check if busy
	var store := get_store()
	if store != null:
		var save_state := store.get_slice(StringName("save"))
		if save_state.get("is_saving", false) or save_state.get("is_deleting", false):
			_show_error("An operation is already in progress.")
			return

	# Show confirmation if slot is occupied
	if not metadata.is_empty:
		_show_save_confirmation()
	else:
		_perform_save()


func _show_save_confirmation() -> void:
	_save_confirm_dialog.dialog_text = "Overwrite this save slot?"
	_save_confirm_dialog.popup_centered()


func _on_save_confirmed() -> void:
	_perform_save()


func _on_save_canceled() -> void:
	_refocus_selected_slot()


func _perform_save() -> void:
	var store := get_store()
	if store == null:
		return

	# Get actual slot_id from metadata
	var metadata := _slot_metadata[_selected_slot_index] if _selected_slot_index < _slot_metadata.size() else null
	if metadata == null:
		return

	# Close overlay (save happens in background via reducer side effect)
	store.dispatch(U_NavigationActions.close_top_overlay())

	# Dispatch save action with actual slot_id
	store.dispatch(U_SaveActions.save_started(metadata.slot_id))


# ==============================================================================
# Event Handlers - Load Flow (Bug #6 Prevention)
# ==============================================================================

func _handle_load_request(metadata: RS_SaveSlotMetadata) -> void:
	# Don't show confirmation for load (per requirements)
	if metadata.is_empty:
		_show_error("Cannot load from an empty slot.")
		return

	_perform_load()


func _perform_load() -> void:
	var store := get_store()
	if store == null:
		return

	# Get actual slot_id from metadata
	var metadata := _slot_metadata[_selected_slot_index] if _selected_slot_index < _slot_metadata.size() else null
	if metadata == null:
		return

	# Dispatch load action with actual slot_id
	# Note: M_StateStore load flow handles closing overlays (Bug #6 prevention)
	store.dispatch(U_SaveActions.load_started(metadata.slot_id))


# ==============================================================================
# Event Handlers - Delete Flow
# ==============================================================================

func _on_delete_pressed() -> void:
	if _selected_slot_index < 0 or _selected_slot_index >= _slot_metadata.size():
		_show_error("No slot selected.")
		return

	# Prevent deleting autosave (index 3 = autosave slot)
	if _selected_slot_index == 3:
		_show_error("Cannot delete autosave slot.")
		return

	var metadata := _slot_metadata[_selected_slot_index]
	if metadata.is_empty:
		_show_error("Cannot delete an empty slot.")
		return

	# Check if busy
	var store := get_store()
	if store != null:
		var save_state := store.get_slice(StringName("save"))
		if save_state.get("is_saving", false) or save_state.get("is_deleting", false):
			_show_error("An operation is already in progress.")
			return

	# Show confirmation
	_show_delete_confirmation()


func _show_delete_confirmation() -> void:
	_delete_confirm_dialog.dialog_text = "Delete this save slot?\n\nThis cannot be undone."
	_delete_confirm_dialog.popup_centered()


func _on_delete_confirmed() -> void:
	_perform_delete()


func _on_delete_canceled() -> void:
	_refocus_selected_slot()


func _perform_delete() -> void:
	var store := get_store()
	if store == null:
		return

	# Get actual slot_id from metadata
	var metadata := _slot_metadata[_selected_slot_index] if _selected_slot_index < _slot_metadata.size() else null
	if metadata == null:
		return

	# Dispatch delete action with actual slot_id
	store.dispatch(U_SaveActions.delete_started(metadata.slot_id))

	# Reload metadata after delete completes (handled in _on_slice_updated)


# ==============================================================================
# Event Handlers - Error Dialog
# ==============================================================================

func _show_error(message: String) -> void:
	_error_dialog.dialog_text = message
	_error_dialog.popup_centered()


func _on_error_dismissed() -> void:
	_refocus_selected_slot()


func _refocus_selected_slot() -> void:
	var buttons: Array[Button] = [_slot_1, _slot_2, _slot_3, _autosave_slot]
	if _selected_slot_index >= 0 and _selected_slot_index < buttons.size():
		call_deferred("_deferred_refocus", buttons[_selected_slot_index])


func _deferred_refocus(button: Button) -> void:
	if button != null and button.is_inside_tree():
		button.grab_focus()


# ==============================================================================
# State Subscription
# ==============================================================================

func _on_slice_updated(slice_name: StringName, slice_state: Dictionary) -> void:
	if slice_name != StringName("save"):
		return

	_handle_save_state_change(slice_state)


func _handle_save_state_change(save_state: Dictionary) -> void:
	# Detect operation completion
	var operation_completed: bool = false

	var is_saving: bool = save_state.get("is_saving", false)
	var is_deleting: bool = save_state.get("is_deleting", false)

	if _was_saving and not is_saving:
		operation_completed = true
	if _was_deleting and not is_deleting:
		operation_completed = true

	# Track previous operation state
	_was_saving = is_saving
	_was_deleting = is_deleting

	# Reload metadata if operation completed
	if operation_completed:
		_reload_metadata()

	# Show errors if any
	var error: String = save_state.get("last_error", "")
	if not error.is_empty():
		_show_error(error)


func _reload_metadata() -> void:
	_screenshot_cache.clear()  # Clear cache
	_load_slot_metadata()
	_update_slot_displays()
	_update_preview_panel(_selected_slot_index)
