extends GutTest

const OVERLAY_SCENE := preload("res://scenes/ui/overlays/ui_touchscreen_settings_overlay.tscn")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

var _store: M_StateStore
var _overlay: UI_TouchscreenSettingsOverlay
var _localization_manager: MockLocalizationManager

func before_each() -> void:
	U_StateHandoff.clear_all()
	U_SERVICE_LOCATOR.clear()

	_store = M_StateStore.new()
	var test_settings := RS_StateStoreSettings.new()
	test_settings.enable_persistence = false
	test_settings.enable_global_settings_persistence = false
	test_settings.enable_debug_logging = false
	test_settings.enable_debug_overlay = false
	_store.settings = test_settings
	_store.gameplay_initial_state = RS_GameplayInitialState.new()
	_store.settings_initial_state = RS_SettingsInitialState.new()
	add_child_autofree(_store)
	U_SERVICE_LOCATOR.register(StringName("state_store"), _store)

	_localization_manager = MockLocalizationManager.new()
	add_child_autofree(_localization_manager)
	_localization_manager.translations = {
		&"settings.touchscreen.title": "Touch EN",
		&"settings.touchscreen.label.joystick_size": "Joystick EN",
		&"settings.touchscreen.label.look_sensitivity": "Look Sens EN",
		&"settings.touchscreen.label.invert_look_y": "Invert Y EN",
		&"settings.touchscreen.button.edit_layout": "Edit EN",
		&"common.apply": "Apply EN",
		&"settings.touchscreen.tooltip.joystick_size": "Joystick tooltip EN",
		&"settings.touchscreen.tooltip.look_sensitivity": "Look tooltip EN",
		&"settings.touchscreen.tooltip.invert_look_y": "Invert tooltip EN",
	}
	U_SERVICE_LOCATOR.register(StringName("localization_manager"), _localization_manager)

	_overlay = OVERLAY_SCENE.instantiate() as UI_TouchscreenSettingsOverlay
	add_child_autofree(_overlay)
	await get_tree().process_frame
	await get_tree().process_frame

func after_each() -> void:
	U_StateHandoff.clear_all()
	U_SERVICE_LOCATOR.clear()
	_store = null
	_overlay = null
	_localization_manager = null

func test_locale_change_relocalizes_touchscreen_labels_and_tooltips() -> void:
	assert_eq(_overlay._title_label.text, "Touch EN")
	assert_eq(_overlay._joystick_size_text_label.text, "Joystick EN")
	assert_eq(_overlay._look_sensitivity_text_label.text, "Look Sens EN")
	assert_eq(_overlay._invert_look_y_text_label.text, "Invert Y EN")
	assert_eq(_overlay._edit_layout_button.text, "Edit EN")
	assert_eq(_overlay._apply_button.text, "Apply EN")
	assert_eq(_overlay._joystick_size_slider.tooltip_text, "Joystick tooltip EN")
	assert_eq(_overlay._look_sensitivity_slider.tooltip_text, "Look tooltip EN")
	assert_eq(_overlay._invert_look_y_check.tooltip_text, "Invert tooltip EN")

	_localization_manager.translations[&"settings.touchscreen.title"] = "Touch ES"
	_localization_manager.translations[&"settings.touchscreen.label.joystick_size"] = "Joystick ES"
	_localization_manager.translations[&"settings.touchscreen.label.look_sensitivity"] = "Mirar ES"
	_localization_manager.translations[&"settings.touchscreen.label.invert_look_y"] = "Invertir Y"
	_localization_manager.translations[&"settings.touchscreen.button.edit_layout"] = "Editar"
	_localization_manager.translations[&"common.apply"] = "Aplicar"
	_localization_manager.translations[&"settings.touchscreen.tooltip.joystick_size"] = "Tooltip joystick"
	_localization_manager.translations[&"settings.touchscreen.tooltip.look_sensitivity"] = "Tooltip mirar"
	_localization_manager.translations[&"settings.touchscreen.tooltip.invert_look_y"] = "Tooltip invertir"

	_overlay._on_locale_changed(&"es")
	await get_tree().process_frame

	assert_eq(_overlay._title_label.text, "Touch ES")
	assert_eq(_overlay._joystick_size_text_label.text, "Joystick ES")
	assert_eq(_overlay._look_sensitivity_text_label.text, "Mirar ES")
	assert_eq(_overlay._invert_look_y_text_label.text, "Invertir Y")
	assert_eq(_overlay._edit_layout_button.text, "Editar")
	assert_eq(_overlay._apply_button.text, "Aplicar")
	assert_eq(_overlay._joystick_size_slider.tooltip_text, "Tooltip joystick")
	assert_eq(_overlay._look_sensitivity_slider.tooltip_text, "Tooltip mirar")
	assert_eq(_overlay._invert_look_y_check.tooltip_text, "Tooltip invertir")

class MockLocalizationManager extends Node:
	var translations: Dictionary = {}

	func register_ui_root(_root: Node) -> void:
		pass

	func unregister_ui_root(_root: Node) -> void:
		pass

	func translate(key: StringName) -> String:
		if translations.has(key):
			return String(translations[key])
		return String(key)
