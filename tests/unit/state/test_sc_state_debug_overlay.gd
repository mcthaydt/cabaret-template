extends GutTest

## Tests for SC_StateDebugOverlay - Debug overlay UI
##
## Tests the F3-toggleable debug overlay that displays:
## - Current state (JSON formatted)
## - Action history (last 20 actions)
## - Action detail view (before/after state diff)

var store: M_StateStore
var overlay: Node

func before_each():
	StateStoreEventBus.reset()
	
	# Create store
	store = M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	autofree(store)
	add_child_autofree(store)
	await get_tree().process_frame

func after_each():
	if overlay and is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null

## Test: Debug overlay instantiates without errors
func test_debug_overlay_instantiates_without_errors():
	# Load overlay scene (will fail until scene is created)
	var overlay_scene = load("res://scenes/debug/sc_state_debug_overlay.tscn")
	assert_not_null(overlay_scene, "Debug overlay scene should exist")
	
	overlay = overlay_scene.instantiate()
	assert_not_null(overlay, "Overlay should instantiate")
	
	add_child_autofree(overlay)
	await get_tree().process_frame
	
	assert_true(is_instance_valid(overlay), "Overlay should be valid after adding to tree")

## Test: Debug overlay displays current state
func test_debug_overlay_displays_current_state():
	# Load and instantiate overlay
	var overlay_scene = load("res://scenes/debug/sc_state_debug_overlay.tscn")
	assert_not_null(overlay_scene, "Debug overlay scene should exist")
	
	overlay = overlay_scene.instantiate()
	add_child_autofree(overlay)
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Dispatch action to change state
	store.dispatch({"type": "gameplay/update_health", "payload": {"health": 75}})
	await get_tree().process_frame
	
	# Wait for overlay to process and update display
	await get_tree().process_frame
	
	# Get state label
	var state_label: Label = overlay.get_node("%StateLabel")
	assert_not_null(state_label, "StateLabel should exist in overlay")
	
	# Verify state is displayed (should contain JSON structure)
	var displayed_text: String = state_label.text
	assert_true(displayed_text.length() > 0, "State label should have content")
	# Just verify it's displaying some state data, not empty
	assert_false(displayed_text.contains("loading"), "State label should not show 'loading' after initialization")

## Test: Debug overlay displays action history
func test_debug_overlay_displays_action_history():
	# Load and instantiate overlay
	var overlay_scene = load("res://scenes/debug/sc_state_debug_overlay.tscn")
	overlay = overlay_scene.instantiate()
	add_child_autofree(overlay)
	await get_tree().process_frame
	
	# Dispatch multiple actions
	store.dispatch({"type": "gameplay/update_health", "payload": {"health": 90}})
	await get_tree().process_frame
	store.dispatch({"type": "gameplay/update_health", "payload": {"health": 80}})
	await get_tree().process_frame
	store.dispatch({"type": "gameplay/update_health", "payload": {"health": 70}})
	await get_tree().process_frame
	
	# Get history list
	var history_list: ItemList = overlay.get_node("%HistoryList")
	assert_not_null(history_list, "HistoryList should exist in overlay")
	
	# Verify actions are in history (should have at least 3)
	assert_gte(history_list.item_count, 3, "History should contain at least 3 actions")
	
	# Verify action types are displayed
	var found_set_health := false
	for i in range(history_list.item_count):
		var item_text := history_list.get_item_text(i)
		if item_text.contains("update_health"):
			found_set_health = true
			break
	assert_true(found_set_health, "History should display 'update_health' actions")

## Test: Debug overlay toggles with input action
func test_debug_overlay_toggles_with_input_action():
	# Verify M_StateStore has _input method for F3 toggle
	assert_true(store.has_method("_input"), "M_StateStore should have _input method")
	
	# Check if overlay is initially hidden/not present
	var overlays_before := get_tree().get_nodes_in_group("state_debug_overlay")
	var initial_count := overlays_before.size()
	
	# Simulate toggle_debug_overlay action being pressed
	# Use physical_keycode for F3 (4194334)
	var key_event := InputEventKey.new()
	key_event.physical_keycode = KEY_F3
	key_event.pressed = true
	
	# Simulate input being processed
	Input.parse_input_event(key_event)
	store._input(key_event)
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Verify overlay was spawned
	var overlays_after := get_tree().get_nodes_in_group("state_debug_overlay")
	assert_gt(overlays_after.size(), initial_count, "Pressing F3 should spawn debug overlay")
	
	# Simulate F3 key release
	key_event.pressed = false
	Input.parse_input_event(key_event)
	await get_tree().process_frame
	
	# Simulate F3 key press again to toggle off
	key_event.pressed = true
	Input.parse_input_event(key_event)
	store._input(key_event)
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Verify overlay was removed
	var overlays_final := get_tree().get_nodes_in_group("state_debug_overlay")
	assert_eq(overlays_final.size(), initial_count, "Pressing F3 again should remove debug overlay")
