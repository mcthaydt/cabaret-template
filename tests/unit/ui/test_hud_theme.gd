extends GutTest

const HUD_SCENE := preload("res://scenes/ui/hud/ui_hud_overlay.tscn")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/core/resources/state/rs_state_store_settings.gd")
const RS_GAMEPLAY_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_gameplay_initial_state.gd")
const RS_SCENE_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_scene_initial_state.gd")
const RS_NAVIGATION_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_navigation_initial_state.gd")
const U_NAVIGATION_ACTIONS := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")
const RS_UI_MOTION_SET := preload("res://scripts/core/resources/ui/rs_ui_motion_set.gd")
const RS_UI_MOTION_PRESET := preload("res://scripts/core/resources/ui/rs_ui_motion_preset.gd")

var _store: M_StateStore
var _hud: UI_HudController

func before_each() -> void:
	U_UI_THEME_BUILDER.active_config = null
	U_StateHandoff.clear_all()
	U_ServiceLocator.clear()
	U_ECSEventBus.reset()
	U_InteractBlocker.cleanup()

	_store = _create_store()
	_store.dispatch(U_NAVIGATION_ACTIONS.start_game(StringName("alleyway")))
	await get_tree().process_frame

func after_each() -> void:
	U_UI_THEME_BUILDER.active_config = null
	U_StateHandoff.clear_all()
	U_ServiceLocator.clear()
	U_ECSEventBus.reset()
	U_InteractBlocker.cleanup()
	_store = null
	_hud = null

func test_health_bar_uses_theme_styles() -> void:
	var config := RS_UI_THEME_CONFIG.new()
	config.health_bg = Color(0.16, 0.24, 0.40, 1.0)
	config.progress_bar_bg = null
	_hud = await _spawn_hud_with_config(config)

	var health_bar := _hud.health_bar
	var bg_style := health_bar.get_theme_stylebox(&"background")
	assert_true(bg_style is StyleBoxFlat, "Health bar background should come from themed ProgressBar stylebox")
	if bg_style is StyleBoxFlat:
		assert_true(
			(bg_style as StyleBoxFlat).bg_color.is_equal_approx(config.health_bg),
			"Health bar background color should match config.health_bg"
		)

func test_health_bar_no_inline_style_overrides() -> void:
	var config := RS_UI_THEME_CONFIG.new()
	_hud = await _spawn_hud_with_config(config)

	assert_false(
		_hud.health_bar.has_theme_stylebox_override(&"background"),
		"Health bar should rely on theme styles instead of node style overrides"
	)

func test_signpost_golden_override_preserved() -> void:
	var config := RS_UI_THEME_CONFIG.new()
	config.golden = Color(0.87, 0.71, 0.25, 1.0)
	_hud = await _spawn_hud_with_config(config)

	assert_true(
		_hud.signpost_message_label.has_theme_color_override(&"font_color"),
		"Signpost label should keep semantic golden font color override"
	)
	assert_true(
		_hud.signpost_message_label.get_theme_color(&"font_color").is_equal_approx(config.golden),
		"Signpost semantic golden color should come from active theme config"
	)

func test_life_label_semantic_overrides_are_script_applied() -> void:
	var config := RS_UI_THEME_CONFIG.new()
	config.accent_primary = Color(0.3, 0.9, 1.0, 1.0)
	config.bg_base = Color(0.05, 0.06, 0.08, 1.0)
	_hud = await _spawn_hud_with_config(config)

	var life_label := _hud.get_node_or_null("MarginContainer/VBoxContainer/HealthContainer/LifeLabel") as Label
	assert_not_null(life_label, "HUD should expose the LIFE label node")
	if life_label == null:
		return

	assert_true(
		life_label.has_theme_color_override(&"font_color"),
		"LIFE label should set semantic font color in script"
	)
	assert_true(
		life_label.get_theme_color(&"font_color").is_equal_approx(config.accent_primary),
		"LIFE label font color should follow config.accent_primary"
	)
	assert_true(
		life_label.get_theme_color(&"font_outline_color").is_equal_approx(config.bg_base),
		"LIFE label outline color should follow config.bg_base"
	)
	assert_eq(
		life_label.get_theme_constant(&"outline_size"),
		4,
		"LIFE label should keep readable outline size"
	)

func test_toast_uses_motion_resource() -> void:
	var config := RS_UI_THEME_CONFIG.new()
	U_UI_THEME_BUILDER.active_config = config

	var custom_motion := RS_UI_MOTION_SET.new()
	var fade_in := RS_UI_MOTION_PRESET.new()
	fade_in.property_path = "modulate:a"
	fade_in.from_value = 0.0
	fade_in.to_value = 1.0
	fade_in.duration_sec = 0.01

	var hold := RS_UI_MOTION_PRESET.new()
	hold.interval_sec = 0.02

	var fade_out := RS_UI_MOTION_PRESET.new()
	fade_out.property_path = "modulate:a"
	fade_out.from_value = 1.0
	fade_out.to_value = 0.0
	fade_out.duration_sec = 0.01

	var custom_steps: Array[Resource] = [fade_in, hold, fade_out]
	custom_motion.enter = custom_steps

	_hud = HUD_SCENE.instantiate() as UI_HudController
	_apply_theme_to_hud_controls(_hud, U_UI_THEME_BUILDER.build_theme(config))
	_hud.checkpoint_toast_motion_set = custom_motion
	add_child_autofree(_hud)
	await get_tree().process_frame

	U_ECSEventBus.publish(StringName("checkpoint_activated"), {
		"checkpoint_id": StringName("cp_motion_test")
	})
	await get_tree().process_frame

	assert_true(_hud.toast_container.visible, "Toast should become visible when checkpoint event fires")
	await get_tree().create_timer(0.10).timeout
	assert_false(
		_hud.toast_container.visible,
		"Toast should use configured motion resource timing and finish quickly with custom short presets"
	)

func _create_store() -> M_StateStore:
	var store := M_STATE_STORE.new()
	store.settings = RS_STATE_STORE_SETTINGS.new()
	store.settings.enable_persistence = false
	store.settings.enable_global_settings_persistence = false
	store.settings.enable_debug_logging = false
	store.settings.enable_debug_overlay = false
	store.gameplay_initial_state = RS_GAMEPLAY_INITIAL_STATE.new()
	store.scene_initial_state = RS_SCENE_INITIAL_STATE.new()
	store.navigation_initial_state = RS_NAVIGATION_INITIAL_STATE.new()
	add_child_autofree(store)
	U_ServiceLocator.register(StringName("state_store"), store)
	return store

func _spawn_hud_with_config(config: RS_UIThemeConfig) -> UI_HudController:
	U_UI_THEME_BUILDER.active_config = config
	var hud := HUD_SCENE.instantiate() as UI_HudController
	_apply_theme_to_hud_controls(hud, U_UI_THEME_BUILDER.build_theme(config))
	add_child_autofree(hud)
	await get_tree().process_frame
	return hud

func _apply_theme_to_hud_controls(hud: UI_HudController, theme: Theme) -> void:
	if hud == null or theme == null:
		return
	var hud_margin := hud.get_node_or_null("MarginContainer") as Control
	if hud_margin != null:
		hud_margin.theme = theme
	var signpost_container := hud.get_node_or_null("SignpostPanelContainer") as Control
	if signpost_container != null:
		signpost_container.theme = theme
