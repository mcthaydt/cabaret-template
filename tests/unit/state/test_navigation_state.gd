extends GutTest

## Tests for navigation slice reducer, selectors, and initial state

const U_StateEventBus := preload("res://scripts/events/state/u_state_event_bus.gd")
const StateHandoff := preload("res://scripts/state/utils/u_state_handoff.gd")
const RS_StateStoreSettings := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_NavigationInitialState := preload("res://scripts/resources/state/rs_navigation_initial_state.gd")
const RS_GameplayInitialState := preload("res://scripts/resources/state/rs_gameplay_initial_state.gd")
const RS_MenuInitialState := preload("res://scripts/resources/state/rs_menu_initial_state.gd")
const RS_SceneInitialState := preload("res://scripts/resources/state/rs_scene_initial_state.gd")
const RS_SettingsInitialState := preload("res://scripts/resources/state/rs_settings_initial_state.gd")
const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_NavigationReducer := preload("res://scripts/state/reducers/u_navigation_reducer.gd")
const U_NavigationSelectors := preload("res://scripts/state/selectors/u_navigation_selectors.gd")

var _store

func before_each() -> void:
	U_StateEventBus.reset()
	StateHandoff.clear_all()

func after_each() -> void:
	U_StateEventBus.reset()
	StateHandoff.clear_all()

## T010: Navigation initial state defaults
func test_navigation_initial_state_defaults() -> void:
	var initial_state := RS_NavigationInitialState.new()
	var state_dict: Dictionary = initial_state.to_dictionary()

	assert_eq(state_dict.get("shell"), StringName("main_menu"), "Shell should default to main_menu")
	assert_eq(state_dict.get("base_scene_id"), StringName("main_menu"), "Base scene should default to main_menu")
	assert_eq(state_dict.get("overlay_stack"), [], "Overlay stack should start empty")
	assert_eq(state_dict.get("overlay_return_stack"), [], "Overlay return stack should start empty")
	assert_eq(state_dict.get("active_menu_panel"), StringName("menu/main"), "Active menu panel should default to menu/main")

## T011: Open/close pause flow
func test_open_close_pause_flow() -> void:
	var state: Dictionary = {
		"shell": StringName("gameplay"),
		"base_scene_id": StringName("alleyway"),
		"overlay_stack": [],
		"active_menu_panel": StringName("menu/main")
	}

	var paused_state: Dictionary = U_NavigationReducer.reduce(state, U_NavigationActions.open_pause())
	assert_eq(paused_state.get("overlay_stack"), [StringName("pause_menu")], "Pause overlay should be pushed")
	assert_true(U_NavigationSelectors.is_paused(paused_state), "Paused selector should reflect overlay presence")

	var resumed_state: Dictionary = U_NavigationReducer.reduce(paused_state, U_NavigationActions.close_pause())
	assert_eq(resumed_state.get("overlay_stack"), [], "Overlay stack should clear when closing pause")
	assert_false(U_NavigationSelectors.is_paused(resumed_state), "Paused selector should be false after closing")

## T011/T014: Nested overlay navigation (pause -> settings -> back)
func test_nested_overlay_navigation_returns_to_pause_then_resumes_gameplay() -> void:
	var state: Dictionary = {
		"shell": StringName("gameplay"),
		"base_scene_id": StringName("alleyway"),
		"overlay_stack": [StringName("pause_menu")],
		"overlay_return_stack": [],
		"active_menu_panel": StringName("pause/root")
	}

	var settings_state: Dictionary = U_NavigationReducer.reduce(state, U_NavigationActions.open_overlay(StringName("settings_menu_overlay")))
	assert_eq(settings_state.get("overlay_stack"), [StringName("settings_menu_overlay")], "Settings overlay should replace pause as top overlay")
	assert_eq(settings_state.get("overlay_return_stack"), [StringName("pause_menu")], "Pause overlay should be stored for return navigation")

	var back_to_pause: Dictionary = U_NavigationReducer.reduce(settings_state, U_NavigationActions.close_top_overlay())
	assert_eq(back_to_pause.get("overlay_stack"), [StringName("pause_menu")], "CloseMode RETURN should restore pause overlay")
	assert_eq(back_to_pause.get("overlay_return_stack"), [], "Return stack should be cleared after returning to pause")

	var resumed_state: Dictionary = U_NavigationReducer.reduce(back_to_pause, U_NavigationActions.close_top_overlay())
	assert_eq(resumed_state.get("overlay_stack"), [], "Closing pause should clear overlay stack")
	assert_eq(resumed_state.get("overlay_return_stack"), [], "Return stack should remain empty after closing pause")
	assert_false(U_NavigationSelectors.is_paused(resumed_state), "Game should be unpaused after closing pause overlay")

