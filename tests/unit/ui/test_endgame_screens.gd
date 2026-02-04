extends GutTest

const GameOverScene := preload("res://scenes/ui/menus/ui_game_over.tscn")
const VictoryScene := preload("res://scenes/ui/menus/ui_victory.tscn")
const CreditsScene := preload("res://scenes/ui/menus/ui_credits.tscn")

const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const RS_StateStoreSettings := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_BootInitialState := preload("res://scripts/resources/state/rs_boot_initial_state.gd")
const RS_MenuInitialState := preload("res://scripts/resources/state/rs_menu_initial_state.gd")
const RS_GameplayInitialState := preload("res://scripts/resources/state/rs_gameplay_initial_state.gd")
const RS_SceneInitialState := preload("res://scripts/resources/state/rs_scene_initial_state.gd")
const RS_SettingsInitialState := preload("res://scripts/resources/state/rs_settings_initial_state.gd")
const RS_NavigationInitialState := preload("res://scripts/resources/state/rs_navigation_initial_state.gd")

const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_StateHandoff := preload("res://scripts/state/utils/u_state_handoff.gd")

func before_each() -> void:
	U_StateHandoff.clear_all()

func after_each() -> void:
	U_StateHandoff.clear_all()

func test_game_over_retry_returns_to_gameplay() -> void:
	var store := await _create_state_store()
	_prepare_endgame_state(store, StringName("game_over"))
	var screen := await _instantiate_scene(GameOverScene)

	var retry_button: Button = screen.get_node("MarginContainer/VBoxContainer/ButtonRow/RetryButton")
	retry_button.emit_signal("pressed")
	await wait_process_frames(2)

	var nav := store.get_slice(StringName("navigation"))
	assert_eq(nav.get("shell"), StringName("gameplay"), "Retry should switch shell to gameplay")

func test_game_over_menu_returns_to_main_menu() -> void:
	var store := await _create_state_store()
	_prepare_endgame_state(store, StringName("game_over"))
	var screen := await _instantiate_scene(GameOverScene)

	var menu_button: Button = screen.get_node("MarginContainer/VBoxContainer/ButtonRow/MenuButton")
	menu_button.emit_signal("pressed")
	await wait_process_frames(2)

	var nav := store.get_slice(StringName("navigation"))
	assert_eq(nav.get("shell"), StringName("main_menu"), "Menu should switch shell to main menu")

func test_game_over_back_matches_retry() -> void:
	var store := await _create_state_store()
	_prepare_endgame_state(store, StringName("game_over"))
	var screen := await _instantiate_scene(GameOverScene)

	var back_event := InputEventAction.new()
	back_event.action = "ui_cancel"
	back_event.pressed = true
	screen._unhandled_input(back_event)
	await wait_process_frames(2)

	var nav := store.get_slice(StringName("navigation"))
	assert_eq(nav.get("shell"), StringName("gameplay"), "ui_cancel should trigger retry flow")

func test_victory_continue_returns_to_gameplay() -> void:
	var store := await _create_state_store()
	_prepare_endgame_state(store, StringName("victory"))
	var screen := await _instantiate_scene(VictoryScene)

	var continue_button: Button = screen.get_node("MarginContainer/VBoxContainer/ButtonRow/ContinueButton")
	continue_button.emit_signal("pressed")
	await wait_process_frames(2)

	var nav := store.get_slice(StringName("navigation"))
	assert_eq(nav.get("shell"), StringName("gameplay"), "Continue should return to gameplay shell")

func test_victory_credits_opens_credits_scene() -> void:
	var store := await _create_state_store()
	_prepare_endgame_state(store, StringName("victory"))
	var screen := await _instantiate_scene(VictoryScene)

	var credits_button: Button = screen.get_node("MarginContainer/VBoxContainer/ButtonRow/CreditsButton")
	credits_button.emit_signal("pressed")
	await wait_process_frames(2)

	var nav := store.get_slice(StringName("navigation"))
	assert_eq(nav.get("base_scene_id"), StringName("credits"), "Credits button should target credits scene")

