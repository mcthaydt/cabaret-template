extends BaseTest

## Integration tests for Display post-processing pipeline (Phase 7)
##
## Validates:
## - Post-process effects enable/disable correctly via grain+dither shader
## - Effect parameters update shader uniforms
## - Preview overrides persisted settings
## - Clear preview restores persisted settings
## - Overlay visibility responds to navigation shell

const M_DISPLAY_MANAGER := preload("res://scripts/core/managers/m_display_manager.gd")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/core/resources/state/rs_state_store_settings.gd")
const RS_DISPLAY_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_display_initial_state.gd")

const U_DISPLAY_ACTIONS := preload("res://scripts/state/actions/u_display_actions.gd")
const U_NAVIGATION_ACTIONS := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_POST_PROCESS_LAYER := preload("res://scripts/core/managers/helpers/display/u_post_process_layer.gd")
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
	U_SERVICE_LOCATOR.register(StringName("post_process_overlay"), _overlay)

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

func _get_grain_dither_rect() -> ColorRect:
	var path: Variant = U_POST_PROCESS_LAYER.EFFECT_NODE_PATHS.get(U_POST_PROCESS_LAYER.EFFECT_GRAIN_DITHER)
	if path is NodePath:
		return _overlay.get_node_or_null(path) as ColorRect
	return null

func _get_color_blind_rect() -> ColorRect:
	var path: Variant = U_POST_PROCESS_LAYER.EFFECT_NODE_PATHS.get(U_POST_PROCESS_LAYER.EFFECT_COLOR_BLIND)
	if path is NodePath:
		return _overlay.get_node_or_null(path) as ColorRect
	return null

func _get_grain_dither_param(param: StringName) -> Variant:
	var rect := _get_grain_dither_rect()
	if rect == null:
		return null
	var material := rect.material
	if material is ShaderMaterial:
		return (material as ShaderMaterial).get_shader_parameter(param)
	return null

func _get_shader_param(rect: ColorRect, param: StringName) -> Variant:
	if rect == null:
		return null
	var material := rect.material
	if material is ShaderMaterial:
		return (material as ShaderMaterial).get_shader_parameter(param)
	return null

func test_film_grain_toggle_updates_grain_dither_rect_visibility() -> void:
	var rect := _get_grain_dither_rect()
	assert_not_null(rect, "Grain+dither rect should exist")
	assert_false(rect.visible, "Grain+dither rect should be hidden by default")

	# Enable post-processing master toggle first
	_store.dispatch(U_DISPLAY_ACTIONS.set_post_processing_enabled(true))
	_store.dispatch(U_DISPLAY_ACTIONS.set_film_grain_enabled(true))
	await get_tree().process_frame

	assert_true(rect.visible, "Grain+dither rect should be visible when film grain is enabled")
	assert_eq(int(_get_grain_dither_param(StringName("film_grain_enabled"))), 1,
		"film_grain_enabled flag should be 1 in grain+dither shader")

func test_film_grain_intensity_updates_shader_parameter() -> void:
	var rect := _get_grain_dither_rect()
	assert_not_null(rect, "Grain+dither rect should exist")

	_store.dispatch(U_DISPLAY_ACTIONS.set_post_processing_enabled(true))
	_store.dispatch(U_DISPLAY_ACTIONS.set_film_grain_enabled(true))
	_store.dispatch(U_DISPLAY_ACTIONS.set_film_grain_intensity(0.35))
	await get_tree().process_frame

	assert_almost_eq(float(_get_grain_dither_param(StringName("fg_intensity"))), 0.35, 0.001,
		"Film grain intensity should update grain+dither shader parameter")

func test_dither_parameters_update_shader_uniforms() -> void:
	var rect := _get_grain_dither_rect()
	assert_not_null(rect, "Grain+dither rect should exist")

	_store.dispatch(U_DISPLAY_ACTIONS.set_post_processing_enabled(true))
	_store.dispatch(U_DISPLAY_ACTIONS.set_dither_enabled(true))
	_store.dispatch(U_DISPLAY_ACTIONS.set_dither_intensity(0.7))
	await get_tree().process_frame

	assert_true(rect.visible, "Grain+dither rect should be visible when dither is enabled")
	assert_eq(int(_get_grain_dither_param(StringName("dither_enabled"))), 1,
		"dither_enabled flag should be 1 in grain+dither shader")
	assert_almost_eq(float(_get_grain_dither_param(StringName("dither_intensity"))), 0.7, 0.001,
		"Dither intensity should update grain+dither shader parameter")

func test_color_blind_shader_mode_updates() -> void:
	var rect := _get_color_blind_rect()
	assert_not_null(rect, "Color blind rect should exist")

	_store.dispatch(U_DISPLAY_ACTIONS.set_color_blind_shader_enabled(true))
	_store.dispatch(U_DISPLAY_ACTIONS.set_color_blind_mode("deuteranopia"))
	await get_tree().process_frame

	assert_true(rect.visible, "Color blind shader should be enabled after dispatch")
	assert_eq(int(_get_shader_param(rect, StringName("mode"))), 1, "Deuteranopia mode should map to 1")

