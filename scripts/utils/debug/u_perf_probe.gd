extends RefCounted
class_name U_PerfProbe

## Lightweight performance probe for mobile diagnostics.
##
## Accumulates Time.get_ticks_usec() measurements and logs at ~1Hz.
## Zero-cost on desktop (gated on U_MobilePlatformDetector.is_mobile()).
## Usage:
##   var start := probe.begin()
##   ... do work ...
##   probe.end(start)
##   probe.tick_and_maybe_log()  # call once per process_tick

const U_MOBILE_PLATFORM_DETECTOR := preload("res://scripts/utils/display/u_mobile_platform_detector.gd")

var _label: String
var _total_usec: int = 0
var _count: int = 0
var _max_usec: int = 0
var _log_interval_frames: int = 60
var _frame_counter: int = 0
var _is_mobile: bool = false


func _init(label: String, log_interval_frames: int = 60) -> void:
	_label = label
	_log_interval_frames = log_interval_frames
	_is_mobile = U_MOBILE_PLATFORM_DETECTOR.is_mobile()


## Returns start ticks (usec). Returns 0 on desktop (no-op path).
func begin() -> int:
	if not _is_mobile:
		return 0
	return Time.get_ticks_usec()


## Accumulates elapsed time since begin(). No-op if start_ticks is 0.
func end(start_ticks: int) -> void:
	if not _is_mobile or start_ticks == 0:
		return
	var elapsed := Time.get_ticks_usec() - start_ticks
	_total_usec += elapsed
	_count += 1
	if elapsed > _max_usec:
		_max_usec = elapsed


## Call once per process_tick. Logs accumulated stats at the configured interval.
func tick_and_maybe_log() -> void:
	if not _is_mobile:
		return
	_frame_counter += 1
	if _frame_counter >= _log_interval_frames:
		_frame_counter = 0
		if _count > 0:
			var avg_ms := float(_total_usec) / float(_count) / 1000.0
			var max_ms := float(_max_usec) / 1000.0
			print("[PERF] %s: avg=%.3fms max=%.3fms count=%d" % [_label, avg_ms, max_ms, _count])
		_total_usec = 0
		_count = 0
		_max_usec = 0


## Reset all accumulated stats.
func reset() -> void:
	_total_usec = 0
	_count = 0
	_max_usec = 0
	_frame_counter = 0


## Returns true if this probe is active (mobile platform).
func is_active() -> bool:
	return _is_mobile