func test_victory_menu_returns_to_main_menu() -> void:
	var store := await _create_state_store()
	_prepare_endgame_state(store, StringName("victory"))
	var screen := await _instantiate_scene(VictoryScene)

	var menu_button: Button = screen.get_node("MarginContainer/VBoxContainer/ButtonRow/MenuButton")
	menu_button.emit_signal("pressed")
	await wait_process_frames(2)

	var nav := store.get_slice(StringName("navigation"))
	assert_eq(nav.get("shell"), StringName("main_menu"), "Menu button should return to main menu shell")

func test_victory_back_opens_credits() -> void:
	var store := await _create_state_store()
	_prepare_endgame_state(store, StringName("victory"))
	var screen := await _instantiate_scene(VictoryScene)

	var back_event := InputEventAction.new()
	back_event.action = "ui_cancel"
	back_event.pressed = true
	screen._unhandled_input(back_event)
	await wait_process_frames(2)

	var nav := store.get_slice(StringName("navigation"))
	assert_eq(nav.get("base_scene_id"), StringName("credits"), "ui_cancel should skip to credits")

func test_credits_skip_returns_to_menu() -> void:
	var store := await _create_state_store()
	_prepare_credits_state(store)
	var screen := await _instantiate_scene(CreditsScene)

	var skip_button: Button = screen.get_node("SkipButton")
	skip_button.emit_signal("pressed")
	await _await_shell(store, StringName("main_menu"))
	var nav_after_skip := store.get_slice(StringName("navigation"))
	assert_eq(nav_after_skip.get("shell"), StringName("main_menu"), "Skip should return to main menu shell")

func test_credits_auto_return_dispatches_navigation() -> void:
	var store := await _create_state_store()
	_prepare_credits_state(store)
	var screen := await _instantiate_scene(CreditsScene)
	screen.set_test_durations(0.05, 0.1)

	await _await_shell(store, StringName("main_menu"), 120)
	var nav_after_auto := store.get_slice(StringName("navigation"))
	assert_eq(nav_after_auto.get("shell"), StringName("main_menu"), "Auto-return should dispatch skip_to_menu")

func test_credits_back_matches_skip() -> void:
	var store := await _create_state_store()
	_prepare_credits_state(store)
	var screen := await _instantiate_scene(CreditsScene)

	var back_event := InputEventAction.new()
	back_event.action = "ui_cancel"
	back_event.pressed = true
	screen._unhandled_input(back_event)
	await wait_process_frames(2)

	await _await_shell(store, StringName("main_menu"))
	var nav_after_back := store.get_slice(StringName("navigation"))
	assert_eq(nav_after_back.get("shell"), StringName("main_menu"), "ui_cancel should behave like skip")

func _create_state_store() -> M_StateStore:
	var store := M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.settings.enable_persistence = false
	store.boot_initial_state = RS_BootInitialState.new()
	store.menu_initial_state = RS_MenuInitialState.new()
	store.navigation_initial_state = RS_NavigationInitialState.new()
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	store.scene_initial_state = RS_SceneInitialState.new()
	store.scene_initial_state.current_scene_id = StringName("main_menu")
	store.settings_initial_state = RS_SettingsInitialState.new()
	add_child_autofree(store)
	await wait_process_frames(2)
	return store

func _prepare_endgame_state(store: M_StateStore, end_scene: StringName) -> void:
	store.dispatch(U_NavigationActions.start_game(StringName("alleyway")))
	store.dispatch(U_NavigationActions.open_endgame(end_scene))

func _prepare_credits_state(store: M_StateStore) -> void:
	_prepare_endgame_state(store, StringName("victory"))
	store.dispatch(U_NavigationActions.skip_to_credits())

func _await_shell(store: M_StateStore, target_shell: StringName, max_frames: int = 60) -> void:
	for _i in range(max_frames):
		var nav := store.get_slice(StringName("navigation"))
		if nav.get("shell") == target_shell:
			return
		await wait_process_frames(1)
	assert_true(false, "Timed out waiting for shell %s" % target_shell)

func _instantiate_scene(packed_scene: PackedScene) -> Control:
	var instance := packed_scene.instantiate()
	add_child_autofree(instance)
	await wait_process_frames(3)
	return instance
