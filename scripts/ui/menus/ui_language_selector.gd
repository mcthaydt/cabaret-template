@icon("res://assets/editor_icons/icn_utility.svg")
extends BaseMenuScreen
class_name UI_LanguageSelector

## Language Selector UI Controller (Phase 0.5B)
##
## First-run screen that lets the player choose their language.
## On subsequent launches, instantly skips to main_menu when
## has_selected_language is already true.


const SUPPORTED_LOCALES: Array[StringName] = [&"en", &"es", &"pt", &"zh_CN", &"ja"]

@onready var _button_container: Control = %ButtonContainer
@onready var _en_button: Button = %EnButton
@onready var _es_button: Button = %EsButton
@onready var _pt_button: Button = %PtButton
@onready var _zh_cn_button: Button = %ZhCnButton
@onready var _ja_button: Button = %JaButton


func _ready() -> void:
	# Flash prevention: hide container before store lookup so the screen never
	# flashes visible on returning visits (skip path executes in same frame).
	if _button_container != null:
		_button_container.visible = false
	super._ready()


func _on_store_ready(_store_ref: M_StateStore) -> void:
	var state: Dictionary = _store_ref.get_state()
	if U_LocalizationSelectors.has_selected_language(state):
		_skip_to_main_menu()
	else:
		_setup_buttons()


func _setup_buttons() -> void:
	if _button_container != null:
		_button_container.visible = true

	_connect_locale_button(_en_button, &"en")
	_connect_locale_button(_es_button, &"es")
	_connect_locale_button(_pt_button, &"pt")
	_connect_locale_button(_zh_cn_button, &"zh_CN")
	_connect_locale_button(_ja_button, &"ja")

	# Build 3-column grid for keyboard/gamepad navigation:
	# Row 0: [en, es, pt]
	# Row 1: [zh_CN, ja, null]
	var grid: Array = [
		[_en_button, _es_button, _pt_button],
		[_zh_cn_button, _ja_button, null],
	]
	U_FocusConfigurator.configure_grid_focus(grid, false, false)

	if _en_button != null:
		_en_button.grab_focus()


func _connect_locale_button(button: Button, locale: StringName) -> void:
	if button == null:
		return
	if not button.pressed.is_connected(_on_locale_selected.bind(locale)):
		button.pressed.connect(_on_locale_selected.bind(locale))


func _on_locale_selected(locale: StringName) -> void:
	U_UISoundPlayer.play_confirm()
	var store := get_store()
	if store == null:
		return
	store.dispatch(U_LocalizationActions.set_locale(locale))
	store.dispatch(U_LocalizationActions.mark_language_selected())
	_transition_to_main_menu()


func _skip_to_main_menu() -> void:
	var scene_manager := U_ServiceLocator.get_service(StringName("scene_manager")) as M_SceneManager
	if scene_manager == null:
		push_warning("UI_LanguageSelector: scene_manager not found — cannot skip to main_menu")
		return
	scene_manager.transition_to_scene(StringName("main_menu"), "instant")


func _transition_to_main_menu() -> void:
	var scene_manager := U_ServiceLocator.get_service(StringName("scene_manager")) as M_SceneManager
	if scene_manager == null:
		push_warning("UI_LanguageSelector: scene_manager not found — cannot transition to main_menu")
		return
	scene_manager.transition_to_scene(StringName("main_menu"), "fade")


func _on_back_pressed() -> void:
	pass  # No back action on first-run screen
