extends GutTest

## Integration tests for UI_SaveSlotSelector
##
## Tests full UI behavior with scene loading, Redux integration,
## and bug prevention patterns from LESSONS_LEARNED.md

const UI_SaveSlotSelector := preload("res://scripts/ui/ui_save_slot_selector.gd")
const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const U_SaveManager := preload("res://scripts/state/utils/u_save_manager.gd")
const U_SaveEnvelope := preload("res://scripts/state/utils/u_save_envelope.gd")
const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_SaveActions := preload("res://scripts/state/actions/u_save_actions.gd")
const RS_SaveSlotMetadata := preload("res://scripts/state/resources/rs_save_slot_metadata.gd")

var _store: M_StateStore
var _overlay: UI_SaveSlotSelector
var _dispatched_actions: Array[Dictionary] = []


## Test helper: Write metadata to disk for testing purposes
func _save_test_metadata(metadata: RS_SaveSlotMetadata) -> void:
	var path: String
	if metadata.slot_id == 0:
		path = U_SaveManager.get_auto_slot_path()
	else:
		path = U_SaveManager.get_manual_slot_path(metadata.slot_id)

	# Create minimal state for testing
	var test_state: Dictionary = {
		"scene": {"current_scene_id": metadata.scene_name},
		"gameplay": {
			"play_time_seconds": metadata.play_time_seconds,
			"player_health": metadata.player_health,
			"player_max_health": metadata.player_max_health,
			"death_count": metadata.death_count,
		}
	}

	U_SaveEnvelope.write_envelope(path, metadata, test_state)


func before_each() -> void:
	# Initialize state store
	_store = M_StateStore.new()
	add_child_autofree(_store)
	await get_tree().process_frame

	# Track dispatched actions
	_dispatched_actions.clear()
	_store.action_dispatched.connect(_on_action_dispatched)

	# Load and initialize overlay scene
	var scene: PackedScene = load("res://scenes/ui/ui_save_slot_selector.tscn")
	_overlay = scene.instantiate() as UI_SaveSlotSelector
	add_child_autofree(_overlay)
	await get_tree().process_frame


func after_each() -> void:
	# Clean up manual save slots (1-3)
	# Note: Slot 0 is autosave and cannot be deleted via delete_slot()
	for i in range(1, 4):
		U_SaveManager.delete_slot(i)

	# Manually delete autosave if it exists
	var autosave_path := U_SaveManager.get_auto_slot_path()
	if FileAccess.file_exists(autosave_path):
		DirAccess.remove_absolute(autosave_path)

	_overlay = null
	_store = null
	_dispatched_actions.clear()


func _on_action_dispatched(action: Dictionary) -> void:
	_dispatched_actions.append(action)


## Bug #8 Prevention: Mode detection from Redux state
func test_mode_load_shows_correct_ui() -> void:
	# Set mode to LOAD
	_store.dispatch(U_SaveActions.set_save_mode(UI_SaveSlotSelector.Mode.LOAD))
	await get_tree().process_frame

	# Reload overlay to pick up new mode
	_overlay._load_mode_from_state()
	_overlay._update_ui_for_mode()
	await get_tree().process_frame

	var title_label: Label = _overlay.get_node("%TitleLabel")
	var action_button: Button = _overlay.get_node("%ActionButton1")
	var autosave_slot: Button = _overlay.get_node("%AutosaveSlot")

	assert_eq(title_label.text, "Load Game", "Title should be 'Load Game' in LOAD mode")
	assert_eq(action_button.text, "Load", "Action button should say 'Load'")
	assert_false(autosave_slot.disabled, "Autosave slot should be enabled in LOAD mode")


## Bug #8 Prevention: Mode SAVE shows correct UI
func test_mode_save_shows_correct_ui() -> void:
	# Set mode to SAVE
	_store.dispatch(U_SaveActions.set_save_mode(UI_SaveSlotSelector.Mode.SAVE))
	await get_tree().process_frame

	# Reload overlay to pick up new mode
	_overlay._load_mode_from_state()
	_overlay._update_ui_for_mode()
	await get_tree().process_frame

	var title_label: Label = _overlay.get_node("%TitleLabel")
	var action_button: Button = _overlay.get_node("%ActionButton1")
	var autosave_slot: Button = _overlay.get_node("%AutosaveSlot")

	assert_eq(title_label.text, "Save Game", "Title should be 'Save Game' in SAVE mode")
	assert_eq(action_button.text, "Save", "Action button should say 'Save'")
	assert_true(autosave_slot.disabled, "Autosave slot should be disabled in SAVE mode")


