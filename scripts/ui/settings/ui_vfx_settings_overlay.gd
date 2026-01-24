@icon("res://assets/editor_icons/utility.svg")
extends "res://scripts/ui/base/base_overlay.gd"
class_name UI_VFXSettingsOverlay

## VFX Settings Overlay UI Controller
##
## Displays VFX settings (screen shake, damage flash) with Apply/Cancel pattern.
## Changes are applied only when user clicks Apply button.

const RS_VFXInitialState := preload("res://scripts/resources/state/rs_vfx_initial_state.gd")
const U_VFXSelectors := preload("res://scripts/state/selectors/u_vfx_selectors.gd")
const U_VFXActions := preload("res://scripts/state/actions/u_vfx_actions.gd")
const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_NavigationSelectors := preload("res://scripts/state/selectors/u_navigation_selectors.gd")
const U_FocusConfigurator := preload("res://scripts/ui/helpers/u_focus_configurator.gd")
const U_ServiceLocator := preload("res://scripts/core/u_service_locator.gd")

@onready var _shake_enabled_toggle: CheckButton = %ShakeEnabledToggle
@onready var _intensity_slider: HSlider = %IntensitySlider
@onready var _intensity_percentage: Label = %IntensityPercentage
@onready var _flash_enabled_toggle: CheckButton = %FlashEnabledToggle
@onready var _particles_enabled_toggle: CheckButton = %ParticlesEnabledToggle
@onready var _apply_button: Button = %ApplyButton
@onready var _cancel_button: Button = %CancelButton
@onready var _reset_button: Button = %ResetButton

var _store_unsubscribe: Callable = Callable()
var _updating_from_state: bool = false
var _has_local_edits: bool = false
var _vfx_manager: M_VFXManager = null

func _ready() -> void:
	await super._ready()
	_vfx_manager = U_ServiceLocator.try_get_service(StringName("vfx_manager")) as M_VFXManager

func _on_store_ready(store: M_StateStore) -> void:
	if _store_unsubscribe != Callable() and _store_unsubscribe.is_valid():
		_store_unsubscribe.call()
		_store_unsubscribe = Callable()
	if store != null:
		_store_unsubscribe = store.subscribe(_on_state_changed)
		_on_state_changed({}, store.get_state())

func _on_panel_ready() -> void:
	_configure_focus_neighbors()
	_connect_control_signals()
	# Initialize UI from state
	var store := get_store()
	if store != null:
		_on_state_changed({}, store.get_state())

func _configure_focus_neighbors() -> void:
	var vertical_controls: Array[Control] = []
	if _shake_enabled_toggle != null:
		vertical_controls.append(_shake_enabled_toggle)
	if _intensity_slider != null:
		vertical_controls.append(_intensity_slider)
	if _flash_enabled_toggle != null:
		vertical_controls.append(_flash_enabled_toggle)
	if _particles_enabled_toggle != null:
		vertical_controls.append(_particles_enabled_toggle)

	if not vertical_controls.is_empty():
		U_FocusConfigurator.configure_vertical_focus(vertical_controls, false)

	var last_vertical_control: Control = null
	if not vertical_controls.is_empty():
		last_vertical_control = vertical_controls[vertical_controls.size() - 1]

	# Configure button row horizontal focus
	var buttons: Array[Control] = []
	if _cancel_button != null:
		buttons.append(_cancel_button)
	if _reset_button != null:
		buttons.append(_reset_button)
	if _apply_button != null:
		buttons.append(_apply_button)

	if not buttons.is_empty():
		U_FocusConfigurator.configure_horizontal_focus(buttons, true)
		# Connect vertical controls to button row
		var first_button := buttons[0]
		for button in buttons:
			if last_vertical_control != null:
				button.focus_neighbor_top = button.get_path_to(last_vertical_control)
				button.focus_neighbor_bottom = button.get_path_to(last_vertical_control)
		# Connect last vertical control to first button
		if last_vertical_control != null:
			last_vertical_control.focus_neighbor_bottom = last_vertical_control.get_path_to(first_button)

func _connect_control_signals() -> void:
	if _shake_enabled_toggle != null and not _shake_enabled_toggle.toggled.is_connected(_on_shake_enabled_toggled):
		_shake_enabled_toggle.toggled.connect(_on_shake_enabled_toggled)
	if _intensity_slider != null and not _intensity_slider.value_changed.is_connected(_on_intensity_changed):
		_intensity_slider.value_changed.connect(_on_intensity_changed)
	if _flash_enabled_toggle != null and not _flash_enabled_toggle.toggled.is_connected(_on_flash_enabled_toggled):
		_flash_enabled_toggle.toggled.connect(_on_flash_enabled_toggled)
	if _particles_enabled_toggle != null and not _particles_enabled_toggle.toggled.is_connected(_on_particles_enabled_toggled):
		_particles_enabled_toggle.toggled.connect(_on_particles_enabled_toggled)
	if _apply_button != null and not _apply_button.pressed.is_connected(_on_apply_pressed):
		_apply_button.pressed.connect(_on_apply_pressed)
	if _cancel_button != null and not _cancel_button.pressed.is_connected(_on_cancel_pressed):
		_cancel_button.pressed.connect(_on_cancel_pressed)
	if _reset_button != null and not _reset_button.pressed.is_connected(_on_reset_pressed):
		_reset_button.pressed.connect(_on_reset_pressed)

