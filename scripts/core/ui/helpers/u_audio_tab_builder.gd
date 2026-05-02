extends "res://scripts/core/ui/helpers/u_settings_tab_builder.gd"
class_name U_AudioTabBuilder

const U_UI_SETTINGS_CATALOG := preload("res://scripts/core/ui/helpers/u_ui_settings_catalog.gd")

var _on_master_volume_changed: Callable
var _on_music_volume_changed: Callable
var _on_sfx_volume_changed: Callable
var _on_ambient_volume_changed: Callable
var _on_master_mute_toggled: Callable
var _on_music_mute_toggled: Callable
var _on_sfx_mute_toggled: Callable
var _on_ambient_mute_toggled: Callable
var _on_spatial_audio_toggled: Callable
var _on_apply_pressed: Callable
var _on_cancel_pressed: Callable
var _on_reset_pressed: Callable

func _init(tab: Control) -> void:
	super._init(tab)

func set_callbacks(
	master_vol: Callable,
	music_vol: Callable,
	sfx_vol: Callable,
	ambient_vol: Callable,
	master_mute: Callable,
	music_mute: Callable,
	sfx_mute: Callable,
	ambient_mute: Callable,
	spatial: Callable,
	apply: Callable,
	cancel: Callable,
	reset: Callable
) -> U_AudioTabBuilder:
	_on_master_volume_changed = master_vol
	_on_music_volume_changed = music_vol
	_on_sfx_volume_changed = sfx_vol
	_on_ambient_volume_changed = ambient_vol
	_on_master_mute_toggled = master_mute
	_on_music_mute_toggled = music_mute
	_on_sfx_mute_toggled = sfx_mute
	_on_ambient_mute_toggled = ambient_mute
	_on_spatial_audio_toggled = spatial
	_on_apply_pressed = apply
	_on_cancel_pressed = cancel
	_on_reset_pressed = reset
	return self

func build() -> Control:
	set_heading(&"settings.audio.title")
	
	var vol_range := U_UI_SETTINGS_CATALOG.get_volume_range()
	
	begin_inline_group("MasterVolume")
	add_slider(
		&"settings.audio.label.master_volume",
		vol_range.min,
		vol_range.max,
		0.01,
		_on_master_volume_changed,
		&"settings.audio.value.percent",
		&"settings.audio.tooltip.master_volume",
		"",
		"MasterVolumeSlider"
	)
	add_toggle(&"settings.audio.label.mute", _on_master_mute_toggled, &"", "", "MasterMuteToggle")
	end_inline_group()
	
	begin_inline_group("MusicVolume")
	add_slider(
		&"settings.audio.label.music_volume",
		vol_range.min,
		vol_range.max,
		0.01,
		_on_music_volume_changed,
		&"settings.audio.value.percent",
		&"settings.audio.tooltip.music_volume",
		"",
		"MusicVolumeSlider"
	)
	add_toggle(&"settings.audio.label.mute", _on_music_mute_toggled, &"", "", "MusicMuteToggle")
	end_inline_group()
	
	begin_inline_group("SFXVolume")
	add_slider(
		&"settings.audio.label.sfx_volume",
		vol_range.min,
		vol_range.max,
		0.01,
		_on_sfx_volume_changed,
		&"settings.audio.value.percent",
		&"settings.audio.tooltip.sfx_volume",
		"",
		"SFXVolumeSlider"
	)
	add_toggle(&"settings.audio.label.mute", _on_sfx_mute_toggled, &"", "", "SFXMuteToggle")
	end_inline_group()
	
	begin_inline_group("AmbientVolume")
	add_slider(
		&"settings.audio.label.ambient_volume",
		vol_range.min,
		vol_range.max,
		0.01,
		_on_ambient_volume_changed,
		&"settings.audio.value.percent",
		&"settings.audio.tooltip.ambient_volume",
		"",
		"AmbientVolumeSlider"
	)
	add_toggle(&"settings.audio.label.mute", _on_ambient_mute_toggled, &"", "", "AmbientMuteToggle")
	end_inline_group()
	
	add_toggle(
		&"settings.audio.label.spatial_audio",
		_on_spatial_audio_toggled,
		&"settings.audio.tooltip.spatial_audio",
		"",
		"SpatialAudioToggle"
	)
	
	add_button_row(_on_apply_pressed, _on_cancel_pressed, _on_reset_pressed)
	
	return super.build()