## Bug #1 Prevention: Two-tier focus navigation - vertical slots
func test_focus_navigation_vertical_slots() -> void:
	var autosave: Button = _overlay.get_node("%AutosaveSlot")
	var slot_1: Button = _overlay.get_node("%Slot1")
	var slot_2: Button = _overlay.get_node("%Slot2")
	var slot_3: Button = _overlay.get_node("%Slot3")

	# Focus autosave slot
	autosave.grab_focus()
	await get_tree().process_frame
	assert_eq(_overlay.get_viewport().gui_get_focus_owner(), autosave, "Autosave should have focus")

	# Simulate down navigation
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_DPAD_DOWN
	event.pressed = true
	_overlay._input(event)
	await get_tree().process_frame

	# Should move to slot 1
	assert_eq(_overlay.get_viewport().gui_get_focus_owner(), slot_1, "Down from autosave should focus slot 1")

	# Continue down to slot 2
	_overlay._input(event)
	await get_tree().process_frame
	assert_eq(_overlay.get_viewport().gui_get_focus_owner(), slot_2, "Down from slot 1 should focus slot 2")

	# Continue down to slot 3
	_overlay._input(event)
	await get_tree().process_frame
	assert_eq(_overlay.get_viewport().gui_get_focus_owner(), slot_3, "Down from slot 2 should focus slot 3")


## Bug #1 Prevention: Two-tier focus navigation - no left/right on slots
func test_focus_navigation_no_horizontal_on_slots() -> void:
	var slot_1: Button = _overlay.get_node("%Slot1")

	# Focus slot 1
	slot_1.grab_focus()
	await get_tree().process_frame

	var initial_focus := _overlay.get_viewport().gui_get_focus_owner()

	# Try to navigate left (should do nothing)
	var event_left := InputEventJoypadButton.new()
	event_left.button_index = JOY_BUTTON_DPAD_LEFT
	event_left.pressed = true
	_overlay._input(event_left)
	await get_tree().process_frame

	assert_eq(_overlay.get_viewport().gui_get_focus_owner(), initial_focus, "Left navigation should not change focus on slots")

	# Try to navigate right (should do nothing)
	var event_right := InputEventJoypadButton.new()
	event_right.button_index = JOY_BUTTON_DPAD_RIGHT
	event_right.pressed = true
	_overlay._input(event_right)
	await get_tree().process_frame

	assert_eq(_overlay.get_viewport().gui_get_focus_owner(), initial_focus, "Right navigation should not change focus on slots")


## Bug #1 Prevention: Two-tier focus navigation - bridge to action buttons
func test_focus_navigation_bridge_to_actions() -> void:
	var slot_3: Button = _overlay.get_node("%Slot3")
	var action_button: Button = _overlay.get_node("%ActionButton1")

	# Focus slot 3
	slot_3.grab_focus()
	await get_tree().process_frame

	# Navigate down (should jump to action buttons)
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_DPAD_DOWN
	event.pressed = true
	_overlay._input(event)
	await get_tree().process_frame

	assert_eq(_overlay.get_viewport().gui_get_focus_owner(), action_button, "Down from slot 3 should focus first action button")


## Bug #1 Prevention: Two-tier focus navigation - horizontal action buttons
func test_focus_navigation_horizontal_actions() -> void:
	var action_button_1: Button = _overlay.get_node("%ActionButton1")
	var delete_button: Button = _overlay.get_node("%DeleteButton")
	var back_button: Button = _overlay.get_node("%BackButton")

	# Focus first action button
	action_button_1.grab_focus()
	await get_tree().process_frame

	# Navigate right to delete button
	var event_right := InputEventJoypadButton.new()
	event_right.button_index = JOY_BUTTON_DPAD_RIGHT
	event_right.pressed = true
	_overlay._input(event_right)
	await get_tree().process_frame

	assert_eq(_overlay.get_viewport().gui_get_focus_owner(), delete_button, "Right from action button should focus delete button")

	# Navigate right to back button
	_overlay._input(event_right)
	await get_tree().process_frame

	assert_eq(_overlay.get_viewport().gui_get_focus_owner(), back_button, "Right from delete button should focus back button")


