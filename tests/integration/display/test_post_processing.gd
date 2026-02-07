extends BaseTest

## Integration tests for Display post-processing pipeline (Phase 7)
##
## Validates:
## - Post-process effects enable/disable correctly
## - Effect parameters update shader uniforms
## - Preview overrides persisted settings
## - Clear preview restores persisted settings
## - Overlay visibility responds to navigation shell

const M_DISPLAY_MANAGER := preload("res://scripts/managers/m_display_manager.gd")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_DISPLAY_INITIAL_STATE := preload("res://scripts/resources/state/rs_display_initial_state.gd")

const U_DISPLAY_ACTIONS := preload("res://scripts/state/actions/u_display_actions.gd")
const U_NAVIGATION_ACTIONS := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_POST_PROCESS_LAYER := preload("res://scripts/managers/helpers/u_post_process_layer.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_HANDOFF := preload("res://scripts/state/utils/u_state_handoff.gd")

const POST_PROCESS_OVERLAY_SCENE := preload("res://scenes/ui/overlays/ui_post_process_overlay.tscn")

var _store: M_StateStore
var _display_manager: M_DisplayManager
var _overlay: Node

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	U_STATE_HANDOFF.clear_all()
	await get_tree().process_frame

	_store = _create_state_store()
	add_child_autofree(_store)
	U_SERVICE_LOCATOR.register(StringName("state_store"), _store)

	_overlay = POST_PROCESS_OVERLAY_SCENE.instantiate()
	_overlay.name = "PostProcessOverlay"
	add_child_autofree(_overlay)

	_display_manager = M_DISPLAY_MANAGER.new()
	add_child_autofree(_display_manager)
	await get_tree().process_frame

	_store.dispatch(U_NAVIGATION_ACTIONS.set_shell(StringName("gameplay"), StringName("gameplay_base")))
	await get_tree().physics_frame

func after_each() -> void:
	U_STATE_HANDOFF.clear_all()
	super.after_each()

func _create_state_store() -> M_StateStore:
	var store := M_STATE_STORE.new()
	store.settings = RS_STATE_STORE_SETTINGS.new()
	store.settings.enable_persistence = false
	store.settings.enable_debug_logging = false
	store.settings.enable_debug_overlay = false
	store.display_initial_state = RS_DISPLAY_INITIAL_STATE.new()
	return store

func _get_effect_rect(effect_name: StringName) -> ColorRect:
	var path: Variant = U_POST_PROCESS_LAYER.EFFECT_NODE_PATHS.get(effect_name)
	if path is NodePath:
		return _overlay.get_node_or_null(path) as ColorRect
	return null

func _get_shader_param(rect: ColorRect, param: StringName) -> Variant:
	if rect == null:
		return null
	var material := rect.material
	if material is ShaderMaterial:
		return (material as ShaderMaterial).get_shader_parameter(param)
	return null

func test_film_grain_toggle_updates_visibility() -> void:
	var rect := _get_effect_rect(U_POST_PROCESS_LAYER.EFFECT_FILM_GRAIN)
	assert_not_null(rect, "Film grain rect should exist")
	assert_false(rect.visible, "Film grain should be disabled by default")

	# Enable post-processing master toggle first
	_store.dispatch(U_DISPLAY_ACTIONS.set_post_processing_enabled(true))
	_store.dispatch(U_DISPLAY_ACTIONS.set_film_grain_enabled(true))
	await get_tree().process_frame

	assert_true(rect.visible, "Film grain should be enabled after dispatch")

func test_film_grain_intensity_updates_shader_parameter() -> void:
	var rect := _get_effect_rect(U_POST_PROCESS_LAYER.EFFECT_FILM_GRAIN)
	assert_not_null(rect, "Film grain rect should exist")

	# Enable post-processing and film grain first
	_store.dispatch(U_DISPLAY_ACTIONS.set_post_processing_enabled(true))
	_store.dispatch(U_DISPLAY_ACTIONS.set_film_grain_enabled(true))
	_store.dispatch(U_DISPLAY_ACTIONS.set_film_grain_intensity(0.35))
	await get_tree().process_frame

	assert_almost_eq(float(_get_shader_param(rect, StringName("intensity"))), 0.35, 0.001,
		"Film grain intensity should update shader parameter")

func test_crt_parameters_update_shader_uniforms() -> void:
	var rect := _get_effect_rect(U_POST_PROCESS_LAYER.EFFECT_CRT)
	assert_not_null(rect, "CRT rect should exist")

	# Enable post-processing first
	_store.dispatch(U_DISPLAY_ACTIONS.set_post_processing_enabled(true))
	_store.dispatch(U_DISPLAY_ACTIONS.set_crt_enabled(true))
	_store.dispatch(U_DISPLAY_ACTIONS.set_crt_scanline_intensity(0.55))
	_store.dispatch(U_DISPLAY_ACTIONS.set_crt_curvature(4.0))
	_store.dispatch(U_DISPLAY_ACTIONS.set_crt_chromatic_aberration(0.004))
	await get_tree().process_frame

	assert_true(rect.visible, "CRT should be enabled after dispatch")
	assert_almost_eq(float(_get_shader_param(rect, StringName("scanline_intensity"))), 0.55, 0.001,
		"CRT scanline intensity should update shader parameter")
	assert_almost_eq(float(_get_shader_param(rect, StringName("curvature"))), 4.0, 0.001,
		"CRT curvature should update shader parameter")
	assert_almost_eq(float(_get_shader_param(rect, StringName("chromatic_aberration"))), 0.004, 0.0005,
		"CRT chromatic aberration should update shader parameter")

func test_dither_parameters_update_shader_uniforms() -> void:
	var rect := _get_effect_rect(U_POST_PROCESS_LAYER.EFFECT_DITHER)
	assert_not_null(rect, "Dither rect should exist")

	# Enable post-processing first
	_store.dispatch(U_DISPLAY_ACTIONS.set_post_processing_enabled(true))
	_store.dispatch(U_DISPLAY_ACTIONS.set_dither_enabled(true))
	_store.dispatch(U_DISPLAY_ACTIONS.set_dither_intensity(0.7))
	_store.dispatch(U_DISPLAY_ACTIONS.set_dither_pattern("noise"))
	await get_tree().process_frame

	assert_true(rect.visible, "Dither should be enabled after dispatch")
	assert_almost_eq(float(_get_shader_param(rect, StringName("intensity"))), 0.7, 0.001,
		"Dither intensity should update shader parameter")
	# Dither pattern is now hardcoded to bayer (0) - simplified, no user customization
	assert_eq(int(_get_shader_param(rect, StringName("pattern_mode"))), 0,
		"Dither pattern is always bayer (0) regardless of user selection")

func test_color_blind_shader_mode_updates() -> void:
	var rect := _get_effect_rect(U_POST_PROCESS_LAYER.EFFECT_COLOR_BLIND)
	assert_not_null(rect, "Color blind rect should exist")

	_store.dispatch(U_DISPLAY_ACTIONS.set_color_blind_shader_enabled(true))
	_store.dispatch(U_DISPLAY_ACTIONS.set_color_blind_mode("deuteranopia"))
	await get_tree().process_frame

	assert_true(rect.visible, "Color blind shader should be enabled after dispatch")
	assert_eq(int(_get_shader_param(rect, StringName("mode"))), 1, "Deuteranopia mode should map to 1")

func test_preview_overrides_persisted_settings() -> void:
	var rect := _get_effect_rect(U_POST_PROCESS_LAYER.EFFECT_FILM_GRAIN)
	assert_not_null(rect, "Film grain rect should exist")
	assert_false(rect.visible, "Film grain should be disabled by default")

	_display_manager.set_display_settings_preview({
		"post_processing_enabled": true,
		"film_grain_enabled": true,
		"film_grain_intensity": 0.5,
	})
	await get_tree().process_frame

	assert_true(rect.visible, "Preview should enable film grain")
	assert_almost_eq(float(_get_shader_param(rect, StringName("intensity"))), 0.5, 0.001,
		"Preview should override film grain intensity")

func test_clear_preview_restores_persisted_settings() -> void:
	var rect := _get_effect_rect(U_POST_PROCESS_LAYER.EFFECT_FILM_GRAIN)
	assert_not_null(rect, "Film grain rect should exist")

	# Enable post-processing and film grain first
	_store.dispatch(U_DISPLAY_ACTIONS.set_post_processing_enabled(true))
	_store.dispatch(U_DISPLAY_ACTIONS.set_film_grain_enabled(true))
	await get_tree().process_frame
	assert_true(rect.visible, "Setup: film grain should be enabled from state")

	_display_manager.set_display_settings_preview({
		"post_processing_enabled": true,
		"film_grain_enabled": false
	})
	await get_tree().process_frame
	assert_false(rect.visible, "Preview should disable film grain")

	_display_manager.clear_display_settings_preview()
	await get_tree().process_frame
	assert_true(rect.visible, "Clear preview should restore persisted film grain setting")

func test_overlay_visibility_respects_navigation_shell() -> void:
	var film_layer := _overlay.get_node_or_null("FilmGrainLayer") as CanvasLayer
	assert_not_null(film_layer, "FilmGrainLayer should exist")

	_store.dispatch(U_NAVIGATION_ACTIONS.set_shell(StringName("main_menu"), StringName("settings_menu")))
	await get_tree().physics_frame
	assert_false(film_layer.visible, "Overlay should hide when shell is not gameplay")

	_store.dispatch(U_NAVIGATION_ACTIONS.set_shell(StringName("gameplay"), StringName("gameplay_base")))
	await get_tree().physics_frame
	assert_true(film_layer.visible, "Overlay should show when shell is gameplay")

func test_quality_preset_low_disables_post_processing_effects() -> void:
	var rect := _get_effect_rect(U_POST_PROCESS_LAYER.EFFECT_FILM_GRAIN)
	assert_not_null(rect, "Film grain rect should exist")

	# Enable post-processing and film grain first
	_store.dispatch(U_DISPLAY_ACTIONS.set_post_processing_enabled(true))
	_store.dispatch(U_DISPLAY_ACTIONS.set_film_grain_enabled(true))
	await get_tree().process_frame
	assert_true(rect.visible, "Setup: film grain should be enabled from state")

	# Disable post-processing (simulating what low quality preset would do)
	_store.dispatch(U_DISPLAY_ACTIONS.set_post_processing_enabled(false))
	await get_tree().process_frame
	assert_false(rect.visible, "Disabling post-processing should hide all effects")

	# Re-enable post-processing
	_store.dispatch(U_DISPLAY_ACTIONS.set_post_processing_enabled(true))
	await get_tree().process_frame
	assert_true(rect.visible, "Re-enabling post-processing should reapply effects")
