@icon("res://resources/editor_icons/utility.svg")
extends "res://scripts/ui/base/base_overlay.gd"
class_name UI_VFXSettingsOverlay

## VFX Settings Overlay UI Controller
##
## Displays VFX settings (screen shake, damage flash) with auto-save pattern.
## Changes are immediately dispatched to Redux - no Apply/Cancel buttons.

const U_VFXSelectors := preload("res://scripts/state/selectors/u_vfx_selectors.gd")
const U_VFXActions := preload("res://scripts/state/actions/u_vfx_actions.gd")
const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_NavigationSelectors := preload("res://scripts/state/selectors/u_navigation_selectors.gd")
const U_FocusConfigurator := preload("res://scripts/ui/helpers/u_focus_configurator.gd")

@onready var _shake_enabled_toggle: CheckButton = %ShakeEnabledToggle
@onready var _intensity_slider: HSlider = %IntensitySlider
@onready var _intensity_percentage: Label = %IntensityPercentage
@onready var _flash_enabled_toggle: CheckButton = %FlashEnabledToggle
@onready var _close_button: Button = %CloseButton

var _store_unsubscribe: Callable = Callable()

func _on_store_ready(store: M_StateStore) -> void:
	if _store_unsubscribe != Callable() and _store_unsubscribe.is_valid():
		_store_unsubscribe.call()
		_store_unsubscribe = Callable()
	if store != null:
		_store_unsubscribe = store.subscribe(_on_state_changed)
		_on_state_changed(store.get_state())

func _on_panel_ready() -> void:
	_configure_focus_neighbors()
	_connect_control_signals()
	# Initialize UI from state
	var store := get_store()
	if store != null:
		_on_state_changed(store.get_state())

func _configure_focus_neighbors() -> void:
	var vertical_controls: Array[Control] = []
	if _shake_enabled_toggle != null:
		vertical_controls.append(_shake_enabled_toggle)
	if _intensity_slider != null:
		vertical_controls.append(_intensity_slider)
	if _flash_enabled_toggle != null:
		vertical_controls.append(_flash_enabled_toggle)
	if _close_button != null:
		vertical_controls.append(_close_button)

	if not vertical_controls.is_empty():
		U_FocusConfigurator.configure_vertical_focus(vertical_controls, true)

func _connect_control_signals() -> void:
	if _shake_enabled_toggle != null and not _shake_enabled_toggle.toggled.is_connected(_on_shake_enabled_toggled):
		_shake_enabled_toggle.toggled.connect(_on_shake_enabled_toggled)
	if _intensity_slider != null and not _intensity_slider.value_changed.is_connected(_on_intensity_changed):
		_intensity_slider.value_changed.connect(_on_intensity_changed)
	if _flash_enabled_toggle != null and not _flash_enabled_toggle.toggled.is_connected(_on_flash_enabled_toggled):
		_flash_enabled_toggle.toggled.connect(_on_flash_enabled_toggled)
	if _close_button != null and not _close_button.pressed.is_connected(_on_close_pressed):
		_close_button.pressed.connect(_on_close_pressed)

func _on_state_changed(state: Dictionary) -> void:
	if state == null or state.is_empty():
		return

	# Update UI from state (without triggering signals)
	if _shake_enabled_toggle != null:
		_shake_enabled_toggle.set_block_signals(true)
		_shake_enabled_toggle.button_pressed = U_VFXSelectors.is_screen_shake_enabled(state)
		_shake_enabled_toggle.set_block_signals(false)

	if _intensity_slider != null:
		_intensity_slider.set_block_signals(true)
		var intensity := U_VFXSelectors.get_screen_shake_intensity(state)
		_intensity_slider.value = intensity
		_intensity_slider.set_block_signals(false)
		_update_percentage_label(intensity)

	if _flash_enabled_toggle != null:
		_flash_enabled_toggle.set_block_signals(true)
		_flash_enabled_toggle.button_pressed = U_VFXSelectors.is_damage_flash_enabled(state)
		_flash_enabled_toggle.set_block_signals(false)

func _on_shake_enabled_toggled(pressed: bool) -> void:
	var store := get_store()
	if store != null:
		store.dispatch(U_VFXActions.set_screen_shake_enabled(pressed))

func _on_intensity_changed(value: float) -> void:
	var store := get_store()
	if store != null:
		store.dispatch(U_VFXActions.set_screen_shake_intensity(value))
	_update_percentage_label(value)

func _on_flash_enabled_toggled(pressed: bool) -> void:
	var store := get_store()
	if store != null:
		store.dispatch(U_VFXActions.set_damage_flash_enabled(pressed))

func _on_close_pressed() -> void:
	var store := get_store()
	if store == null:
		return

	var nav_slice: Dictionary = store.get_state().get("navigation", {})
	var overlay_stack: Array = U_NavigationSelectors.get_overlay_stack(nav_slice)

	if not overlay_stack.is_empty():
		store.dispatch(U_NavigationActions.close_top_overlay())
	else:
		store.dispatch(U_NavigationActions.set_shell(StringName("main_menu"), StringName("settings_menu")))

func _on_back_pressed() -> void:
	_on_close_pressed()

func _update_percentage_label(value: float) -> void:
	if _intensity_percentage != null:
		_intensity_percentage.text = "%d%%" % int(value * 100.0)

func _exit_tree() -> void:
	if _store_unsubscribe != Callable() and _store_unsubscribe.is_valid():
		_store_unsubscribe.call()
	_store_unsubscribe = Callable()
