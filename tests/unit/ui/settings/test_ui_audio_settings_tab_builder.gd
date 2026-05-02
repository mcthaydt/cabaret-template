extends GutTest

const TAB_SCENE := preload("res://scenes/core/ui/overlays/settings/ui_audio_settings_tab.tscn")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")

var _store: M_StateStore
var _tab: UI_AudioSettingsTab


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
	_tab = null


func test_audio_settings_tab_is_builder_backed() -> void:
	_instantiate_tab()

	assert_true(_tab.has_meta(&"settings_builder"), "Audio tab should mark builder-backed runtime UI")


func test_audio_builder_wires_signals_and_focus() -> void:
	_instantiate_tab()

	_tab._master_volume_slider.value = 0.3
	_tab._master_volume_slider.value_changed.emit(0.3)
	_tab._master_mute_toggle.button_pressed = true
	_tab._master_mute_toggle.toggled.emit(true)
	_tab._apply_button.pressed.emit()
	await get_tree().process_frame

	var audio_state: Dictionary = _store.get_state().get("audio", {})
	assert_almost_eq(
		float(audio_state.get("master_volume", 0.0)),
		0.3,
		0.001,
		"Builder callback should dispatch slider value"
	)
	assert_true(bool(audio_state.get("master_muted", false)), "Builder callback should dispatch toggle value")
	assert_ne(_tab._master_volume_slider.focus_neighbor_bottom, NodePath(), "Builder should configure vertical focus")


func test_audio_builder_applies_theme_tokens() -> void:
	var config := RS_UI_THEME_CONFIG.new()
	config.heading = 38
	config.section_header = 16
	config.body_small = 15
	config.text_secondary = Color(0.82, 0.72, 0.66, 1.0)
	U_UI_THEME_BUILDER.active_config = config
	_instantiate_tab()

	var heading_label := _find_child_by_name(_tab, "HeadingLabel") as Label
	var master_label := _find_child_by_name(_tab, "MasterVolumeSlider").get_parent().get_child(0) as Label
	
	assert_eq(heading_label.get_theme_font_size(&"font_size"), config.heading, "Heading should use builder token")
	assert_eq(master_label.get_theme_font_size(&"font_size"), config.body_small, "Label should use builder token")
	assert_true(
		master_label.get_theme_color(&"font_color").is_equal_approx(config.text_secondary),
		"Field label should use secondary color token"
	)
	assert_eq(_tab._apply_button.get_theme_font_size(&"font_size"), config.section_header, "Action should use builder token")

func _find_child_by_name(parent: Node, name: String) -> Node:
	for child in parent.get_children():
		if child.name == name:
			return child
		var result := _find_child_by_name(child, name)
		if result != null:
			return result
	return null


func _instantiate_tab() -> void:
	_tab = TAB_SCENE.instantiate() as UI_AudioSettingsTab
	add_child_autofree(_tab)
	await get_tree().process_frame