func test_preview_overrides_persisted_settings() -> void:
	var rect := _get_grain_dither_rect()
	assert_not_null(rect, "Grain+dither rect should exist")
	assert_false(rect.visible, "Grain+dither rect should be hidden by default")

	_display_manager.set_display_settings_preview({
		"post_processing_enabled": true,
		"film_grain_enabled": true,
		"film_grain_intensity": 0.5,
	})
	await get_tree().process_frame

	assert_true(rect.visible, "Preview should enable grain+dither rect")
	assert_almost_eq(float(_get_grain_dither_param(StringName("fg_intensity"))), 0.5, 0.001,
		"Preview should override film grain intensity")

func test_clear_preview_restores_persisted_settings() -> void:
	var rect := _get_grain_dither_rect()
	assert_not_null(rect, "Grain+dither rect should exist")

	# Enable post-processing and film grain first
	_store.dispatch(U_DISPLAY_ACTIONS.set_post_processing_enabled(true))
	_store.dispatch(U_DISPLAY_ACTIONS.set_film_grain_enabled(true))
	await get_tree().process_frame
	assert_true(rect.visible, "Setup: grain+dither rect should be visible from state")

	_display_manager.set_display_settings_preview({
		"post_processing_enabled": true,
		"film_grain_enabled": false
	})
	await get_tree().process_frame
	assert_false(rect.visible, "Preview should disable grain+dither rect when no effects enabled")

	_display_manager.clear_display_settings_preview()
	await get_tree().process_frame
	assert_true(rect.visible, "Clear preview should restore persisted film grain setting")

func test_overlay_visibility_respects_navigation_shell() -> void:
	var grain_dither_layer := _overlay.get_node_or_null("GrainDitherLayer") as CanvasLayer
	assert_not_null(grain_dither_layer, "GrainDitherLayer should exist")

	_store.dispatch(U_NAVIGATION_ACTIONS.set_shell(StringName("main_menu"), StringName("settings_menu")))
	await get_tree().physics_frame
	assert_false(grain_dither_layer.visible, "Overlay should hide when shell is not gameplay")

	_store.dispatch(U_NAVIGATION_ACTIONS.set_shell(StringName("gameplay"), StringName("gameplay_base")))
	await get_tree().physics_frame
	assert_true(grain_dither_layer.visible, "Overlay should show when shell is gameplay")

func test_quality_preset_low_disables_post_processing_effects() -> void:
	var rect := _get_grain_dither_rect()
	assert_not_null(rect, "Grain+dither rect should exist")

	# Enable post-processing and film grain first
	_store.dispatch(U_DISPLAY_ACTIONS.set_post_processing_enabled(true))
	_store.dispatch(U_DISPLAY_ACTIONS.set_film_grain_enabled(true))
	await get_tree().process_frame
	assert_true(rect.visible, "Setup: grain+dither rect should be visible from state")

	# Disable post-processing (simulating what low quality preset would do)
	_store.dispatch(U_DISPLAY_ACTIONS.set_post_processing_enabled(false))
	await get_tree().process_frame
	assert_false(rect.visible, "Disabling post-processing should hide grain+dither rect")

	# Re-enable post-processing
	_store.dispatch(U_DISPLAY_ACTIONS.set_post_processing_enabled(true))
	await get_tree().process_frame
	assert_true(rect.visible, "Re-enabling post-processing should reapply effects")

func test_multiple_effects_share_single_grain_dither_rect() -> void:
	var rect := _get_grain_dither_rect()
	assert_not_null(rect, "Grain+dither rect should exist")

	_store.dispatch(U_DISPLAY_ACTIONS.set_post_processing_enabled(true))
	_store.dispatch(U_DISPLAY_ACTIONS.set_film_grain_enabled(true))
	_store.dispatch(U_DISPLAY_ACTIONS.set_dither_enabled(true))
	await get_tree().process_frame

	assert_true(rect.visible, "Grain+dither rect should be visible with all effects on")
	assert_eq(int(_get_grain_dither_param(StringName("film_grain_enabled"))), 1)
	assert_eq(int(_get_grain_dither_param(StringName("dither_enabled"))), 1)

func test_scanlines_toggle_updates_shader_parameter() -> void:
	_store.dispatch(U_DISPLAY_ACTIONS.set_post_processing_enabled(true))
	_store.dispatch(U_DISPLAY_ACTIONS.set_scanlines_enabled(true))
	await get_tree().process_frame

	var rect := _get_grain_dither_rect()
	assert_not_null(rect, "Grain+dither rect should exist")
	assert_true(rect.visible, "Grain+dither rect should be visible when scanlines enabled")
	assert_eq(int(_get_grain_dither_param(StringName("scanlines_enabled"))), 1,
		"scanlines_enabled flag should be 1 in grain+dither shader")

func test_line_mask_intensity_and_count_update_shader_parameters() -> void:
	_store.dispatch(U_DISPLAY_ACTIONS.set_post_processing_enabled(true))
	_store.dispatch(U_DISPLAY_ACTIONS.set_scanlines_enabled(true))
	_store.dispatch(U_DISPLAY_ACTIONS.set_line_mask_intensity(0.4))
	_store.dispatch(U_DISPLAY_ACTIONS.set_scanline_count(720.0))
	await get_tree().process_frame

	assert_almost_eq(float(_get_grain_dither_param(StringName("line_mask_intensity"))), 0.4, 0.001,
		"line_mask_intensity should update shader parameter")
	assert_almost_eq(float(_get_grain_dither_param(StringName("scanline_count"))), 720.0, 0.1,
		"scanline_count should update shader parameter")