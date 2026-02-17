extends GutTest

const OVERLAY_SCENE := preload("res://scenes/ui/overlays/ui_gamepad_settings_overlay.tscn")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

var _store: M_StateStore
var _overlay: UI_GamepadSettingsOverlay
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
		&"settings.gamepad.title": "Gamepad EN",
		&"settings.gamepad.label.left_deadzone": "Left EN",
		&"settings.gamepad.preview.enter": "Press EN",
		&"common.apply": "Apply EN",
		&"settings.gamepad.tooltip.left_deadzone": "Left tooltip EN",
	}
	U_SERVICE_LOCATOR.register(StringName("localization_manager"), _localization_manager)

	_overlay = OVERLAY_SCENE.instantiate() as UI_GamepadSettingsOverlay
	add_child_autofree(_overlay)
	await get_tree().process_frame
	await get_tree().process_frame

func after_each() -> void:
	U_StateHandoff.clear_all()
	U_SERVICE_LOCATOR.clear()
	_store = null
	_overlay = null
	_localization_manager = null

func test_locale_change_relocalizes_gamepad_labels_and_tooltips() -> void:
	var enter_prompt_label := _overlay._preview_enter_prompt.get_node("Text") as Label

	assert_eq(_overlay._title_label.text, "Gamepad EN")
	assert_eq(_overlay._left_deadzone_label.text, "Left EN")
	assert_eq(_overlay._apply_button.text, "Apply EN")
	assert_eq(_overlay._left_slider.tooltip_text, "Left tooltip EN")
	assert_eq(enter_prompt_label.text, "Press EN")

	_localization_manager.translations[&"settings.gamepad.title"] = "Gamepad ES"
	_localization_manager.translations[&"settings.gamepad.label.left_deadzone"] = "Izquierda"
	_localization_manager.translations[&"settings.gamepad.preview.enter"] = "Presiona ES"
	_localization_manager.translations[&"common.apply"] = "Aplicar"
	_localization_manager.translations[&"settings.gamepad.tooltip.left_deadzone"] = "Tooltip izquierdo"

	_overlay._on_locale_changed(&"es")
	await get_tree().process_frame

	assert_eq(_overlay._title_label.text, "Gamepad ES")
	assert_eq(_overlay._left_deadzone_label.text, "Izquierda")
	assert_eq(_overlay._apply_button.text, "Aplicar")
	assert_eq(_overlay._left_slider.tooltip_text, "Tooltip izquierdo")
	assert_eq(enter_prompt_label.text, "Presiona ES")

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
