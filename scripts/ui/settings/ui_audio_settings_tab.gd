@icon("res://resources/editor_icons/utility.svg")
extends VBoxContainer
class_name UI_AudioSettingsTab

const U_ServiceLocator := preload("res://scripts/core/u_service_locator.gd")
const U_AudioSelectors := preload("res://scripts/state/selectors/u_audio_selectors.gd")
const U_AudioActions := preload("res://scripts/state/actions/u_audio_actions.gd")
const U_FocusConfigurator := preload("res://scripts/ui/helpers/u_focus_configurator.gd")
const U_UISoundPlayer := preload("res://scripts/ui/utils/u_ui_sound_player.gd")
const RS_AudioInitialState := preload("res://scripts/state/resources/rs_audio_initial_state.gd")
const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_NavigationSelectors := preload("res://scripts/state/selectors/u_navigation_selectors.gd")
const I_AUDIO_MANAGER := preload("res://scripts/interfaces/i_audio_manager.gd")

var _state_store: I_StateStore = null
var _audio_manager: Node = null
var _unsubscribe: Callable = Callable()
var _updating_from_state: bool = false
var _has_local_edits: bool = false

# Row containers (for mute dimming)
@onready var _master_row: HBoxContainer = $MasterRow
@onready var _music_row: HBoxContainer = $MusicRow
@onready var _sfx_row: HBoxContainer = $SFXRow
@onready var _ambient_row: HBoxContainer = $AmbientRow

# Master
@onready var _master_volume_slider: HSlider = %MasterVolumeSlider
@onready var _master_percentage: Label = %MasterPercentage
@onready var _master_mute_toggle: CheckBox = %MasterMuteToggle

# Music
@onready var _music_volume_slider: HSlider = %MusicVolumeSlider
@onready var _music_percentage: Label = %MusicPercentage
@onready var _music_mute_toggle: CheckBox = %MusicMuteToggle

# SFX
@onready var _sfx_volume_slider: HSlider = %SFXVolumeSlider
@onready var _sfx_percentage: Label = %SFXPercentage
@onready var _sfx_mute_toggle: CheckBox = %SFXMuteToggle

# Ambient
@onready var _ambient_volume_slider: HSlider = %AmbientVolumeSlider
@onready var _ambient_percentage: Label = %AmbientPercentage
@onready var _ambient_mute_toggle: CheckBox = %AmbientMuteToggle

# Spatial
@onready var _spatial_audio_toggle: CheckBox = %SpatialAudioToggle

# Buttons
@onready var _apply_button: Button = %ApplyButton
@onready var _cancel_button: Button = %CancelButton
@onready var _reset_button: Button = %ResetButton

func _ready() -> void:
	_connect_signals()
	_configure_focus_neighbors()

	_state_store = U_ServiceLocator.get_service(StringName("state_store")) as I_StateStore
	if _state_store == null:
		push_error("UI_AudioSettingsTab: StateStore not found")
		return

	_audio_manager = U_ServiceLocator.try_get_service(StringName("audio_manager"))

	_unsubscribe = _state_store.subscribe(_on_state_changed)
	_on_state_changed({}, _state_store.get_state())

func _exit_tree() -> void:
	_clear_audio_settings_preview()
	if _unsubscribe != Callable() and _unsubscribe.is_valid():
		_unsubscribe.call()
		_unsubscribe = Callable()

