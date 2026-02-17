extends GutTest

const OVERLAY_SCENE := preload("res://scenes/ui/overlays/ui_edit_touch_controls_overlay.tscn")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

var _store: M_StateStore
var _overlay: UI_EditTouchControlsOverlay
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
		&"overlay.edit_touch_controls.title": "Edit EN",
		&"overlay.edit_touch_controls.label.drag_mode": "Drag EN",
		&"overlay.edit_touch_controls.instructions": "Instructions EN",
		&"overlay.edit_touch_controls.button.save_positions": "Save EN",
	}
	U_SERVICE_LOCATOR.register(StringName("localization_manager"), _localization_manager)

	_overlay = OVERLAY_SCENE.instantiate() as UI_EditTouchControlsOverlay
	add_child_autofree(_overlay)
	await get_tree().process_frame
	await get_tree().process_frame

func after_each() -> void:
	U_StateHandoff.clear_all()
	U_SERVICE_LOCATOR.clear()
	_store = null
	_overlay = null
	_localization_manager = null

func test_locale_change_relocalizes_edit_touch_controls_labels() -> void:
	assert_eq(_overlay._title_label.text, "Edit EN")
	assert_eq(_overlay._drag_mode_check.text, "Drag EN")
	assert_eq(_overlay._instructions_label.text, "Instructions EN")
	assert_eq(_overlay._save_button.text, "Save EN")

	_localization_manager.translations[&"overlay.edit_touch_controls.title"] = "Editar ES"
	_localization_manager.translations[&"overlay.edit_touch_controls.label.drag_mode"] = "Arrastre ES"
	_localization_manager.translations[&"overlay.edit_touch_controls.instructions"] = "Instrucciones ES"
	_localization_manager.translations[&"overlay.edit_touch_controls.button.save_positions"] = "Guardar ES"

	_overlay._on_locale_changed(&"es")
	await get_tree().process_frame

	assert_eq(_overlay._title_label.text, "Editar ES")
	assert_eq(_overlay._drag_mode_check.text, "Arrastre ES")
	assert_eq(_overlay._instructions_label.text, "Instrucciones ES")
	assert_eq(_overlay._save_button.text, "Guardar ES")

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
