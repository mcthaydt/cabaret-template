extends GutTest

## TDD tests for mobile pause menu navigation issue
##
## These tests verify that the pause menu properly updates navigation state
## and allows child overlays to open when pause is the parent overlay.

const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")

var _store: M_StateStore

func before_each() -> void:
	_store = M_StateStore.new()
	_store.add_to_group("state_store")
	add_child_autofree(_store)
	await get_tree().process_frame

	# Set shell to gameplay
	_store.dispatch(U_NavigationActions.start_game(StringName("gameplay_base")))
	await get_tree().physics_frame

func test_pause_opens_with_correct_overlay_stack() -> void:
	# GIVEN: Gameplay with no overlays
	var nav := _store.get_slice(StringName("navigation"))
	assert_eq(nav.get("shell"), StringName("gameplay"), "Should be in gameplay shell")
	assert_eq(nav.get("overlay_stack"), [], "Overlay stack should be empty initially")

	# WHEN: Pause menu is opened
	_store.dispatch(U_NavigationActions.open_pause())
	await get_tree().physics_frame

	# THEN: Stack should contain pause_menu
	nav = _store.get_slice(StringName("navigation"))
	assert_eq(nav.get("overlay_stack"), [StringName("pause_menu")], "Pause menu should be in overlay stack")

func test_settings_opens_with_pause_parent() -> void:
	# GIVEN: Pause menu is open (stack = [pause_menu])
	_store.dispatch(U_NavigationActions.open_pause())
	await get_tree().physics_frame

	# WHEN: Settings overlay is requested
	_store.dispatch(U_NavigationActions.open_overlay(StringName("settings_menu_overlay")))
	await get_tree().physics_frame

	# THEN: Stack should contain both pause_menu and settings
	var nav := _store.get_slice(StringName("navigation"))
	assert_eq(nav.get("overlay_stack").size(), 2, "Should have 2 overlays in stack")
	assert_eq(nav.get("overlay_stack")[0], StringName("pause_menu"), "First should be pause_menu")
	assert_eq(nav.get("overlay_stack")[1], StringName("settings_menu_overlay"), "Second should be settings")

func test_settings_REJECTED_without_pause_parent() -> void:
	# GIVEN: Empty overlay stack (no pause menu open)
	var nav := _store.get_slice(StringName("navigation"))
	assert_eq(nav.get("overlay_stack"), [], "Stack should be empty")

	# WHEN: Settings overlay is requested WITHOUT pause menu parent
	_store.dispatch(U_NavigationActions.open_overlay(StringName("settings_menu_overlay")))
	await get_tree().physics_frame

	# THEN: Action should be REJECTED, stack remains empty
	nav = _store.get_slice(StringName("navigation"))
	assert_eq(nav.get("overlay_stack"), [], "Stack should still be empty - action rejected")

func test_overlay_rejected_when_shell_not_gameplay() -> void:
	# GIVEN: Shell is main_menu (not gameplay)
	_store.dispatch(U_NavigationActions.set_shell(StringName("main_menu"), StringName("main_menu")))
	await get_tree().physics_frame

	# WHEN: Try to open overlay
	_store.dispatch(U_NavigationActions.open_overlay(StringName("settings_menu_overlay")))
	await get_tree().physics_frame

	# THEN: Action should be REJECTED
	var nav := _store.get_slice(StringName("navigation"))
	assert_eq(nav.get("overlay_stack"), [], "Overlay should be rejected when shell != gameplay")

func test_gamepad_settings_opens_with_pause_parent() -> void:
	# GIVEN: Pause menu is open
	_store.dispatch(U_NavigationActions.open_pause())
	await get_tree().physics_frame

	# WHEN: Gamepad settings overlay is requested
	_store.dispatch(U_NavigationActions.open_overlay(StringName("gamepad_settings")))
	await get_tree().physics_frame

	# THEN: Stack should contain both
	var nav := _store.get_slice(StringName("navigation"))
	assert_eq(nav.get("overlay_stack").size(), 2, "Should have 2 overlays")
	assert_eq(nav.get("overlay_stack")[1], StringName("gamepad_settings"), "Second should be gamepad_settings")

func test_input_profiles_opens_with_pause_parent() -> void:
	# GIVEN: Pause menu is open
	_store.dispatch(U_NavigationActions.open_pause())
	await get_tree().physics_frame

	# WHEN: Input profiles overlay is requested
	_store.dispatch(U_NavigationActions.open_overlay(StringName("input_profile_selector")))
	await get_tree().physics_frame

	# THEN: Stack should contain both
	var nav := _store.get_slice(StringName("navigation"))
	assert_eq(nav.get("overlay_stack").size(), 2, "Should have 2 overlays")
	assert_eq(nav.get("overlay_stack")[1], StringName("input_profile_selector"), "Second should be input_profile_selector")
