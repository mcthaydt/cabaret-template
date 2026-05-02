extends GutTest

const UI_AUDIO_SETTINGS_TAB := preload("res://scenes/core/ui/overlays/settings/ui_audio_settings_tab.tscn")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")

var _store: M_StateStore

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
	_store.audio_initial_state = RS_AudioInitialState.new()
	add_child_autofree(_store)
	U_SERVICE_LOCATOR.register(StringName("state_store"), _store)

func after_each() -> void:
	U_UI_THEME_BUILDER.active_config = null
	U_StateHandoff.clear_all()
	U_SERVICE_LOCATOR.clear()
	_store = null

func test_audio_tab_has_no_onready_variables() -> void:
	var tab := UI_AUDIO_SETTINGS_TAB.instantiate()
	add_child_autofree(tab)
	
	var script_instance: Script = tab.get_script()
	var source_code: String = script_instance.get_source_code()
	
	var onready_count: int = 0
	for line: String in source_code.split("\n"):
		if line.strip_edges().begins_with("@onready"):
			onready_count += 1
	
	assert_eq(onready_count, 0, "Audio settings tab should have zero @onready variables after migration to builder pattern")