## T011/T014: Overlays that resume gameplay directly
func test_overlay_close_mode_resumes_gameplay_directly() -> void:
	var state: Dictionary = {
		"shell": StringName("gameplay"),
		"base_scene_id": StringName("alleyway"),
		"overlay_stack": [StringName("settings_menu_overlay")],
		"overlay_return_stack": [StringName("pause_menu")],
		"active_menu_panel": StringName("pause/root")
	}

	var rebinding_state: Dictionary = U_NavigationReducer.reduce(state, U_NavigationActions.open_overlay(StringName("input_rebinding")))
	assert_eq(rebinding_state.get("overlay_stack"), [StringName("input_rebinding")], "Input rebinding overlay should be top overlay")
	assert_eq(rebinding_state.get("overlay_return_stack"), [StringName("pause_menu"), StringName("settings_menu_overlay")], "Pause and settings overlays should be stored for return semantics")

	var resumed_state: Dictionary = U_NavigationReducer.reduce(rebinding_state, U_NavigationActions.close_top_overlay())
	assert_eq(resumed_state.get("overlay_stack"), [StringName("settings_menu_overlay")], "Rebinding overlay should close and return to settings overlay")
	assert_eq(resumed_state.get("overlay_return_stack"), [StringName("pause_menu")], "Pause overlay should remain in return stack")
	assert_true(U_NavigationSelectors.is_paused(resumed_state), "Game should remain paused while settings overlay is active")

## T011: Menu panel switching
func test_set_menu_panel_updates_active_panel() -> void:
	var state: Dictionary = RS_NavigationInitialState.new().to_dictionary()
	var panel_state: Dictionary = U_NavigationReducer.reduce(state, U_NavigationActions.set_menu_panel(StringName("menu/settings")))

	assert_eq(panel_state.get("active_menu_panel"), StringName("menu/settings"), "Active menu panel should update to requested panel")
	assert_eq(state.get("active_menu_panel"), StringName("menu/main"), "Original state should remain unchanged (immutability)")

## T011/T014: Endgame flows (open -> retry -> main menu)
func test_endgame_retry_and_return_to_menu() -> void:
	var state: Dictionary = {
		"shell": StringName("gameplay"),
		"base_scene_id": StringName("alleyway"),
		"overlay_stack": [],
		"active_menu_panel": StringName("menu/main")
	}

	var endgame_state: Dictionary = U_NavigationReducer.reduce(state, U_NavigationActions.open_endgame(StringName("game_over")))
	assert_eq(endgame_state.get("shell"), StringName("endgame"), "Shell should switch to endgame on open_endgame")
	assert_eq(endgame_state.get("base_scene_id"), StringName("game_over"), "Base scene should point to endgame scene id")
	assert_eq(endgame_state.get("overlay_stack"), [], "Overlays should clear when entering endgame")

	var retry_state: Dictionary = U_NavigationReducer.reduce(endgame_state, U_NavigationActions.retry())
	assert_eq(retry_state.get("shell"), StringName("gameplay"), "Retry should return to gameplay shell")
	assert_eq(retry_state.get("base_scene_id"), StringName("alleyway"), "Retry should restore last gameplay scene")

	var menu_state: Dictionary = U_NavigationReducer.reduce(endgame_state, U_NavigationActions.return_to_main_menu())
	assert_eq(menu_state.get("shell"), StringName("main_menu"), "Return to main menu should switch shell")
	assert_eq(menu_state.get("base_scene_id"), StringName("main_menu"), "Base scene should point to main menu after return_to_main_menu")
	assert_eq(menu_state.get("overlay_stack"), [], "Overlays should be cleared when returning to main menu")

