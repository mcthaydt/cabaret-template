extends GutTest

const OVERLAY_SCENE := preload("res://scenes/ui/overlays/settings/ui_vfx_settings_overlay.tscn")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

var _store: M_StateStore
var _overlay: UI_VFXSettingsOverlay
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
	_store.vfx_initial_state = RS_VFXInitialState.new()
	add_child_autofree(_store)
	U_SERVICE_LOCATOR.register(StringName("state_store"), _store)

	_localization_manager = MockLocalizationManager.new()
	add_child_autofree(_localization_manager)
	_localization_manager.translations = {
		&"settings.vfx.title": "VFX EN",
		&"settings.vfx.label.screen_shake": "Screen Shake EN",
		&"common.apply": "Apply EN",
		&"settings.vfx.tooltip.shake_intensity": "Shake tooltip EN",
	}
	U_SERVICE_LOCATOR.register(StringName("localization_manager"), _localization_manager)

	_overlay = OVERLAY_SCENE.instantiate() as UI_VFXSettingsOverlay
	add_child_autofree(_overlay)
	await get_tree().process_frame
	await get_tree().process_frame

func after_each() -> void:
	U_StateHandoff.clear_all()
	U_SERVICE_LOCATOR.clear()
	_store = null
	_overlay = null
	_localization_manager = null

func test_locale_change_relocalizes_vfx_labels_and_tooltips() -> void:
	assert_eq(_overlay._title_label.text, "VFX EN")
	assert_eq(_overlay._shake_enabled_label.text, "Screen Shake EN")
	assert_eq(_overlay._apply_button.text, "Apply EN")
	assert_eq(_overlay._intensity_slider.tooltip_text, "Shake tooltip EN")

	_localization_manager.translations[&"settings.vfx.title"] = "VFX ES"
	_localization_manager.translations[&"settings.vfx.label.screen_shake"] = "Sacudida"
	_localization_manager.translations[&"common.apply"] = "Aplicar"
	_localization_manager.translations[&"settings.vfx.tooltip.shake_intensity"] = "Tooltip de sacudida"

	_overlay._on_locale_changed(&"es")
	await get_tree().process_frame

	assert_eq(_overlay._title_label.text, "VFX ES")
	assert_eq(_overlay._shake_enabled_label.text, "Sacudida")
	assert_eq(_overlay._apply_button.text, "Aplicar")
	assert_eq(_overlay._intensity_slider.tooltip_text, "Tooltip de sacudida")

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