func _connect_signals() -> void:
	if _master_volume_slider != null and not _master_volume_slider.value_changed.is_connected(_on_master_volume_changed):
		_master_volume_slider.value_changed.connect(_on_master_volume_changed)
	if _master_mute_toggle != null and not _master_mute_toggle.toggled.is_connected(_on_master_mute_toggled):
		_master_mute_toggle.toggled.connect(_on_master_mute_toggled)

	if _music_volume_slider != null and not _music_volume_slider.value_changed.is_connected(_on_music_volume_changed):
		_music_volume_slider.value_changed.connect(_on_music_volume_changed)
	if _music_mute_toggle != null and not _music_mute_toggle.toggled.is_connected(_on_music_mute_toggled):
		_music_mute_toggle.toggled.connect(_on_music_mute_toggled)

	if _sfx_volume_slider != null and not _sfx_volume_slider.value_changed.is_connected(_on_sfx_volume_changed):
		_sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	if _sfx_mute_toggle != null and not _sfx_mute_toggle.toggled.is_connected(_on_sfx_mute_toggled):
		_sfx_mute_toggle.toggled.connect(_on_sfx_mute_toggled)

	if _ambient_volume_slider != null and not _ambient_volume_slider.value_changed.is_connected(_on_ambient_volume_changed):
		_ambient_volume_slider.value_changed.connect(_on_ambient_volume_changed)
	if _ambient_mute_toggle != null and not _ambient_mute_toggle.toggled.is_connected(_on_ambient_mute_toggled):
		_ambient_mute_toggle.toggled.connect(_on_ambient_mute_toggled)

	if _spatial_audio_toggle != null and not _spatial_audio_toggle.toggled.is_connected(_on_spatial_audio_toggled):
		_spatial_audio_toggle.toggled.connect(_on_spatial_audio_toggled)

	if _apply_button != null and not _apply_button.pressed.is_connected(_on_apply_pressed):
		_apply_button.pressed.connect(_on_apply_pressed)
	if _cancel_button != null and not _cancel_button.pressed.is_connected(_on_cancel_pressed):
		_cancel_button.pressed.connect(_on_cancel_pressed)
	if _reset_button != null and not _reset_button.pressed.is_connected(_on_reset_pressed):
		_reset_button.pressed.connect(_on_reset_pressed)

func _input(event: InputEvent) -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null:
		return

	# Handle slider-to-mute navigation: right arrow at max value jumps to mute toggle
	if event.is_action_pressed("ui_right") and focused is HSlider:
		var slider := focused as HSlider
		# Check if slider is at max value (100%)
		if slider.value >= slider.max_value:
			var target_toggle: CheckBox = _get_mute_toggle_for_slider(slider)
			if target_toggle != null:
				target_toggle.grab_focus()
				get_viewport().set_input_as_handled()
		return

	# Handle mute-to-slider navigation: left arrow on mute toggle jumps back to slider
	if event.is_action_pressed("ui_left") and focused is CheckBox:
		var toggle := focused as CheckBox
		var target_slider: HSlider = _get_slider_for_mute_toggle(toggle)
		if target_slider != null:
			target_slider.grab_focus()
			get_viewport().set_input_as_handled()

func _get_mute_toggle_for_slider(slider: HSlider) -> CheckBox:
	if slider == _master_volume_slider:
		return _master_mute_toggle
	elif slider == _music_volume_slider:
		return _music_mute_toggle
	elif slider == _sfx_volume_slider:
		return _sfx_mute_toggle
	elif slider == _ambient_volume_slider:
		return _ambient_mute_toggle
	return null

func _get_slider_for_mute_toggle(toggle: CheckBox) -> HSlider:
	if toggle == _master_mute_toggle:
		return _master_volume_slider
	elif toggle == _music_mute_toggle:
		return _music_volume_slider
	elif toggle == _sfx_mute_toggle:
		return _sfx_volume_slider
	elif toggle == _ambient_mute_toggle:
		return _ambient_volume_slider
	return null

func _configure_focus_neighbors() -> void:
	# Configure a 2-column grid:
	# - Column 0: volume sliders
	# - Column 1: toggles (mute + spatial)
	var grid: Array = [
		[_master_volume_slider, _master_mute_toggle],
		[_music_volume_slider, _music_mute_toggle],
		[_sfx_volume_slider, _sfx_mute_toggle],
		[_ambient_volume_slider, _ambient_mute_toggle],
		[null, _spatial_audio_toggle],
	]

	U_FocusConfigurator.configure_grid_focus(grid, false, false)

	# Add a sensible "down" neighbor for the last slider into the spatial toggle.
	if _ambient_volume_slider != null and _spatial_audio_toggle != null:
		_ambient_volume_slider.focus_neighbor_bottom = _ambient_volume_slider.get_path_to(_spatial_audio_toggle)

	# Let users move left from spatial toggle into the last slider column.
	if _spatial_audio_toggle != null and _ambient_volume_slider != null:
		_spatial_audio_toggle.focus_neighbor_left = _spatial_audio_toggle.get_path_to(_ambient_volume_slider)

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
		# Connect spatial toggle to button row
		if _spatial_audio_toggle != null:
			_spatial_audio_toggle.focus_neighbor_bottom = _spatial_audio_toggle.get_path_to(buttons[0])
			for button in buttons:
				button.focus_neighbor_top = button.get_path_to(_spatial_audio_toggle)
				button.focus_neighbor_bottom = button.get_path_to(_spatial_audio_toggle)

