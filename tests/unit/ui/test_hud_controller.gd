extends GutTest

const HUD_SCENE := preload("res://scenes/ui/ui_hud_overlay.tscn")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_GAMEPLAY_INITIAL_STATE := preload("res://scripts/resources/state/rs_gameplay_initial_state.gd")
const RS_SCENE_INITIAL_STATE := preload("res://scripts/resources/state/rs_scene_initial_state.gd")
const RS_NAVIGATION_INITIAL_STATE := preload("res://scripts/resources/state/rs_navigation_initial_state.gd")
const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")

func test_hud_controller_uses_process_mode_always() -> void:
	var store := M_STATE_STORE.new()
	store.settings = RS_STATE_STORE_SETTINGS.new()
	store.gameplay_initial_state = RS_GAMEPLAY_INITIAL_STATE.new()
	store.scene_initial_state = RS_SCENE_INITIAL_STATE.new()
	store.navigation_initial_state = RS_NAVIGATION_INITIAL_STATE.new()
	add_child(store)
	autofree(store)
	await get_tree().process_frame

	var hud := HUD_SCENE.instantiate()
	add_child(hud)
	autofree(hud)
	await get_tree().process_frame

	assert_eq(hud.process_mode, Node.PROCESS_MODE_ALWAYS,
		"HUD controller should process even when the scene tree is paused.")

func test_health_bar_hides_when_menus_open() -> void:
	var store := M_STATE_STORE.new()
	store.settings = RS_STATE_STORE_SETTINGS.new()
	store.gameplay_initial_state = RS_GAMEPLAY_INITIAL_STATE.new()
	store.scene_initial_state = RS_SCENE_INITIAL_STATE.new()
	store.navigation_initial_state = RS_NAVIGATION_INITIAL_STATE.new()
	add_child(store)
	autofree(store)
	await get_tree().process_frame
	store.dispatch(U_NavigationActions.start_game(StringName("exterior")))
	await wait_process_frames(1)

	var hud := HUD_SCENE.instantiate()
	add_child(hud)
	autofree(hud)
	await get_tree().process_frame

	var health_bar: ProgressBar = hud.get_node("MarginContainer/VBoxContainer/HealthBar")
	assert_not_null(health_bar, "Health bar should exist")

	# Health bar should be visible during normal gameplay (no overlays)
	assert_true(health_bar.visible, "Health bar should be visible when no menus are open")

	# Simulate opening a menu by pushing an overlay via navigation actions
	store.dispatch(U_NavigationActions.open_pause())
	# Wait for signal batching to flush
	await wait_process_frames(5)

	var nav_with_overlay := store.get_slice(StringName("navigation"))
	var overlay_stack: Array = nav_with_overlay.get("overlay_stack", [])
	assert_gt(overlay_stack.size(), 0, "Navigation overlay stack should not be empty")

	# Health bar should now be hidden
	assert_false(health_bar.visible, "Health bar should be hidden when menu is open")

	# Simulate closing the menu
	store.dispatch(U_NavigationActions.close_pause())
	await wait_process_frames(5)

	# Health bar should be visible again
	assert_true(health_bar.visible, "Health bar should be visible again when menu is closed")

## Test health bar stays hidden when transitioning from gameplay to main menu
## Reproduces bug: health bar flashes when quitting to main menu from pause
func test_health_bar_hidden_when_transitioning_to_main_menu() -> void:
	var store := M_STATE_STORE.new()
	store.settings = RS_STATE_STORE_SETTINGS.new()
	store.gameplay_initial_state = RS_GAMEPLAY_INITIAL_STATE.new()
	store.scene_initial_state = RS_SCENE_INITIAL_STATE.new()
	store.navigation_initial_state = RS_NAVIGATION_INITIAL_STATE.new()
	add_child(store)
	autofree(store)
	await get_tree().process_frame

	# Start in gameplay with pause menu open
	store.dispatch(U_NavigationActions.start_game(StringName("exterior")))
	await wait_process_frames(1)

	var hud := HUD_SCENE.instantiate()
	add_child(hud)
	autofree(hud)
	await get_tree().process_frame

	var health_bar: ProgressBar = hud.get_node("MarginContainer/VBoxContainer/HealthBar")
	assert_not_null(health_bar, "Health bar should exist")

	# Open pause menu
	store.dispatch(U_NavigationActions.open_pause())
	await wait_process_frames(5)

	# Health bar should be hidden
	assert_false(health_bar.visible, "Health bar should be hidden when pause menu is open")

	# Simulate clicking "Quit to Main Menu" - this clears overlays AND changes shell
	store.dispatch(U_NavigationActions.return_to_main_menu())
	await wait_process_frames(5)

	# Health bar should STAY hidden because we're transitioning to main menu shell
	# The shell is now "main_menu" not "gameplay", so health bar remains hidden
	assert_false(health_bar.visible, "Health bar should stay hidden when transitioning to main menu")