## Bug #2 Prevention: Screenshot display for occupied slot
func test_screenshot_display_for_occupied_slot() -> void:
	# Create a mock screenshot (1x1 red pixel as PNG)
	var img := Image.create(256, 144, false, Image.FORMAT_RGB8)
	img.fill(Color.RED)
	var screenshot_data: PackedByteArray = img.save_png_to_buffer()

	# Create save with screenshot
	var metadata := RS_SaveSlotMetadata.new()
	metadata.slot_id =1
	metadata.is_empty = false
	metadata.scene_name = "Test Scene"
	metadata.screenshot_data = screenshot_data
	metadata.timestamp = Time.get_unix_time_from_system()
	metadata.play_time_seconds = 3661.0
	metadata.player_health = 75.0
	metadata.player_max_health = 100.0
	metadata.death_count = 5

	# Save to slot 1
	_save_test_metadata(metadata)

	# Reload overlay metadata
	_overlay._load_slot_metadata()
	_overlay._update_slot_displays()
	await get_tree().process_frame

	# Select slot 1
	_overlay._selected_slot_index = 1
	_overlay._show_slot_preview(_overlay._slot_metadata[1])
	await get_tree().process_frame

	# Verify screenshot loaded
	var screenshot_preview: TextureRect = _overlay.get_node("%ScreenshotPreview")
	var empty_label: Label = _overlay.get_node("%EmptySlotLabel")

	assert_not_null(screenshot_preview.texture, "Screenshot texture should be loaded")
	assert_false(empty_label.visible, "Empty slot label should be hidden when screenshot loaded")


## Bug #2 Prevention: Empty slot shows placeholder
func test_empty_slot_shows_placeholder() -> void:
	# Ensure slot 1 is empty
	U_SaveManager.delete_slot(1)

	# Reload overlay metadata
	_overlay._load_slot_metadata()
	_overlay._update_slot_displays()
	await get_tree().process_frame

	# Select empty slot
	_overlay._selected_slot_index = 1
	_overlay._show_slot_preview(_overlay._slot_metadata[1])
	await get_tree().process_frame

	# Verify placeholder shown
	var screenshot_preview: TextureRect = _overlay.get_node("%ScreenshotPreview")
	var empty_label: Label = _overlay.get_node("%EmptySlotLabel")

	assert_null(screenshot_preview.texture, "Screenshot texture should be null for empty slot")
	assert_true(empty_label.visible, "Empty slot label should be visible")


## Bug #6 Prevention: Load flow dispatches close before load
func test_load_flow_closes_overlay_before_load_action() -> void:
	# Create a save in slot 1
	var metadata := RS_SaveSlotMetadata.new()
	metadata.slot_id =1
	metadata.is_empty = false
	metadata.scene_name = "Test Scene"
	_save_test_metadata(metadata)

	# Set mode to LOAD
	_store.dispatch(U_SaveActions.set_save_mode(UI_SaveSlotSelector.Mode.LOAD))
	_overlay._load_mode_from_state()
	await get_tree().process_frame

	# Reload metadata
	_overlay._load_slot_metadata()
	_overlay._selected_slot_index = 1

	# Clear action history
	_dispatched_actions.clear()

	# Perform load
	_overlay._perform_load()
	await get_tree().process_frame
	await get_tree().process_frame  # Wait for action dispatch after close

	# Verify action dispatch order
	assert_true(_dispatched_actions.size() >= 2, "Should dispatch at least 2 actions (close + load)")

	# First action should be close_top_overlay
	var first_action := _dispatched_actions[0]
	assert_eq(first_action.get("type"), U_NavigationActions.ACTION_CLOSE_TOP_OVERLAY, "First action should close overlay")

	# Second action should be load_started
	var second_action := _dispatched_actions[1]
	assert_eq(second_action.get("type"), U_SaveActions.ACTION_LOAD_STARTED, "Second action should start load")
	assert_eq(second_action.get("slot_index"), 1, "Load action should target slot 1")


