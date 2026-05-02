extends BaseTest

## Integration tests for U_DisplayColorGradingApplier
##
## Validates:
## - scene/swapped action triggers color grading load for the target scene
## - Known scene loads its configured grade (exposure, contrast, filter_mode)
## - Unknown scene falls back to the neutral grade (default values)
## - ColorGradingLayer is created under PostProcessOverlay after first apply
## - Shader uniforms on ColorGradingRect reflect the loaded grade

const M_DISPLAY_MANAGER := preload("res://scripts/core/managers/m_display_manager.gd")
const M_STATE_STORE := preload("res://scripts/core/state/m_state_store.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/core/resources/state/rs_state_store_settings.gd")
const RS_DISPLAY_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_display_initial_state.gd")

const U_COLOR_GRADING_REGISTRY := preload("res://scripts/core/managers/helpers/display/u_color_grading_registry.gd")
const U_COLOR_GRADING_SELECTORS := preload("res://scripts/core/state/selectors/u_color_grading_selectors.gd")
const U_NAVIGATION_ACTIONS := preload("res://scripts/core/state/actions/u_navigation_actions.gd")
const U_SCENE_ACTIONS := preload("res://scripts/core/state/actions/u_scene_actions.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_HANDOFF := preload("res://scripts/core/state/utils/u_state_handoff.gd")

const POST_PROCESS_OVERLAY_SCENE := preload("res://scenes/core/ui/overlays/ui_post_process_overlay.tscn")

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

	_store.dispatch(U_NAVIGATION_ACTIONS.set_shell(StringName("gameplay"), StringName("demo_room")))
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


func _get_color_grading_rect() -> ColorRect:
	var layer := _overlay.find_child("ColorGradingLayer", false, false) as CanvasLayer
	if layer == null:
		return null
	return layer.find_child("ColorGradingRect", false, false) as ColorRect


func _get_color_grading_param(param: StringName) -> Variant:
	var rect := _get_color_grading_rect()
	if rect == null:
		return null
	var material := rect.material as ShaderMaterial
	if material == null:
		return null
	return material.get_shader_parameter(param)


func _get_expected_alleyway_grade_dict() -> Dictionary:
	var grade := U_COLOR_GRADING_REGISTRY.get_color_grading_for_scene(StringName("demo_room"))
	if grade == null:
		return {}
	return grade.to_dictionary()


# --- Layer creation ---

func test_color_grading_layer_created_under_post_process_overlay() -> void:
	var layer := _overlay.find_child("ColorGradingLayer", false, false)
	assert_not_null(layer, "ColorGradingLayer should be created under PostProcessOverlay")


func test_color_grading_rect_has_shader_material() -> void:
	var rect := _get_color_grading_rect()
	assert_not_null(rect, "ColorGradingRect should exist")
	assert_true(rect.material is ShaderMaterial,
		"ColorGradingRect should have a ShaderMaterial")


# --- Known scene grade load (source-derived from alleyway grade resource) ---

func test_scene_swap_loads_filter_mode_for_known_scene() -> void:
	_store.dispatch(U_SCENE_ACTIONS.scene_swapped(StringName("demo_room")))
	await get_tree().process_frame

	var expected_grade: Dictionary = _get_expected_alleyway_grade_dict()
	assert_false(expected_grade.is_empty(), "Expected alleyway color grading should be available")
	var state := _store.get_state()
	assert_eq(
		U_COLOR_GRADING_SELECTORS.get_filter_mode(state),
		int(expected_grade.get("color_grading_filter_mode", 0)),
		"scene/swapped 'alleyway' should load the configured filter_mode"
	)


func test_scene_swap_loads_exposure_for_known_scene() -> void:
	_store.dispatch(U_SCENE_ACTIONS.scene_swapped(StringName("demo_room")))
	await get_tree().process_frame

	var expected_grade: Dictionary = _get_expected_alleyway_grade_dict()
	assert_false(expected_grade.is_empty(), "Expected alleyway color grading should be available")
	var state := _store.get_state()
	assert_almost_eq(
		U_COLOR_GRADING_SELECTORS.get_exposure(state),
		float(expected_grade.get("color_grading_exposure", 0.0)),
		0.001,
		"scene/swapped 'alleyway' should load the configured exposure"
	)


func test_scene_swap_loads_contrast_for_known_scene() -> void:
	_store.dispatch(U_SCENE_ACTIONS.scene_swapped(StringName("demo_room")))
	await get_tree().process_frame

	var expected_grade: Dictionary = _get_expected_alleyway_grade_dict()
	assert_false(expected_grade.is_empty(), "Expected alleyway color grading should be available")
	var state := _store.get_state()
	assert_almost_eq(
		U_COLOR_GRADING_SELECTORS.get_contrast(state),
		float(expected_grade.get("color_grading_contrast", 1.0)),
		0.001,
		"scene/swapped 'alleyway' should load the configured contrast"
	)


func test_scene_swap_populates_all_color_grading_keys_in_state() -> void:
	_store.dispatch(U_SCENE_ACTIONS.scene_swapped(StringName("demo_room")))
	await get_tree().process_frame

	var state := _store.get_state()
	var color_grading_settings := U_COLOR_GRADING_SELECTORS.get_color_grading_settings(state)
	assert_gt(color_grading_settings.size(), 0,
		"scene/swapped should populate color_grading_ keys in display state")


# --- Unknown scene falls back to neutral grade ---

func test_scene_swap_unknown_scene_loads_neutral_filter_mode() -> void:
	_store.dispatch(U_SCENE_ACTIONS.scene_swapped(StringName("unknown_scene_xyz")))
	await get_tree().process_frame

	var state := _store.get_state()
	assert_eq(U_COLOR_GRADING_SELECTORS.get_filter_mode(state), 0,
		"Unknown scene should fall back to neutral filter_mode 0")


func test_scene_swap_unknown_scene_loads_neutral_exposure() -> void:
	_store.dispatch(U_SCENE_ACTIONS.scene_swapped(StringName("unknown_scene_xyz")))
	await get_tree().process_frame

	var state := _store.get_state()
	assert_almost_eq(U_COLOR_GRADING_SELECTORS.get_exposure(state), 0.0, 0.001,
		"Unknown scene should fall back to neutral exposure 0.0")


func test_scene_swap_unknown_scene_still_populates_color_grading_state() -> void:
	_store.dispatch(U_SCENE_ACTIONS.scene_swapped(StringName("unknown_scene_xyz")))
	await get_tree().process_frame

	var state := _store.get_state()
	var color_grading_settings := U_COLOR_GRADING_SELECTORS.get_color_grading_settings(state)
	assert_gt(color_grading_settings.size(), 0,
		"Unknown scene should still dispatch load_scene_grade with neutral values")


# --- Shader uniform propagation ---

func test_scene_swap_updates_shader_exposure_uniform() -> void:
	_store.dispatch(U_SCENE_ACTIONS.scene_swapped(StringName("demo_room")))
	await get_tree().process_frame

	var expected_grade: Dictionary = _get_expected_alleyway_grade_dict()
	assert_false(expected_grade.is_empty(), "Expected alleyway color grading should be available")
	var exposure: Variant = _get_color_grading_param(StringName("exposure"))
	assert_not_null(exposure, "ColorGradingRect shader should have an 'exposure' parameter")
	assert_almost_eq(
		float(exposure),
		float(expected_grade.get("color_grading_exposure", 0.0)),
		0.001,
		"Shader 'exposure' uniform should reflect alleyway grade"
	)


func test_scene_swap_updates_shader_filter_mode_uniform() -> void:
	_store.dispatch(U_SCENE_ACTIONS.scene_swapped(StringName("demo_room")))
	await get_tree().process_frame

	var expected_grade: Dictionary = _get_expected_alleyway_grade_dict()
	assert_false(expected_grade.is_empty(), "Expected alleyway color grading should be available")
	var filter_mode: Variant = _get_color_grading_param(StringName("filter_mode"))
	assert_not_null(filter_mode, "ColorGradingRect shader should have a 'filter_mode' parameter")
	assert_eq(
		int(filter_mode),
		int(expected_grade.get("color_grading_filter_mode", 0)),
		"Shader 'filter_mode' uniform should reflect alleyway grade"
	)