## T011: Victory skip flows
func test_victory_skip_to_credits_and_menu() -> void:
	var state: Dictionary = {
		"shell": StringName("endgame"),
		"base_scene_id": StringName("victory"),
		"overlay_stack": [],
		"active_menu_panel": StringName("menu/main")
	}

	var credits_state: Dictionary = U_NavigationReducer.reduce(state, U_NavigationActions.skip_to_credits())
	assert_eq(credits_state.get("base_scene_id"), StringName("credits"), "Skip to credits should change base scene to credits")
	assert_eq(credits_state.get("shell"), StringName("endgame"), "Shell should remain endgame while viewing credits")

	var menu_state: Dictionary = U_NavigationReducer.reduce(credits_state, U_NavigationActions.skip_to_menu())
	assert_eq(menu_state.get("shell"), StringName("main_menu"), "Skip to menu should return to main menu shell")
	assert_eq(menu_state.get("base_scene_id"), StringName("main_menu"), "Base scene should be main menu after skip_to_menu")

## T011/T014: Invalid overlays should be ignored in wrong contexts
func test_open_overlay_ignored_in_wrong_shell() -> void:
	var state: Dictionary = {
		"shell": StringName("main_menu"),
		"base_scene_id": StringName("main_menu"),
		"overlay_stack": [],
		"active_menu_panel": StringName("menu/main")
	}

	var pause_attempt: Dictionary = U_NavigationReducer.reduce(state, U_NavigationActions.open_pause())
	assert_eq(pause_attempt, state, "Pause should be ignored outside gameplay shell")

	var overlay_attempt: Dictionary = U_NavigationReducer.reduce(state, U_NavigationActions.open_overlay(StringName("settings_menu_overlay")))
	assert_eq(overlay_attempt, state, "Overlay open should be ignored outside gameplay shell")

## T013: Selectors expose derived values without mutation
func test_navigation_selectors_reflect_state_and_do_not_mutate() -> void:
	var state: Dictionary = {
		"shell": StringName("gameplay"),
		"base_scene_id": StringName("alleyway"),
		"overlay_stack": [StringName("settings_menu_overlay")],
		"overlay_return_stack": [StringName("pause_menu")],
		"active_menu_panel": StringName("pause/root")
	}

	var shell: StringName = U_NavigationSelectors.get_shell(state)
	var base_scene_id: StringName = U_NavigationSelectors.get_base_scene_id(state)
	var overlay_stack: Array = U_NavigationSelectors.get_overlay_stack(state)
	var top_overlay: StringName = U_NavigationSelectors.get_top_overlay_id(state)
	var close_mode: int = U_NavigationSelectors.get_top_overlay_close_mode(state)
	var paused: bool = U_NavigationSelectors.is_paused(state)
	var active_panel: StringName = U_NavigationSelectors.get_active_menu_panel(state)

	assert_eq(shell, StringName("gameplay"), "Selector should return shell")
	assert_eq(base_scene_id, StringName("alleyway"), "Selector should return base scene id")
	assert_eq(overlay_stack, [StringName("settings_menu_overlay")], "Selector should return overlay stack copy")
	assert_eq(top_overlay, StringName("settings_menu_overlay"), "Top overlay should be settings menu overlay")
	assert_eq(close_mode, U_NavigationReducer.CloseMode.RETURN_TO_PREVIOUS_OVERLAY, "Settings overlay should return to previous overlay")
	assert_true(paused, "Paused selector should return true when overlays exist in gameplay")
	assert_eq(active_panel, StringName("pause/root"), "Active menu panel should be preserved")
	assert_eq(state.get("overlay_stack"), [StringName("settings_menu_overlay")], "Selectors should not mutate source state")

## T012: Navigation slice registers in state store
func test_navigation_slice_initializes_in_state_store() -> void:
	_store = M_StateStore.new()
	_store.settings = RS_StateStoreSettings.new()
	_store.navigation_initial_state = RS_NavigationInitialState.new()
	_store.gameplay_initial_state = RS_GameplayInitialState.new()
	_store.menu_initial_state = RS_MenuInitialState.new()
	_store.scene_initial_state = RS_SceneInitialState.new()
	_store.settings_initial_state = RS_SettingsInitialState.new()

	add_child(_store)
	autofree(_store)
	await get_tree().process_frame

	var navigation_slice: Dictionary = _store.get_slice(StringName("navigation"))
	assert_eq(navigation_slice.get("shell"), StringName("main_menu"), "Navigation slice should initialize with default shell")

	_store.dispatch(U_NavigationActions.start_game(StringName("alleyway")))
	_store.dispatch(U_NavigationActions.open_pause())
	var updated_slice: Dictionary = _store.get_slice(StringName("navigation"))
	assert_true(updated_slice.get("overlay_stack", []).size() > 0, "Navigation slice should update via dispatched actions")