func _on_state_changed(_action: Dictionary, state: Dictionary) -> void:
	var action_type: StringName = StringName("")
	if _action != null and _action.has("type"):
		action_type = _action.get("type", StringName(""))

	# Preserve local edits (Apply/Cancel pattern). Only reconcile from state when
	# the user is not actively editing.
	if _has_local_edits and action_type != StringName(""):
		return

	if state == null:
		return

	# Update UI from state (without triggering signals)
	_updating_from_state = true

	# Update Master
	var master_vol := U_AudioSelectors.get_master_volume(state)
	_set_slider_value_silently(_master_volume_slider, master_vol)
	_update_percentage_label(_master_percentage, master_vol)
	_set_toggle_value_silently(_master_mute_toggle, U_AudioSelectors.is_master_muted(state))

	# Update Music
	var music_vol := U_AudioSelectors.get_music_volume(state)
	_set_slider_value_silently(_music_volume_slider, music_vol)
	_update_percentage_label(_music_percentage, music_vol)
	_set_toggle_value_silently(_music_mute_toggle, U_AudioSelectors.is_music_muted(state))

	# Update SFX
	var sfx_vol := U_AudioSelectors.get_sfx_volume(state)
	_set_slider_value_silently(_sfx_volume_slider, sfx_vol)
	_update_percentage_label(_sfx_percentage, sfx_vol)
	_set_toggle_value_silently(_sfx_mute_toggle, U_AudioSelectors.is_sfx_muted(state))

	# Update Ambient
	var ambient_vol := U_AudioSelectors.get_ambient_volume(state)
	_set_slider_value_silently(_ambient_volume_slider, ambient_vol)
	_update_percentage_label(_ambient_percentage, ambient_vol)
	_set_toggle_value_silently(_ambient_mute_toggle, U_AudioSelectors.is_ambient_muted(state))

	# Update Spatial
	_set_toggle_value_silently(_spatial_audio_toggle, U_AudioSelectors.is_spatial_audio_enabled(state))

	_updating_from_state = false
	_has_local_edits = false

	# Update mute visuals (dimming)
	_update_mute_visuals(state)

# Master handlers
func _on_master_volume_changed(value: float) -> void:
	_update_percentage_label(_master_percentage, value)
	if _updating_from_state:
		return
	U_UISoundPlayer.play_slider_tick()
	_has_local_edits = true
	_update_audio_settings_preview_from_ui()

func _on_master_mute_toggled(pressed: bool) -> void:
	if _updating_from_state:
		return
	_has_local_edits = true
	_update_mute_visuals_from_ui()
	_update_audio_settings_preview_from_ui()

# Music handlers
func _on_music_volume_changed(value: float) -> void:
	_update_percentage_label(_music_percentage, value)
	if _updating_from_state:
		return
	U_UISoundPlayer.play_slider_tick()
	_has_local_edits = true
	_update_audio_settings_preview_from_ui()

func _on_music_mute_toggled(pressed: bool) -> void:
	if _updating_from_state:
		return
	_has_local_edits = true
	_update_mute_visuals_from_ui()
	_update_audio_settings_preview_from_ui()

# SFX handlers
func _on_sfx_volume_changed(value: float) -> void:
	_update_percentage_label(_sfx_percentage, value)
	if _updating_from_state:
		return
	U_UISoundPlayer.play_slider_tick()
	_has_local_edits = true
	_update_audio_settings_preview_from_ui()

func _on_sfx_mute_toggled(pressed: bool) -> void:
	if _updating_from_state:
		return
	_has_local_edits = true
	_update_mute_visuals_from_ui()
	_update_audio_settings_preview_from_ui()

# Ambient handlers
func _on_ambient_volume_changed(value: float) -> void:
	_update_percentage_label(_ambient_percentage, value)
	if _updating_from_state:
		return
	U_UISoundPlayer.play_slider_tick()
	_has_local_edits = true
	_update_audio_settings_preview_from_ui()

func _on_ambient_mute_toggled(pressed: bool) -> void:
	if _updating_from_state:
		return
	_has_local_edits = true
	_update_mute_visuals_from_ui()
	_update_audio_settings_preview_from_ui()

# Spatial handler
func _on_spatial_audio_toggled(pressed: bool) -> void:
	if _updating_from_state:
		return
	_has_local_edits = true
	_update_audio_settings_preview_from_ui()

