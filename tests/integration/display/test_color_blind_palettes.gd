extends BaseTest

## Integration tests for color blind palette application (Phase 7)
##
## Validates:
## - All palettes load through DisplayManager
## - Palette switching emits active_palette_changed
## - High contrast mode overrides color blind mode

const M_DISPLAY_MANAGER := preload("res://scripts/managers/m_display_manager.gd")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_DISPLAY_INITIAL_STATE := preload("res://scripts/resources/state/rs_display_initial_state.gd")
const RS_UI_COLOR_PALETTE := preload("res://scripts/resources/ui/rs_ui_color_palette.gd")

const U_DISPLAY_ACTIONS := preload("res://scripts/state/actions/u_display_actions.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_HANDOFF := preload("res://scripts/state/utils/u_state_handoff.gd")

const POST_PROCESS_OVERLAY_SCENE := preload("res://scenes/ui/overlays/ui_post_process_overlay.tscn")

const PALETTE_NORMAL_PATH := "res://resources/ui_themes/cfg_palette_normal.tres"
const PALETTE_DEUTER_PATH := "res://resources/ui_themes/cfg_palette_deuteranopia.tres"
const PALETTE_PROTAN_PATH := "res://resources/ui_themes/cfg_palette_protanopia.tres"
const PALETTE_TRITAN_PATH := "res://resources/ui_themes/cfg_palette_tritanopia.tres"

var _store: M_StateStore
var _display_manager: M_DisplayManager
var _post_process_overlay: Node

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	U_STATE_HANDOFF.clear_all()
	await get_tree().process_frame

	_store = _create_state_store()
	add_child_autofree(_store)
	U_SERVICE_LOCATOR.register(StringName("state_store"), _store)

	_post_process_overlay = POST_PROCESS_OVERLAY_SCENE.instantiate()
	_post_process_overlay.name = "PostProcessOverlay"
	add_child_autofree(_post_process_overlay)

	_display_manager = M_DISPLAY_MANAGER.new()
	add_child_autofree(_display_manager)
	await get_tree().process_frame

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

func _assert_palette_path(palette: Resource, expected_path: String, message: String) -> void:
	assert_not_null(palette, message)
	assert_true(palette is RS_UI_COLOR_PALETTE, "Palette should use RS_UIColorPalette script")
	assert_eq(palette.resource_path, expected_path, message)

func test_normal_palette_loads_by_default() -> void:
	var palette := _display_manager.get_active_palette()
	_assert_palette_path(palette, PALETTE_NORMAL_PATH, "Normal palette should load by default")

func test_deuteranopia_palette_loads() -> void:
	_store.dispatch(U_DISPLAY_ACTIONS.set_color_blind_mode("deuteranopia"))
	await get_tree().process_frame

	var palette := _display_manager.get_active_palette()
	_assert_palette_path(palette, PALETTE_DEUTER_PATH, "Deuteranopia palette should load")

func test_protanopia_palette_loads() -> void:
	_store.dispatch(U_DISPLAY_ACTIONS.set_color_blind_mode("protanopia"))
	await get_tree().process_frame

	var palette := _display_manager.get_active_palette()
	_assert_palette_path(palette, PALETTE_PROTAN_PATH, "Protanopia palette should load")

func test_tritanopia_palette_loads() -> void:
	_store.dispatch(U_DISPLAY_ACTIONS.set_color_blind_mode("tritanopia"))
	await get_tree().process_frame

	var palette := _display_manager.get_active_palette()
	_assert_palette_path(palette, PALETTE_TRITAN_PATH, "Tritanopia palette should load")

func test_normal_high_contrast_palette_loads_and_emits_signal() -> void:
	_display_manager.get_active_palette()
	var palette_manager: RefCounted = _display_manager.get("_palette_manager")
	assert_not_null(palette_manager, "Palette manager should be created")

	var emitted := [0]
	palette_manager.active_palette_changed.connect(func(_palette: Resource) -> void:
		emitted[0] += 1
	)

	_store.dispatch(U_DISPLAY_ACTIONS.set_high_contrast_enabled(true))
	await get_tree().process_frame

	var palette := _display_manager.get_active_palette()
	_assert_palette_path(palette, "res://resources/ui_themes/cfg_palette_normal_high_contrast.tres", "Normal high contrast palette should load")
	assert_eq(emitted[0], 1, "Palette manager should emit active_palette_changed on high contrast switch")

func test_deuteranopia_high_contrast_palette_loads() -> void:
	_store.dispatch(U_DISPLAY_ACTIONS.set_color_blind_mode("deuteranopia"))
	_store.dispatch(U_DISPLAY_ACTIONS.set_high_contrast_enabled(true))
	await get_tree().process_frame

	var palette := _display_manager.get_active_palette()
	_assert_palette_path(palette, "res://resources/ui_themes/cfg_palette_deuteranopia_high_contrast.tres", "Deuteranopia high contrast palette should load")

func test_protanopia_high_contrast_palette_loads() -> void:
	_store.dispatch(U_DISPLAY_ACTIONS.set_color_blind_mode("protanopia"))
	_store.dispatch(U_DISPLAY_ACTIONS.set_high_contrast_enabled(true))
	await get_tree().process_frame

	var palette := _display_manager.get_active_palette()
	_assert_palette_path(palette, "res://resources/ui_themes/cfg_palette_protanopia_high_contrast.tres", "Protanopia high contrast palette should load")

func test_tritanopia_high_contrast_palette_loads() -> void:
	_store.dispatch(U_DISPLAY_ACTIONS.set_color_blind_mode("tritanopia"))
	_store.dispatch(U_DISPLAY_ACTIONS.set_high_contrast_enabled(true))
	await get_tree().process_frame

	var palette := _display_manager.get_active_palette()
	_assert_palette_path(palette, "res://resources/ui_themes/cfg_palette_tritanopia_high_contrast.tres", "Tritanopia high contrast palette should load")
