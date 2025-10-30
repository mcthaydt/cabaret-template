extends GutTest

## Integration tests for state slice transitions

const U_StateEventBus := preload("res://scripts/state/u_state_event_bus.gd")
const StateHandoff := preload("res://scripts/state/utils/u_state_handoff.gd")
const U_TransitionActions := preload("res://scripts/state/actions/u_transition_actions.gd")
const U_BootActions := preload("res://scripts/state/actions/u_boot_actions.gd")
const U_MenuActions := preload("res://scripts/state/actions/u_menu_actions.gd")
const U_GameplayActions := preload("res://scripts/state/actions/u_gameplay_actions.gd")
const RS_BootInitialState := preload("res://scripts/state/resources/rs_boot_initial_state.gd")
const RS_MenuInitialState := preload("res://scripts/state/resources/rs_menu_initial_state.gd")
const RS_GameplayInitialState := preload("res://scripts/state/resources/rs_gameplay_initial_state.gd")

func before_each() -> void:
	U_StateEventBus.reset()
	StateHandoff.clear_all()

func after_each() -> void:
	U_StateEventBus.reset()
	StateHandoff.clear_all()

## T384: Test boot to menu transition preserves boot completion
func test_boot_to_menu_transition_preserves_boot_completion() -> void:
	var store := M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.boot_initial_state = RS_BootInitialState.new()
	store.menu_initial_state = RS_MenuInitialState.new()
	add_child_autofree(store)
	await get_tree().process_frame

	# Complete boot sequence
	store.dispatch(U_BootActions.boot_complete())

	# Verify boot is complete
	var boot_state: Dictionary = store.get_slice(StringName("boot"))
	assert_true(boot_state.get("is_ready"), "Boot should be complete")

	# Transition to menu
	store.dispatch(U_TransitionActions.transition_to_menu())

	# Verify boot completion is preserved
	boot_state = store.get_slice(StringName("boot"))
	assert_true(boot_state.get("is_ready"), "Boot completion should be preserved after transition")

	# Verify menu is now active
	var menu_state: Dictionary = store.get_slice(StringName("menu"))
	assert_eq(menu_state.get("active_screen"), "main_menu", "Menu should be active after transition")

## T385: Test menu to gameplay transition initializes gameplay state
func test_menu_to_gameplay_transition_applies_pending_config() -> void:
	var store := M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.menu_initial_state = RS_MenuInitialState.new()
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	add_child_autofree(store)
	await get_tree().process_frame

	# Set up menu config
	store.dispatch(U_MenuActions.select_character("warrior"))
	store.dispatch(U_MenuActions.select_difficulty("hard"))

	# Verify config is set
	var menu_state: Dictionary = store.get_slice(StringName("menu"))
	assert_eq(menu_state.get("pending_character"), "warrior", "Character should be selected")
	assert_eq(menu_state.get("pending_difficulty"), "hard", "Difficulty should be selected")

	# Transition to gameplay with config
	var config: Dictionary = {
		"character": menu_state.get("pending_character"),
		"difficulty": menu_state.get("pending_difficulty")
	}
	store.dispatch(U_TransitionActions.transition_to_gameplay(config))

	# Verify gameplay state is initialized with real fields
	var gameplay_state: Dictionary = store.get_slice(StringName("gameplay"))
	assert_false(gameplay_state.get("paused"), "Gameplay should start unpaused")
	assert_true(gameplay_state.has("entities"), "Gameplay should have entities field")
	assert_eq(gameplay_state.get("entities"), {}, "Entities should start empty")

## T386: Test gameplay to menu transition preserves state
func test_gameplay_to_menu_transition_preserves_progress() -> void:
	var store := M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.menu_initial_state = RS_MenuInitialState.new()
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	add_child_autofree(store)
	await get_tree().process_frame

	# Simulate gameplay state changes
	store.dispatch(U_GameplayActions.pause_game())

	var gameplay_state_before: Dictionary = store.get_slice(StringName("gameplay"))
	var paused_before: bool = gameplay_state_before.get("paused")

	# Transition back to menu
	store.dispatch(U_TransitionActions.transition_to_menu())

	# Verify gameplay state is preserved
	var gameplay_state_after: Dictionary = store.get_slice(StringName("gameplay"))
	assert_eq(gameplay_state_after.get("paused"), paused_before, "Paused state should be preserved")

	# Verify menu is active
	var menu_state: Dictionary = store.get_slice(StringName("menu"))
	assert_eq(menu_state.get("active_screen"), "main_menu", "Menu should be active")

## T387: Test full flow boot → menu → gameplay → menu
func test_full_flow_boot_to_menu_to_gameplay_to_menu() -> void:
	var store := M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.boot_initial_state = RS_BootInitialState.new()
	store.menu_initial_state = RS_MenuInitialState.new()
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	add_child_autofree(store)
	await get_tree().process_frame

	# Step 1: Complete boot
	store.dispatch(U_BootActions.update_loading_progress(0.5))
	store.dispatch(U_BootActions.update_loading_progress(1.0))
	store.dispatch(U_BootActions.boot_complete())

	var boot_state: Dictionary = store.get_slice(StringName("boot"))
	assert_true(boot_state.get("is_ready"), "Boot should be complete")

	# Step 2: Transition to menu
	store.dispatch(U_TransitionActions.transition_to_menu())

	var menu_state: Dictionary = store.get_slice(StringName("menu"))
	assert_eq(menu_state.get("active_screen"), "main_menu", "Should be in menu")

	# Step 3: Configure game
	store.dispatch(U_MenuActions.select_character("mage"))
	store.dispatch(U_MenuActions.select_difficulty("easy"))

	menu_state = store.get_slice(StringName("menu"))
	var config: Dictionary = {
		"character": menu_state.get("pending_character"),
		"difficulty": menu_state.get("pending_difficulty")
	}

	# Step 4: Transition to gameplay
	store.dispatch(U_TransitionActions.transition_to_gameplay(config))

	var gameplay_state: Dictionary = store.get_slice(StringName("gameplay"))
	assert_false(gameplay_state.get("paused"), "Gameplay should start unpaused")
	assert_true(gameplay_state.has("entities"), "Gameplay should have entities field")

	# Step 5: Play game (pause/unpause)
	store.dispatch(U_GameplayActions.pause_game())

	gameplay_state = store.get_slice(StringName("gameplay"))
	assert_true(gameplay_state.get("paused"), "Game should be paused")

	store.dispatch(U_GameplayActions.unpause_game())
	gameplay_state = store.get_slice(StringName("gameplay"))
	assert_false(gameplay_state.get("paused"), "Game should be unpaused")

	# Step 6: Return to menu
	store.dispatch(U_TransitionActions.transition_to_menu())

	menu_state = store.get_slice(StringName("menu"))
	assert_eq(menu_state.get("active_screen"), "main_menu", "Should be back in menu")

	# Verify all state is preserved
	boot_state = store.get_slice(StringName("boot"))
	gameplay_state = store.get_slice(StringName("gameplay"))
	assert_true(boot_state.get("is_ready"), "Boot should still be complete")
	assert_false(gameplay_state.get("paused"), "Gameplay state should be preserved")