func _on_apply_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	if _state_store == null:
		_clear_audio_settings_preview()
		_close_overlay()
		return

	# Capture all values BEFORE dispatching any actions
	# (dispatching triggers state_changed which can modify UI values)
	var master_volume := _master_volume_slider.value
	var music_volume := _music_volume_slider.value
	var sfx_volume := _sfx_volume_slider.value
	var ambient_volume := _ambient_volume_slider.value
	var master_muted := _master_mute_toggle.button_pressed
	var music_muted := _music_mute_toggle.button_pressed
	var sfx_muted := _sfx_mute_toggle.button_pressed
	var ambient_muted := _ambient_mute_toggle.button_pressed
	var spatial_enabled := _spatial_audio_toggle.button_pressed

	_has_local_edits = false
	_state_store.dispatch(U_AudioActions.set_master_volume(master_volume))
	_state_store.dispatch(U_AudioActions.set_music_volume(music_volume))
	_state_store.dispatch(U_AudioActions.set_sfx_volume(sfx_volume))
	_state_store.dispatch(U_AudioActions.set_ambient_volume(ambient_volume))
	_state_store.dispatch(U_AudioActions.set_master_muted(master_muted))
	_state_store.dispatch(U_AudioActions.set_music_muted(music_muted))
	_state_store.dispatch(U_AudioActions.set_sfx_muted(sfx_muted))
	_state_store.dispatch(U_AudioActions.set_ambient_muted(ambient_muted))
	_state_store.dispatch(U_AudioActions.set_spatial_audio_enabled(spatial_enabled))
	_clear_audio_settings_preview()
	_close_overlay()

func _on_cancel_pressed() -> void:
	U_UISoundPlayer.play_cancel()
	_has_local_edits = false
	_clear_audio_settings_preview()
	_close_overlay()

func _on_reset_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	var defaults := RS_AudioInitialState.new()

	_updating_from_state = true
	_set_slider_value_silently(_master_volume_slider, defaults.master_volume)
	_set_slider_value_silently(_music_volume_slider, defaults.music_volume)
	_set_slider_value_silently(_sfx_volume_slider, defaults.sfx_volume)
	_set_slider_value_silently(_ambient_volume_slider, defaults.ambient_volume)
	_set_toggle_value_silently(_master_mute_toggle, defaults.master_muted)
	_set_toggle_value_silently(_music_mute_toggle, defaults.music_muted)
	_set_toggle_value_silently(_sfx_mute_toggle, defaults.sfx_muted)
	_set_toggle_value_silently(_ambient_mute_toggle, defaults.ambient_muted)
	_set_toggle_value_silently(_spatial_audio_toggle, defaults.spatial_audio_enabled)
	_updating_from_state = false

	_update_percentage_label(_master_percentage, defaults.master_volume)
	_update_percentage_label(_music_percentage, defaults.music_volume)
	_update_percentage_label(_sfx_percentage, defaults.sfx_volume)
	_update_percentage_label(_ambient_percentage, defaults.ambient_volume)
	_update_mute_visuals_from_values(
		defaults.master_muted,
		defaults.music_muted,
		defaults.sfx_muted,
		defaults.ambient_muted
	)

	_has_local_edits = false
	if _state_store != null:
		_state_store.dispatch(U_AudioActions.set_master_volume(defaults.master_volume))
		_state_store.dispatch(U_AudioActions.set_music_volume(defaults.music_volume))
		_state_store.dispatch(U_AudioActions.set_sfx_volume(defaults.sfx_volume))
		_state_store.dispatch(U_AudioActions.set_ambient_volume(defaults.ambient_volume))
		_state_store.dispatch(U_AudioActions.set_master_muted(defaults.master_muted))
		_state_store.dispatch(U_AudioActions.set_music_muted(defaults.music_muted))
		_state_store.dispatch(U_AudioActions.set_sfx_muted(defaults.sfx_muted))
		_state_store.dispatch(U_AudioActions.set_ambient_muted(defaults.ambient_muted))
		_state_store.dispatch(U_AudioActions.set_spatial_audio_enabled(defaults.spatial_audio_enabled))
	_clear_audio_settings_preview()

func _set_slider_value_silently(slider: HSlider, value: float) -> void:
	if slider == null:
		return
	slider.set_block_signals(true)
	slider.value = value
	slider.set_block_signals(false)

