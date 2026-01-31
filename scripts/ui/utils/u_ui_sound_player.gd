extends RefCounted
class_name U_UISoundPlayer

## Lightweight UI sound helper (Phase 8)
##
## Wraps M_AudioManager UI sound playback with a small API so UI scripts can
## trigger focus/confirm/cancel/tick sounds without direct manager references.
##
## Supports per-sound throttling via RS_UISoundDefinition.throttle_ms field.

const U_ServiceLocator := preload("res://scripts/core/u_service_locator.gd")
const I_AUDIO_MANAGER := preload("res://scripts/interfaces/i_audio_manager.gd")
const U_AUDIO_REGISTRY_LOADER := preload("res://scripts/managers/helpers/u_audio_registry_loader.gd")

static var _last_play_times: Dictionary = {}  ## sound_id -> timestamp_ms
static var _registry_initialized: bool = false


static func reset_throttles() -> void:
	_last_play_times.clear()


## Deprecated: Use reset_throttles() instead
static func reset_tick_throttle() -> void:
	reset_throttles()


static func play_focus() -> void:
	_play(StringName("ui_focus"))


static func play_confirm() -> void:
	_play(StringName("ui_confirm"))


static func play_cancel() -> void:
	_play(StringName("ui_cancel"))


static func play_slider_tick() -> void:
	_play(StringName("ui_tick"))


static func _play(sound_id: StringName) -> bool:
	_ensure_registry_initialized()

	# Load sound definition to check throttle settings
	var sound_def := U_AUDIO_REGISTRY_LOADER.get_ui_sound(sound_id)
	if sound_def == null:
		return false

	# Check throttle
	if sound_def.throttle_ms > 0:
		var current_time_ms: int = Time.get_ticks_msec()
		var last_time: int = _last_play_times.get(sound_id, 0)
		if current_time_ms - last_time < sound_def.throttle_ms:
			return false  # Throttled
		_last_play_times[sound_id] = current_time_ms

	var audio_mgr := _get_audio_manager() as I_AUDIO_MANAGER
	if audio_mgr == null:
		return false
	audio_mgr.play_ui_sound(sound_id)
	return true


static func _ensure_registry_initialized() -> void:
	if _registry_initialized:
		return
	U_AUDIO_REGISTRY_LOADER.initialize()
	_registry_initialized = true


static func _get_audio_manager() -> Node:
	return U_ServiceLocator.try_get_service(StringName("audio_manager"))
