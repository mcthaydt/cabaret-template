extends RefCounted
class_name U_UISoundPlayer

## Lightweight UI sound helper.
##
## Wraps M_AudioManager UI sound playback with a small API so UI scripts can
## trigger focus/confirm/cancel/tick sounds without direct manager references.

const U_ServiceLocator := preload("res://scripts/core/u_service_locator.gd")
const I_AUDIO_MANAGER := preload("res://scripts/interfaces/i_audio_manager.gd")

const _TICK_THROTTLE_MS: int = 100  # Max 10 ticks / second

static var _last_tick_time_ms: int = 0


static func reset_tick_throttle() -> void:
	_last_tick_time_ms = 0


static func play_focus() -> void:
	_play(StringName("ui_focus"))


static func play_confirm() -> void:
	_play(StringName("ui_confirm"))


static func play_cancel() -> void:
	_play(StringName("ui_cancel"))


static func play_slider_tick() -> void:
	var current_time_ms: int = Time.get_ticks_msec()
	if current_time_ms - _last_tick_time_ms < _TICK_THROTTLE_MS:
		return

	if _play(StringName("ui_tick")):
		_last_tick_time_ms = current_time_ms


static func _play(sound_id: StringName) -> bool:
	var audio_mgr := _get_audio_manager() as I_AUDIO_MANAGER
	if audio_mgr == null:
		return false
	audio_mgr.play_ui_sound(sound_id)
	return true


static func _get_audio_manager() -> Node:
	return U_ServiceLocator.try_get_service(StringName("audio_manager"))