func _set_toggle_value_silently(toggle: BaseButton, pressed: bool) -> void:
	if toggle == null:
		return
	toggle.set_block_signals(true)
	toggle.button_pressed = pressed
	toggle.set_block_signals(false)

func _update_percentage_label(label: Label, value: float) -> void:
	if label == null:
		return
	label.text = "%d%%" % int(value * 100.0)

func _update_mute_visuals(state: Dictionary) -> void:
	var master_muted := U_AudioSelectors.is_master_muted(state)

	# Master row: dim only if master muted
	if _master_row != null:
		_master_row.modulate.a = 0.4 if master_muted else 1.0

	# Child rows: dim if master OR individual muted
	var music_dimmed := master_muted or U_AudioSelectors.is_music_muted(state)
	var sfx_dimmed := master_muted or U_AudioSelectors.is_sfx_muted(state)
	var ambient_dimmed := master_muted or U_AudioSelectors.is_ambient_muted(state)

	if _music_row != null:
		_music_row.modulate.a = 0.4 if music_dimmed else 1.0
	if _sfx_row != null:
		_sfx_row.modulate.a = 0.4 if sfx_dimmed else 1.0
	if _ambient_row != null:
		_ambient_row.modulate.a = 0.4 if ambient_dimmed else 1.0

func _update_mute_visuals_from_ui() -> void:
	_update_mute_visuals_from_values(
		_master_mute_toggle.button_pressed if _master_mute_toggle != null else false,
		_music_mute_toggle.button_pressed if _music_mute_toggle != null else false,
		_sfx_mute_toggle.button_pressed if _sfx_mute_toggle != null else false,
		_ambient_mute_toggle.button_pressed if _ambient_mute_toggle != null else false
	)

func _update_mute_visuals_from_values(master_muted: bool, music_muted: bool, sfx_muted: bool, ambient_muted: bool) -> void:
	# Master row: dim only if master muted
	if _master_row != null:
		_master_row.modulate.a = 0.4 if master_muted else 1.0

	# Child rows: dim if master OR individual muted
	if _music_row != null:
		_music_row.modulate.a = 0.4 if (master_muted or music_muted) else 1.0
	if _sfx_row != null:
		_sfx_row.modulate.a = 0.4 if (master_muted or sfx_muted) else 1.0
	if _ambient_row != null:
		_ambient_row.modulate.a = 0.4 if (master_muted or ambient_muted) else 1.0

func _close_overlay() -> void:
	if _state_store == null:
		return

	var nav_slice: Dictionary = _state_store.get_state().get("navigation", {})
	var overlay_stack: Array = U_NavigationSelectors.get_overlay_stack(nav_slice)

	if not overlay_stack.is_empty():
		_state_store.dispatch(U_NavigationActions.close_top_overlay())
	else:
		_state_store.dispatch(U_NavigationActions.set_shell(StringName("main_menu"), StringName("settings_menu")))

func _get_audio_manager() -> Node:
	if _audio_manager != null and is_instance_valid(_audio_manager):
		return _audio_manager
	_audio_manager = U_ServiceLocator.try_get_service(StringName("audio_manager"))
	return _audio_manager

func _update_audio_settings_preview_from_ui() -> void:
	var audio_mgr := _get_audio_manager() as I_AUDIO_MANAGER
	if audio_mgr == null:
		return

	audio_mgr.set_audio_settings_preview({
		"master_volume": _master_volume_slider.value if _master_volume_slider != null else 1.0,
		"master_muted": _master_mute_toggle.button_pressed if _master_mute_toggle != null else false,
		"music_volume": _music_volume_slider.value if _music_volume_slider != null else 1.0,
		"music_muted": _music_mute_toggle.button_pressed if _music_mute_toggle != null else false,
		"sfx_volume": _sfx_volume_slider.value if _sfx_volume_slider != null else 1.0,
		"sfx_muted": _sfx_mute_toggle.button_pressed if _sfx_mute_toggle != null else false,
		"ambient_volume": _ambient_volume_slider.value if _ambient_volume_slider != null else 1.0,
		"ambient_muted": _ambient_mute_toggle.button_pressed if _ambient_mute_toggle != null else false,
		"spatial_audio_enabled": _spatial_audio_toggle.button_pressed if _spatial_audio_toggle != null else true,
	})

func _clear_audio_settings_preview() -> void:
	var audio_mgr := _get_audio_manager() as I_AUDIO_MANAGER
	if audio_mgr == null:
		return
	audio_mgr.clear_audio_settings_preview()
