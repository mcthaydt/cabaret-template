extends GutTest

const MENU_SCENE := preload("res://scenes/ui/overlays/ui_save_load_menu.tscn")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

var _store: M_StateStore
var _menu: UI_SaveLoadMenu
var _localization_manager: MockLocalizationManager
var _save_manager: SaveManagerStub

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
	_store.navigation_initial_state = RS_NavigationInitialState.new()
	add_child_autofree(_store)
	U_SERVICE_LOCATOR.register(StringName("state_store"), _store)
	_store.dispatch(U_NavigationActions.set_save_load_mode(StringName("save")))

	_save_manager = SaveManagerStub.new()
	add_child_autofree(_save_manager)
	_save_manager.metadata = [
		{
			"slot_id": StringName("autosave"),
			"exists": true,
			"timestamp": "2026-02-17T12:00:00Z",
			"area_name": "Area",
			"playtime_seconds": 10,
			"thumbnail_path": "",
		}
	]
	U_SERVICE_LOCATOR.register(StringName("save_manager"), _save_manager)

	_localization_manager = MockLocalizationManager.new()
	add_child_autofree(_localization_manager)
	_localization_manager.translations = {
		&"overlay.save_load.title_save": "Save EN",
		&"common.back": "Back EN",
		&"overlay.save_load.loading": "Loading EN",
		&"overlay.save_load.dialog.confirm_title": "Confirm EN",
		&"common.confirm": "ConfirmBtn EN",
		&"common.cancel": "Cancel EN",
		&"overlay.save_load.autosave": "AUTOSAVE EN",
	}
	U_SERVICE_LOCATOR.register(StringName("localization_manager"), _localization_manager)

	_menu = MENU_SCENE.instantiate() as UI_SaveLoadMenu
	add_child_autofree(_menu)
	await get_tree().process_frame
	await get_tree().process_frame

func after_each() -> void:
	U_StateHandoff.clear_all()
	U_SERVICE_LOCATOR.clear()
	_store = null
	_menu = null
	_localization_manager = null
	_save_manager = null

func test_locale_change_relocalizes_save_load_menu_ui() -> void:
	var autosave_button := _find_first_slot_main_button()
	assert_not_null(autosave_button)
	if autosave_button == null:
		return

	assert_eq(_menu._mode_label.text, "Save EN")
	assert_eq(_menu._back_button.text, "Back EN")
	assert_eq(_menu._loading_label.text, "Loading EN")
	assert_eq(_menu._confirmation_dialog.title, "Confirm EN")
	assert_eq(_menu._confirmation_dialog.get_ok_button().text, "ConfirmBtn EN")
	assert_eq(_menu._confirmation_dialog.get_cancel_button().text, "Cancel EN")
	assert_true(autosave_button.text.begins_with("AUTOSAVE EN"))

	_localization_manager.translations[&"overlay.save_load.title_save"] = "Guardar ES"
	_localization_manager.translations[&"common.back"] = "Volver"
	_localization_manager.translations[&"overlay.save_load.loading"] = "Cargando ES"
	_localization_manager.translations[&"overlay.save_load.dialog.confirm_title"] = "Confirmar ES"
	_localization_manager.translations[&"common.confirm"] = "ConfirmarBtn ES"
	_localization_manager.translations[&"common.cancel"] = "Cancelar ES"
	_localization_manager.translations[&"overlay.save_load.autosave"] = "AUTOGUARDADO ES"

	_menu._on_locale_changed(&"es")
	await get_tree().process_frame

	autosave_button = _find_first_slot_main_button()
	assert_not_null(autosave_button)
	if autosave_button == null:
		return
	assert_eq(_menu._mode_label.text, "Guardar ES")
	assert_eq(_menu._back_button.text, "Volver")
	assert_eq(_menu._loading_label.text, "Cargando ES")
	assert_eq(_menu._confirmation_dialog.title, "Confirmar ES")
	assert_eq(_menu._confirmation_dialog.get_ok_button().text, "ConfirmarBtn ES")
	assert_eq(_menu._confirmation_dialog.get_cancel_button().text, "Cancelar ES")
	assert_true(autosave_button.text.begins_with("AUTOGUARDADO ES"))

func _find_first_slot_main_button() -> Button:
	var slot_list := _menu.get_node_or_null("%SlotListContainer") as VBoxContainer
	if slot_list == null:
		return null
	for child in slot_list.get_children():
		var container := child as HBoxContainer
		if container == null:
			continue
		var main_button := container.get_node_or_null("MainButton") as Button
		if main_button != null:
			return main_button
	return null

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

class SaveManagerStub extends Node:
	var metadata: Array[Dictionary] = []

	func get_all_slot_metadata() -> Array[Dictionary]:
		return metadata.duplicate(true)

	func save_to_slot(_slot_id: StringName) -> Error:
		return OK

	func load_from_slot(_slot_id: StringName) -> Error:
		return OK

	func delete_slot(_slot_id: StringName) -> Error:
		return OK
