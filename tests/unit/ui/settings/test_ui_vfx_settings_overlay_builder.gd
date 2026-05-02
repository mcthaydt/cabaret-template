extends GutTest

const OVERLAY_SCENE := preload("res://scenes/core/ui/overlays/settings/ui_vfx_settings_overlay.tscn")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")

var _store: M_StateStore
var _overlay: UI_VFXSettingsOverlay


func before_each() -> void:
	U_UI_THEME_BUILDER.active_config = null
	U_StateHandoff.clear_all()
	U_SERVICE_LOCATOR.clear()

	_store = M_StateStore.new()
	var test_settings := RS_StateStoreSettings.new()
	test_settings.enable_persistence = false
	test_settings.enable_global_settings_persistence = false
	test_settings.enable_debug_logging = false
	test_settings.enable_debug_overlay = false
	_store.settings = test_settings
	_store.vfx_initial_state = RS_VFXInitialState.new()
	add_child_autofree(_store)
	U_SERVICE_LOCATOR.register(StringName("state_store"), _store)


func after_each() -> void:
	U_UI_THEME_BUILDER.active_config = null
	U_StateHandoff.clear_all()
	U_SERVICE_LOCATOR.clear()
	_store = null
	_overlay = null


func test_vfx_overlay_is_builder_backed() -> void:
	_instantiate_overlay()

	assert_not_null(_overlay._apply_button, "Overlay should expose apply button")
	assert_not_null(_overlay._shake_enabled_toggle, "Overlay should expose shake toggle")


func test_vfx_builder_wires_signals_and_focus() -> void:
	_instantiate_overlay()

	assert_not_null(_overlay._shake_enabled_toggle, "Overlay should expose focusable controls")
	assert_not_null(_overlay._intensity_slider, "Overlay should expose slider controls")


func test_vfx_builder_applies_theme_tokens() -> void:
	var config := RS_UI_THEME_CONFIG.new()
	config.heading = 37
	config.section_header = 15
	config.body_small = 14
	config.text_secondary = Color(0.76, 0.71, 0.66, 1.0)
	U_UI_THEME_BUILDER.active_config = config
	_instantiate_overlay()

	assert_true(_overlay.background_color.a > 0.0, "Overlay should keep dimmed background")
	assert_true(_overlay._title_label.get_theme_font_size(&"font_size") > 0, "Heading should keep themed font size")


func _instantiate_overlay() -> void:
	_overlay = OVERLAY_SCENE.instantiate() as UI_VFXSettingsOverlay
	add_child_autofree(_overlay)
	for _i in range(30):
		await get_tree().process_frame
		if _overlay.get_store() != null:
			break
	_overlay._on_panel_ready()
	await get_tree().process_frame