func _on_state_changed(action: Dictionary, state: Dictionary) -> void:
	if state == null or state.is_empty():
		return

	var action_type: StringName = StringName("")
	if action != null and action.has("type"):
		action_type = action.get("type", StringName(""))

	# Preserve local edits (Apply/Cancel pattern). Only reconcile from state when
	# the user is not actively editing.
	if _has_local_edits and action_type != StringName(""):
		return

	# Update UI from state (without triggering signals)
	_updating_from_state = true

	if _shake_enabled_toggle != null:
		_shake_enabled_toggle.button_pressed = U_VFXSelectors.is_screen_shake_enabled(state)

	if _intensity_slider != null:
		var intensity := U_VFXSelectors.get_screen_shake_intensity(state)
		_intensity_slider.value = intensity
		_update_percentage_label(intensity)

	if _flash_enabled_toggle != null:
		_flash_enabled_toggle.button_pressed = U_VFXSelectors.is_damage_flash_enabled(state)

	if _particles_enabled_toggle != null:
		_particles_enabled_toggle.button_pressed = U_VFXSelectors.is_particles_enabled(state)

	_updating_from_state = false

func _on_shake_enabled_toggled(_pressed: bool) -> void:
	# Changes only apply when user clicks Apply button
	if _updating_from_state:
		return
	_has_local_edits = true
	_update_vfx_settings_preview_from_ui()

func _on_intensity_changed(value: float) -> void:
	# Update percentage label immediately for visual feedback
	_update_percentage_label(value)
	if _updating_from_state:
		return
	U_UISoundPlayer.play_slider_tick()
	_has_local_edits = true
	_update_vfx_settings_preview_from_ui()
	if _vfx_manager != null:
		_vfx_manager.trigger_test_shake(value)

func _on_flash_enabled_toggled(_pressed: bool) -> void:
	# Changes only apply when user clicks Apply button
	if _updating_from_state:
		return
	_has_local_edits = true
	_update_vfx_settings_preview_from_ui()

func _on_particles_enabled_toggled(_pressed: bool) -> void:
	# Changes only apply when user clicks Apply button
	if _updating_from_state:
		return
	_has_local_edits = true

func _on_apply_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	var store := get_store()
	if store == null:
		_close_overlay()
		return

	# Capture all values BEFORE dispatching any actions
	# (dispatching triggers state_changed which can modify UI values)
	var shake_enabled := _shake_enabled_toggle.button_pressed
	var shake_intensity := _intensity_slider.value
	var flash_enabled := _flash_enabled_toggle.button_pressed
	var particles_enabled := _particles_enabled_toggle.button_pressed

	_has_local_edits = false
	store.dispatch(U_VFXActions.set_screen_shake_enabled(shake_enabled))
	store.dispatch(U_VFXActions.set_screen_shake_intensity(shake_intensity))
	store.dispatch(U_VFXActions.set_damage_flash_enabled(flash_enabled))
	store.dispatch(U_VFXActions.set_particles_enabled(particles_enabled))
	_close_overlay()

func _on_reset_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	var defaults := RS_VFXInitialState.new()

	_shake_enabled_toggle.button_pressed = defaults.screen_shake_enabled
	_intensity_slider.value = defaults.screen_shake_intensity
	_flash_enabled_toggle.button_pressed = defaults.damage_flash_enabled
	_particles_enabled_toggle.button_pressed = defaults.particles_enabled

	_update_percentage_label(_intensity_slider.value)
	_update_vfx_settings_preview_from_ui()

	# Apply immediately after reset (matches other settings panels)
	_has_local_edits = false
	var store := get_store()
	if store != null:
		store.dispatch(U_VFXActions.set_screen_shake_enabled(defaults.screen_shake_enabled))
		store.dispatch(U_VFXActions.set_screen_shake_intensity(defaults.screen_shake_intensity))
		store.dispatch(U_VFXActions.set_damage_flash_enabled(defaults.damage_flash_enabled))
		store.dispatch(U_VFXActions.set_particles_enabled(defaults.particles_enabled))

func _close_overlay() -> void:
	_clear_vfx_settings_preview()
	var store := get_store()
	if store == null:
		return

	_has_local_edits = false

	var nav_slice: Dictionary = store.get_state().get("navigation", {})
	var overlay_stack: Array = U_NavigationSelectors.get_overlay_stack(nav_slice)

	if not overlay_stack.is_empty():
		store.dispatch(U_NavigationActions.close_top_overlay())
	else:
		store.dispatch(U_NavigationActions.set_shell(StringName("main_menu"), StringName("settings_menu")))

func _on_back_pressed() -> void:
	U_UISoundPlayer.play_cancel()
	_close_overlay()

func _on_cancel_pressed() -> void:
	U_UISoundPlayer.play_cancel()
	_has_local_edits = false
	_clear_vfx_settings_preview()
	_close_overlay()

func _update_vfx_settings_preview_from_ui() -> void:
	if _vfx_manager == null:
		return
	_vfx_manager.set_vfx_settings_preview({
		"screen_shake_enabled": _shake_enabled_toggle.button_pressed if _shake_enabled_toggle != null else true,
		"screen_shake_intensity": _intensity_slider.value if _intensity_slider != null else 1.0,
		"damage_flash_enabled": _flash_enabled_toggle.button_pressed if _flash_enabled_toggle != null else true,
	})

func _clear_vfx_settings_preview() -> void:
	if _vfx_manager == null:
		return
	_vfx_manager.clear_vfx_settings_preview()

func _update_percentage_label(value: float) -> void:
	if _intensity_percentage != null:
		_intensity_percentage.text = "%d%%" % int(value * 100.0)

func _exit_tree() -> void:
	_clear_vfx_settings_preview()
	if _store_unsubscribe != Callable() and _store_unsubscribe.is_valid():
		_store_unsubscribe.call()
	_store_unsubscribe = Callable()