## Empty slot handling: Cannot load empty slot
func test_cannot_load_empty_slot() -> void:
	# Ensure slot 1 is empty
	U_SaveManager.delete_slot(1)

	# Set mode to LOAD
	_store.dispatch(U_SaveActions.set_save_mode(UI_SaveSlotSelector.Mode.LOAD))
	_overlay._load_mode_from_state()
	_overlay._load_slot_metadata()
	await get_tree().process_frame

	# Try to load empty slot
	_overlay._selected_slot_index = 1
	_overlay._on_action_button_pressed()
	await get_tree().process_frame

	# Verify error dialog shown
	var error_dialog: AcceptDialog = _overlay.get_node("%ErrorDialog")
	assert_true(error_dialog.visible, "Error dialog should be shown when loading empty slot")
	assert_string_contains(error_dialog.dialog_text, "empty", "Error message should mention empty slot")


## Empty slot handling: Cannot delete empty slot
func test_cannot_delete_empty_slot() -> void:
	# Ensure slot 1 is empty
	U_SaveManager.delete_slot(1)

	# Reload metadata
	_overlay._load_slot_metadata()
	await get_tree().process_frame

	# Try to delete empty slot
	_overlay._selected_slot_index = 1
	_overlay._on_delete_pressed()
	await get_tree().process_frame

	# Verify error dialog shown
	var error_dialog: AcceptDialog = _overlay.get_node("%ErrorDialog")
	assert_true(error_dialog.visible, "Error dialog should be shown when deleting empty slot")
	assert_string_contains(error_dialog.dialog_text, "empty", "Error message should mention empty slot")


## Empty slot handling: Cannot delete autosave
func test_cannot_delete_autosave() -> void:
	# Create autosave
	var metadata := RS_SaveSlotMetadata.new()
	metadata.slot_id =0
	metadata.is_empty = false
	metadata.scene_name = "Autosave Test"
	_save_test_metadata(metadata)

	# Reload metadata
	_overlay._load_slot_metadata()
	await get_tree().process_frame

	# Try to delete autosave
	_overlay._selected_slot_index = 0
	_overlay._on_delete_pressed()
	await get_tree().process_frame

	# Verify error dialog shown
	var error_dialog: AcceptDialog = _overlay.get_node("%ErrorDialog")
	assert_true(error_dialog.visible, "Error dialog should be shown when deleting autosave")
	assert_string_contains(error_dialog.dialog_text, "autosave", "Error message should mention autosave")


## Save confirmation: Overwriting occupied slot shows confirmation
func test_save_overwrite_shows_confirmation() -> void:
	# Create save in slot 1
	var metadata := RS_SaveSlotMetadata.new()
	metadata.slot_id =1
	metadata.is_empty = false
	metadata.scene_name = "Existing Save"
	_save_test_metadata(metadata)

	# Set mode to SAVE
	_store.dispatch(U_SaveActions.set_save_mode(UI_SaveSlotSelector.Mode.SAVE))
	_overlay._load_mode_from_state()
	_overlay._load_slot_metadata()
	await get_tree().process_frame

	# Try to save to occupied slot
	_overlay._selected_slot_index = 1
	_overlay._on_action_button_pressed()
	await get_tree().process_frame

	# Verify confirmation dialog shown
	var save_confirm_dialog: ConfirmationDialog = _overlay.get_node("%SaveConfirmDialog")
	assert_true(save_confirm_dialog.visible, "Save confirmation dialog should be shown")
	assert_string_contains(save_confirm_dialog.dialog_text, "Overwrite", "Confirmation should mention overwrite")


