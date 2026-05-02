extends "res://scripts/core/ui/helpers/u_settings_tab_builder.gd"
class_name U_LocalizationTabBuilder

const U_UI_SETTINGS_CATALOG := preload("res://scripts/core/ui/helpers/u_ui_settings_catalog.gd")

var _on_language_selected: Callable
var _on_test_localization_pressed: Callable
var _on_dyslexia_toggled: Callable
var _on_apply_pressed: Callable
var _on_cancel_pressed: Callable
var _on_reset_pressed: Callable

func _init(tab: Control) -> void:
	super._init(tab)

func set_callbacks(
	language_cb: Callable,
	test_cb: Callable,
	dyslexia_cb: Callable = Callable(),
	apply_cb: Callable = Callable(),
	cancel_cb: Callable = Callable(),
	reset_cb: Callable = Callable()
) -> U_LocalizationTabBuilder:
	_on_language_selected = language_cb
	_on_test_localization_pressed = test_cb
	_on_dyslexia_toggled = dyslexia_cb
	_on_apply_pressed = apply_cb
	_on_cancel_pressed = cancel_cb
	_on_reset_pressed = reset_cb
	return self

func build() -> Control:
	set_heading(&"settings.localization.title")
	
	begin_section(&"settings.localization.section.language", "LanguageSection")
	add_dropdown(
		&"settings.localization.label.language",
		U_UI_SETTINGS_CATALOG.get_language_options(),
		_on_language_selected,
		&"",
		"",
		"LanguageOptionButton"
	)
	end_section()
	
	begin_section(&"settings.localization.section.accessibility", "AccessibilitySection")
	add_toggle(
		&"settings.localization.label.dyslexia",
		_on_dyslexia_toggled,
		&"",
		"",
		"DyslexiaCheckButton"
	)
	end_section()
	
	var test_btn := _add_button(_current_parent, &"settings.localization.button.test", _on_test_localization_pressed, "Test Localization")
	test_btn.name = "TestLocalizationButton"
	
	add_button_row(
		_on_apply_pressed,
		_on_cancel_pressed,
		_on_reset_pressed,
		&"common.apply",
		&"common.cancel",
		&"common.reset"
	)
	
	return super.build()
