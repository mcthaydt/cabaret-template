extends GutTest

const TAB_SCENE := preload("res://scenes/ui/overlays/settings/ui_display_settings_tab.tscn")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

var _store: M_StateStore
var _tab: UI_DisplaySettingsTab
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
	_store.display_initial_state = RS_DisplayInitialState.new()
	add_child_autofree(_store)
	U_SERVICE_LOCATOR.register(StringName("state_store"), _store)

	_localization_manager = MockLocalizationManager.new()
	add_child_autofree(_localization_manager)
	_localization_manager.translations = {
		&"settings.display.title": "Display EN",
		&"common.apply": "Apply EN",
		&"settings.display.option.window_mode.windowed": "Windowed EN",
	}
	U_SERVICE_LOCATOR.register(StringName("localization_manager"), _localization_manager)

	_tab = TAB_SCENE.instantiate() as UI_DisplaySettingsTab
	add_child_autofree(_tab)
	await get_tree().process_frame

func after_each() -> void:
	U_StateHandoff.clear_all()
	U_SERVICE_LOCATOR.clear()
	_store = null
	_tab = null
	_localization_manager = null

func test_locale_change_relocalizes_labels_and_option_entries() -> void:
	assert_eq(_tab._heading_label.text, "Display EN")
	assert_eq(_tab._apply_button.text, "Apply EN")

	var windowed_index: int = _tab._window_mode_values.find("windowed")
	assert_true(windowed_index >= 0, "Window mode option should include windowed id")
	assert_eq(_tab._window_mode_option.get_item_text(windowed_index), "Windowed EN")

	_localization_manager.translations[&"settings.display.title"] = "Pantalla"
	_localization_manager.translations[&"common.apply"] = "Aplicar"
	_localization_manager.translations[&"settings.display.option.window_mode.windowed"] = "Ventana"

	_tab._on_locale_changed(&"es")
	await get_tree().process_frame

	assert_eq(_tab._heading_label.text, "Pantalla")
	assert_eq(_tab._apply_button.text, "Aplicar")
	assert_eq(_tab._window_mode_option.get_item_text(windowed_index), "Ventana")

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