## Save confirmation: Saving to empty slot does not show confirmation
func test_save_to_empty_slot_no_confirmation() -> void:
	# Ensure slot 1 is empty
	U_SaveManager.delete_slot(1)

	# Set mode to SAVE
	_store.dispatch(U_SaveActions.set_save_mode(UI_SaveSlotSelector.Mode.SAVE))
	_overlay._load_mode_from_state()
	_overlay._load_slot_metadata()
	await get_tree().process_frame

	# Clear action history
	_dispatched_actions.clear()

	# Try to save to empty slot
	_overlay._selected_slot_index = 1
	_overlay._on_action_button_pressed()
	await get_tree().process_frame
	await get_tree().process_frame

	# Verify save action dispatched without confirmation
	var save_confirm_dialog: ConfirmationDialog = _overlay.get_node("%SaveConfirmDialog")
	assert_false(save_confirm_dialog.visible, "Save confirmation should not be shown for empty slot")

	# Verify save_started action dispatched
	var save_action_found := false
	for action in _dispatched_actions:
		if action.get("type") == U_SaveActions.ACTION_SAVE_STARTED:
			save_action_found = true
			break

	assert_true(save_action_found, "Save action should be dispatched for empty slot")


## Save confirmation: Confirming save dispatches save action
func test_save_confirmation_confirmed_dispatches_save() -> void:
	# Create save in slot 1
	var metadata := RS_SaveSlotMetadata.new()
	metadata.slot_id =1
	metadata.is_empty = false
	_save_test_metadata(metadata)

	# Set mode to SAVE
	_store.dispatch(U_SaveActions.set_save_mode(UI_SaveSlotSelector.Mode.SAVE))
	_overlay._load_mode_from_state()
	_overlay._load_slot_metadata()
	await get_tree().process_frame

	# Show confirmation
	_overlay._selected_slot_index = 1
	_overlay._on_action_button_pressed()
	await get_tree().process_frame

	# Clear action history
	_dispatched_actions.clear()

	# Confirm save
	var save_confirm_dialog: ConfirmationDialog = _overlay.get_node("%SaveConfirmDialog")
	save_confirm_dialog.emit_signal("confirmed")
	await get_tree().process_frame
	await get_tree().process_frame

	# Verify save_started action dispatched
	var save_action_found := false
	for action in _dispatched_actions:
		if action.get("type") == U_SaveActions.ACTION_SAVE_STARTED:
			save_action_found = true
			assert_eq(action.get("slot_index"), 1, "Save should target slot 1")
			break

	assert_true(save_action_found, "Save action should be dispatched after confirmation")


## Delete confirmation: Deleting occupied slot shows confirmation
func test_delete_shows_confirmation() -> void:
	# Create save in slot 2
	var metadata := RS_SaveSlotMetadata.new()
	metadata.slot_id =2
	metadata.is_empty = false
	metadata.scene_name = "Test Save"
	_save_test_metadata(metadata)

	# Reload metadata
	_overlay._load_slot_metadata()
	await get_tree().process_frame

	# Try to delete
	_overlay._selected_slot_index = 2
	_overlay._on_delete_pressed()
	await get_tree().process_frame

	# Verify confirmation shown
	var delete_confirm_dialog: ConfirmationDialog = _overlay.get_node("%DeleteConfirmDialog")
	assert_true(delete_confirm_dialog.visible, "Delete confirmation dialog should be shown")
	assert_string_contains(delete_confirm_dialog.dialog_text, "Delete", "Confirmation should mention delete")


## Delete confirmation: Confirming delete dispatches delete action
func test_delete_confirmation_confirmed_dispatches_delete() -> void:
	# Create save in slot 2
	var metadata := RS_SaveSlotMetadata.new()
	metadata.slot_id =2
	metadata.is_empty = false
	_save_test_metadata(metadata)

	# Reload metadata
	_overlay._load_slot_metadata()
	await get_tree().process_frame

	# Show confirmation
	_overlay._selected_slot_index = 2
	_overlay._on_delete_pressed()
	await get_tree().process_frame

	# Clear action history
	_dispatched_actions.clear()

	# Confirm delete
	var delete_confirm_dialog: ConfirmationDialog = _overlay.get_node("%DeleteConfirmDialog")
	delete_confirm_dialog.emit_signal("confirmed")
	await get_tree().process_frame

	# Verify delete_started action dispatched
	var delete_action_found := false
	for action in _dispatched_actions:
		if action.get("type") == U_SaveActions.ACTION_DELETE_STARTED:
			delete_action_found = true
			assert_eq(action.get("slot_index"), 2, "Delete should target slot 2")
			break

	assert_true(delete_action_found, "Delete action should be dispatched after confirmation")


