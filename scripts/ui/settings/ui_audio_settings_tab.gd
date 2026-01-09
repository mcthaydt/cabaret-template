@icon("res://resources/editor_icons/utility.svg")
extends VBoxContainer
class_name UI_AudioSettingsTab

const U_ServiceLocator := preload("res://scripts/core/u_service_locator.gd")
const U_AudioSelectors := preload("res://scripts/state/selectors/u_audio_selectors.gd")
const U_AudioActions := preload("res://scripts/state/actions/u_audio_actions.gd")
const U_FocusConfigurator := preload("res://scripts/ui/helpers/u_focus_configurator.gd")
const U_UISoundPlayer := preload("res://scripts/ui/utils/u_ui_sound_player.gd")

var _state_store: I_StateStore = null
var _unsubscribe: Callable = Callable()

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

func _ready() -> void:
	_connect_signals()
	_configure_focus_neighbors()

	_state_store = U_ServiceLocator.get_service(StringName("state_store")) as I_StateStore
	if _state_store == null:
		push_error("UI_AudioSettingsTab: StateStore not found")
		return

	_unsubscribe = _state_store.subscribe(_on_state_changed)
	_on_state_changed({}, _state_store.get_state())

func _exit_tree() -> void:
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

func _on_state_changed(_action: Dictionary, state: Dictionary) -> void:
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

# Master handlers
func _on_master_volume_changed(value: float) -> void:
	U_UISoundPlayer.play_slider_tick()
	if _state_store != null:
		_state_store.dispatch(U_AudioActions.set_master_volume(value))
	_update_percentage_label(_master_percentage, value)

func _on_master_mute_toggled(pressed: bool) -> void:
	if _state_store != null:
		_state_store.dispatch(U_AudioActions.set_master_muted(pressed))

# Music handlers
func _on_music_volume_changed(value: float) -> void:
	U_UISoundPlayer.play_slider_tick()
	if _state_store != null:
		_state_store.dispatch(U_AudioActions.set_music_volume(value))
	_update_percentage_label(_music_percentage, value)

func _on_music_mute_toggled(pressed: bool) -> void:
	if _state_store != null:
		_state_store.dispatch(U_AudioActions.set_music_muted(pressed))

# SFX handlers
func _on_sfx_volume_changed(value: float) -> void:
	U_UISoundPlayer.play_slider_tick()
	if _state_store != null:
		_state_store.dispatch(U_AudioActions.set_sfx_volume(value))
	_update_percentage_label(_sfx_percentage, value)

func _on_sfx_mute_toggled(pressed: bool) -> void:
	if _state_store != null:
		_state_store.dispatch(U_AudioActions.set_sfx_muted(pressed))

# Ambient handlers
func _on_ambient_volume_changed(value: float) -> void:
	U_UISoundPlayer.play_slider_tick()
	if _state_store != null:
		_state_store.dispatch(U_AudioActions.set_ambient_volume(value))
	_update_percentage_label(_ambient_percentage, value)

func _on_ambient_mute_toggled(pressed: bool) -> void:
	if _state_store != null:
		_state_store.dispatch(U_AudioActions.set_ambient_muted(pressed))

# Spatial handler
func _on_spatial_audio_toggled(pressed: bool) -> void:
	if _state_store != null:
		_state_store.dispatch(U_AudioActions.set_spatial_audio_enabled(pressed))

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
