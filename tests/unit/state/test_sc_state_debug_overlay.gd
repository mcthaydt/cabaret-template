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
	pending("Implement after overlay scene is created")

## Test: Debug overlay displays action history
func test_debug_overlay_displays_action_history():
	pending("Implement after overlay scene is created")

## Test: Debug overlay toggles with input action
func test_debug_overlay_toggles_with_input_action():
	# Test will verify M_StateStore._input() spawns/despawns overlay
	pending("Implement after M_StateStore._input() is added")