## Screenshot caching: Loading same slot twice uses cache
func test_screenshot_caching_performance() -> void:
	# Create a save with screenshot
	var img := Image.create(256, 144, false, Image.FORMAT_RGB8)
	img.fill(Color.BLUE)
	var screenshot_data: PackedByteArray = img.save_png_to_buffer()

	var metadata := RS_SaveSlotMetadata.new()
	metadata.slot_id =1
	metadata.is_empty = false
	metadata.screenshot_data = screenshot_data
	_save_test_metadata(metadata)

	# Reload metadata
	_overlay._load_slot_metadata()
	await get_tree().process_frame

	# Load screenshot first time
	_overlay._selected_slot_index = 1
	_overlay._show_slot_preview(_overlay._slot_metadata[1])
	await get_tree().process_frame

	# Verify cache populated
	assert_eq(_overlay._screenshot_cache.size(), 1, "Cache should contain 1 screenshot")
	assert_true(_overlay._screenshot_cache.has(1), "Cache should contain slot 1")

	var cached_texture: Texture2D = _overlay._screenshot_cache[1]

	# Load screenshot second time
	_overlay._show_slot_preview(_overlay._slot_metadata[1])
	await get_tree().process_frame

	# Verify same texture used (from cache)
	var screenshot_preview: TextureRect = _overlay.get_node("%ScreenshotPreview")
	assert_eq(screenshot_preview.texture, cached_texture, "Second load should use cached texture")


## Metadata display: Play time formatted correctly
func test_metadata_displays_play_time() -> void:
	var metadata := RS_SaveSlotMetadata.new()
	metadata.slot_id =1
	metadata.is_empty = false
	metadata.play_time_seconds = 3661.0  # 1 hour, 1 minute, 1 second
	_save_test_metadata(metadata)

	# Reload metadata
	_overlay._load_slot_metadata()
	_overlay._show_slot_preview(_overlay._slot_metadata[1])
	await get_tree().process_frame

	var play_time_label: Label = _overlay.get_node("%PlayTimeLabel")
	assert_string_contains(play_time_label.text, "01:01:01", "Play time should show 01:01:01")


## Metadata display: Health displayed correctly
func test_metadata_displays_health() -> void:
	var metadata := RS_SaveSlotMetadata.new()
	metadata.slot_id =1
	metadata.is_empty = false
	metadata.player_health = 75.0
	metadata.player_max_health = 100.0
	_save_test_metadata(metadata)

	# Reload metadata
	_overlay._load_slot_metadata()
	_overlay._show_slot_preview(_overlay._slot_metadata[1])
	await get_tree().process_frame

	var health_label: Label = _overlay.get_node("%HealthLabel")
	assert_string_contains(health_label.text, "75", "Health should show current value")
	assert_string_contains(health_label.text, "100", "Health should show max value")


## Metadata display: Death count displayed correctly
func test_metadata_displays_death_count() -> void:
	var metadata := RS_SaveSlotMetadata.new()
	metadata.slot_id =1
	metadata.is_empty = false
	metadata.death_count = 42
	_save_test_metadata(metadata)

	# Reload metadata
	_overlay._load_slot_metadata()
	_overlay._show_slot_preview(_overlay._slot_metadata[1])
	await get_tree().process_frame

	var death_count_label: Label = _overlay.get_node("%DeathCountLabel")
	assert_string_contains(death_count_label.text, "42", "Death count should show 42")


## Back button closes overlay
func test_back_button_closes_overlay() -> void:
	# Clear action history
	_dispatched_actions.clear()

	# Press back button
	_overlay._on_back_pressed()
	await get_tree().process_frame

	# Verify close action dispatched
	var close_action_found := false
	for action in _dispatched_actions:
		if action.get("type") == U_NavigationActions.ACTION_CLOSE_TOP_OVERLAY:
			close_action_found = true
			break

	assert_true(close_action_found, "Back button should dispatch close overlay action")
