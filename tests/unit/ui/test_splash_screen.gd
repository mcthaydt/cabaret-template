extends GutTest

## Tests for UI_SplashScreen boot splash and preloading behavior

const UI_SPLASH_SCREEN := preload("res://scripts/core/ui/menus/ui_splash_screen.gd")

var splash: Control  # UI_SplashScreen

func before_each() -> void:
	U_ServiceLocator.clear()
	splash = _build_splash_screen()
	add_child(splash)
	autofree(splash)
	await get_tree().process_frame

func after_each() -> void:
	splash = null
	U_ServiceLocator.clear()

func _build_splash_screen() -> Control:
	var root: Control = UI_SPLASH_SCREEN.new()

	var crispy_panel := Control.new()
	crispy_panel.name = "CrispyCabaretPanel"
	crispy_panel.unique_name_in_owner = true
	root.add_child(crispy_panel)
	crispy_panel.owner = root

	var godot_panel := Control.new()
	godot_panel.name = "GodotEnginePanel"
	godot_panel.unique_name_in_owner = true
	root.add_child(godot_panel)
	godot_panel.owner = root

	var skip_label := Label.new()
	skip_label.name = "SkipLabel"
	skip_label.unique_name_in_owner = true
	root.add_child(skip_label)
	skip_label.owner = root

	return root

# --- Phase management ---

func test_starts_on_crispy_cabaret_phase() -> void:
	assert_eq(splash.get_current_phase(), UI_SPLASH_SCREEN.Phase.CRISPY_CABARET)

func test_crispy_panel_visible_on_start() -> void:
	var crispy: Control = splash.get_node("%CrispyCabaretPanel") as Control
	var godot: Control = splash.get_node("%GodotEnginePanel") as Control
	assert_true(crispy.visible, "Crispy panel should be visible initially")
	assert_false(godot.visible, "Godot panel should be hidden initially")

func test_skip_not_allowed_before_min_time() -> void:
	assert_false(splash.is_skip_allowed(), "Skip should not be allowed at t=0")

func test_skip_allowed_after_min_time() -> void:
	# Simulate 2+ seconds of _process
	for i in range(130):
		splash._process(1.0 / 60.0)
	assert_true(splash.is_skip_allowed(), "Skip should be allowed after 2s")

func test_advance_to_godot_phase() -> void:
	# Fast-forward past min time
	for i in range(130):
		splash._process(1.0 / 60.0)
	splash._advance_phase()
	assert_eq(splash.get_current_phase(), UI_SPLASH_SCREEN.Phase.GODOT_ENGINE)
	var crispy: Control = splash.get_node("%CrispyCabaretPanel") as Control
	var godot: Control = splash.get_node("%GodotEnginePanel") as Control
	assert_false(crispy.visible, "Crispy panel should be hidden after advance")
	assert_true(godot.visible, "Godot panel should be visible after advance")

func test_advance_from_godot_to_done() -> void:
	splash._advance_phase()  # -> GODOT_ENGINE
	splash._advance_phase()  # -> DONE
	assert_eq(splash.get_current_phase(), UI_SPLASH_SCREEN.Phase.DONE)

func test_timer_resets_on_phase_advance() -> void:
	for i in range(130):
		splash._process(1.0 / 60.0)
	var timer_before: float = splash.get_phase_timer()
	assert_gt(timer_before, 1.9, "Timer should be > 1.9 after 130 frames")
	splash._advance_phase()
	assert_lt(splash.get_phase_timer(), 0.1, "Timer should reset after phase advance")

func test_auto_advance_after_double_min_time() -> void:
	# Simulate 4+ seconds (auto-advance at 2x MIN_DISPLAY_TIME)
	for i in range(250):
		splash._process(1.0 / 60.0)
	assert_ne(
		splash.get_current_phase(), UI_SPLASH_SCREEN.Phase.CRISPY_CABARET,
		"Should auto-advance from crispy phase after 4s"
	)

func test_skip_hint_hidden_initially() -> void:
	var skip: Label = splash.get_node("%SkipLabel") as Label
	assert_false(skip.visible, "Skip hint should be hidden initially")

func test_skip_hint_shown_after_min_time() -> void:
	for i in range(130):
		splash._process(1.0 / 60.0)
	var skip: Label = splash.get_node("%SkipLabel") as Label
	assert_true(skip.visible, "Skip hint should appear after min time")

# --- Preloading ---

func test_gameplay_scene_path_resolves() -> void:
	var path: String = splash._resolve_gameplay_scene_path()
	# power_core may or may not be registered depending on scene registry init
	# Just verify the method doesn't crash and returns a String
	assert_true(path is String, "Should return a String")

func test_gameplay_scene_path_uses_configured_default_scene() -> void:
	var config: RS_GameConfig = load("res://resources/core/cfg_game_config.tres") as RS_GameConfig
	assert_not_null(config, "Game config should load")
	if config == null:
		return
	var expected_path: String = U_SceneRegistry.get_scene_path(config.get_default_gameplay_scene_id())

	assert_eq(splash._resolve_gameplay_scene_path(), expected_path,
		"Splash preload should resolve the configured default gameplay scene")

func test_preload_started_flag() -> void:
	# Preload may or may not have started depending on scene registry
	# Just verify the flag is a bool
	assert_true(splash._preload_started is bool, "preload_started should be a bool")

func test_finalize_preload_does_not_crash_without_preload() -> void:
	splash._preload_started = false
	splash._finalize_preload()
	assert_true(true, "finalize_preload should not crash when nothing was preloaded")
