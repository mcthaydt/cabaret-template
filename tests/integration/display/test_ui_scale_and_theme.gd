extends BaseTest

## Integration tests for UI scale + theme binding (CI-safe)
##
## Validates:
## - UI scale updates registered controls from Redux state
## - High contrast palette updates theme text color on registered UI

const M_DISPLAY_MANAGER := preload("res://scripts/managers/m_display_manager.gd")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_DISPLAY_INITIAL_STATE := preload("res://scripts/resources/state/rs_display_initial_state.gd")
const RS_UI_COLOR_PALETTE := preload("res://scripts/resources/ui/rs_ui_color_palette.gd")

const U_DISPLAY_ACTIONS := preload("res://scripts/state/actions/u_display_actions.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_HANDOFF := preload("res://scripts/state/utils/u_state_handoff.gd")

const POST_PROCESS_OVERLAY_SCENE := preload("res://scenes/ui/overlays/ui_post_process_overlay.tscn")

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

func test_ui_scale_updates_registered_controls_from_state() -> void:
	var root := Control.new()
	add_child_autofree(root)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 20)
	root.add_child(label)
	_display_manager.register_ui_scale_root(root)

	_store.dispatch(U_DISPLAY_ACTIONS.set_ui_scale(1.3))
	await get_tree().process_frame
	assert_eq(label.get_theme_font_size("font_size"), 26, "UI scale 1.3 should scale font size to 26")

	_store.dispatch(U_DISPLAY_ACTIONS.set_ui_scale(0.8))
	await get_tree().process_frame
	assert_eq(label.get_theme_font_size("font_size"), 16, "UI scale 0.8 should scale font size to 16")

func test_high_contrast_palette_updates_theme_text_color() -> void:
	var root := Control.new()
	add_child_autofree(root)
	var label := Label.new()
	root.add_child(label)
	_display_manager.register_ui_scale_root(root)

	_store.dispatch(U_DISPLAY_ACTIONS.set_high_contrast_enabled(true))
	await get_tree().process_frame

	var palette := _display_manager.get_active_palette()
	assert_not_null(palette, "Palette should be available after high contrast toggle")
	assert_true(palette is RS_UI_COLOR_PALETTE, "Palette should be RS_UIColorPalette")
	var typed_palette := palette as RS_UI_COLOR_PALETTE
	assert_eq(typed_palette.palette_id, StringName("normal_high_contrast"), "Normal high contrast palette should be active when color blind mode is normal")

	assert_true(
		label.get_theme_color("font_color").is_equal_approx(typed_palette.text),
		"High contrast should update label font color"
	)
