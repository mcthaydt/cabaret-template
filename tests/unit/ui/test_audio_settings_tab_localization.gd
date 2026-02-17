extends GutTest

const TAB_SCENE := preload("res://scenes/ui/overlays/settings/ui_audio_settings_tab.tscn")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

var _store: M_StateStore
var _tab: UI_AudioSettingsTab
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
	_store.audio_initial_state = RS_AudioInitialState.new()
	add_child_autofree(_store)
	U_SERVICE_LOCATOR.register(StringName("state_store"), _store)

	_localization_manager = MockLocalizationManager.new()
	add_child_autofree(_localization_manager)
	_localization_manager.translations = {
		&"settings.audio.title": "Audio EN",
		&"settings.audio.label.master_volume": "Master EN",
		&"settings.audio.label.mute": "Mute EN",
		&"common.apply": "Apply EN",
		&"settings.audio.tooltip.master_volume": "Master tooltip EN",
	}
	U_SERVICE_LOCATOR.register(StringName("localization_manager"), _localization_manager)

	_tab = TAB_SCENE.instantiate() as UI_AudioSettingsTab
	add_child_autofree(_tab)
	await get_tree().process_frame

func after_each() -> void:
	U_StateHandoff.clear_all()
	U_SERVICE_LOCATOR.clear()
	_store = null
	_tab = null
	_localization_manager = null

func test_locale_change_relocalizes_audio_labels_and_tooltips() -> void:
	assert_eq(_tab._heading_label.text, "Audio EN")
	assert_eq(_tab._master_label.text, "Master EN")
	assert_eq(_tab._master_mute_toggle.text, "Mute EN")
	assert_eq(_tab._apply_button.text, "Apply EN")
	assert_eq(_tab._master_volume_slider.tooltip_text, "Master tooltip EN")

	_localization_manager.translations[&"settings.audio.title"] = "Audio ES"
	_localization_manager.translations[&"settings.audio.label.master_volume"] = "Maestro"
	_localization_manager.translations[&"settings.audio.label.mute"] = "Silenciar"
	_localization_manager.translations[&"common.apply"] = "Aplicar"
	_localization_manager.translations[&"settings.audio.tooltip.master_volume"] = "Tooltip maestro"

	_tab._on_locale_changed(&"es")
	await get_tree().process_frame

	assert_eq(_tab._heading_label.text, "Audio ES")
	assert_eq(_tab._master_label.text, "Maestro")
	assert_eq(_tab._master_mute_toggle.text, "Silenciar")
	assert_eq(_tab._apply_button.text, "Aplicar")
	assert_eq(_tab._master_volume_slider.tooltip_text, "Tooltip maestro")

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
