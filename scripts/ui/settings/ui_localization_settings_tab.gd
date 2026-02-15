@icon("res://assets/editor_icons/icn_utility.svg")
extends VBoxContainer
class_name UI_LocalizationSettingsTab

const U_LOCALIZATION_ACTIONS := preload("res://scripts/state/actions/u_localization_actions.gd")
const U_LOCALIZATION_SELECTORS := preload("res://scripts/state/selectors/u_localization_selectors.gd")

const SUPPORTED_LOCALES: Array[StringName] = [&"en", &"es", &"pt", &"zh_CN", &"ja"]
const LOCALE_DISPLAY_NAMES: Array[String] = ["English", "Español", "Português", "中文 (简体)", "日本語"]

var _state_store: I_StateStore = null
var _updating_from_state: bool = false

@onready var _language_option: OptionButton = %LanguageOptionButton
@onready var _dyslexia_toggle: CheckButton = %DyslexiaCheckButton

func _ready() -> void:
	_populate_language_option()
	_connect_signals()

	_state_store = U_ServiceLocator.get_service(StringName("state_store")) as I_StateStore
	if _state_store == null:
		push_error("UI_LocalizationSettingsTab: StateStore not found")
		return

	_update_from_state(_state_store.get_state())

func _populate_language_option() -> void:
	if _language_option == null:
		return
	_language_option.clear()
	for name in LOCALE_DISPLAY_NAMES:
		_language_option.add_item(name)

func _connect_signals() -> void:
	if _language_option != null and not _language_option.item_selected.is_connected(_on_language_selected):
		_language_option.item_selected.connect(_on_language_selected)
	if _dyslexia_toggle != null and not _dyslexia_toggle.toggled.is_connected(_on_dyslexia_toggled):
		_dyslexia_toggle.toggled.connect(_on_dyslexia_toggled)

func _update_from_state(state: Dictionary) -> void:
	if state == null:
		return
	_updating_from_state = true

	var locale: StringName = U_LOCALIZATION_SELECTORS.get_locale(state)
	var locale_index: int = SUPPORTED_LOCALES.find(locale)
	if locale_index < 0:
		locale_index = 0
	if _language_option != null:
		_language_option.set_block_signals(true)
		_language_option.selected = locale_index
		_language_option.set_block_signals(false)

	var dyslexia: bool = U_LOCALIZATION_SELECTORS.is_dyslexia_font_enabled(state)
	if _dyslexia_toggle != null:
		_dyslexia_toggle.set_block_signals(true)
		_dyslexia_toggle.button_pressed = dyslexia
		_dyslexia_toggle.set_block_signals(false)

	_updating_from_state = false

func _on_language_selected(index: int) -> void:
	if _updating_from_state:
		return
	if index < 0 or index >= SUPPORTED_LOCALES.size():
		return
	if _state_store == null:
		return
	U_UISoundPlayer.play_confirm()
	_state_store.dispatch(U_LOCALIZATION_ACTIONS.set_locale(SUPPORTED_LOCALES[index]))

func _on_dyslexia_toggled(enabled: bool) -> void:
	if _updating_from_state:
		return
	if _state_store == null:
		return
	U_UISoundPlayer.play_confirm()
	_state_store.dispatch(U_LOCALIZATION_ACTIONS.set_dyslexia_font_enabled(enabled))

func _on_locale_changed(_locale: StringName) -> void:
	if _state_store != null:
		_update_from_state(_state_store.get_state())
