extends RefCounted
class_name U_PerfProbe

## Lightweight block profiler for mobile performance diagnostics.
##
## Wraps code blocks with Time.get_ticks_usec() start/stop, accumulates
## samples over a flush window, and prints [PERF] summary lines.
##
## Zero-cost when disabled: start() and stop() return immediately.
## No allocation in hot path: integer counters only, no string formatting until flush.

const LOG_PREFIX := "[PERF]"
const U_MOBILE_PLATFORM_DETECTOR := preload("res://scripts/core/utils/display/u_mobile_platform_detector.gd")

var _name: String = ""
var _enabled: bool = false
var _start_usec: int = 0
var _running: bool = false

# Window accumulation (all in microseconds)
var _sample_count: int = 0
var _total_usec: int = 0
var _min_usec: int = 9223372036854775807
var _max_usec: int = 0

# Flush cadence
var _flush_interval_usec: int = 2_000_000  # 2 seconds default
var _last_flush_usec: int = 0


## Create a new probe. If enabled is not explicitly passed, auto-enables on mobile.
static func create(name: String, enabled: Variant = null, flush_interval_sec: float = 2.0) -> RefCounted:
	var probe := new()
	probe._name = name
	probe._enabled = _resolve_enabled(enabled)
	probe._flush_interval_usec = int(flush_interval_sec * 1_000_000.0)
	probe._last_flush_usec = Time.get_ticks_usec()
	return probe


static func _resolve_enabled(enabled: Variant) -> bool:
	if enabled == null:
		return U_MobilePlatformDetector.is_mobile()
	return bool(enabled)


func start() -> void:
	if not _enabled:
		return
	_start_usec = Time.get_ticks_usec()
	_running = true


func stop() -> void:
	if not _enabled:
		return
	if not _running:
		return
	_running = false
	var elapsed: int = Time.get_ticks_usec() - _start_usec
	if elapsed <= 0:
		elapsed = 1
	_sample_count += 1
	_total_usec += elapsed
	if elapsed < _min_usec:
		_min_usec = elapsed
	if elapsed > _max_usec:
		_max_usec = elapsed
	_check_flush()


func set_enabled(v: bool) -> void:
	_enabled = v
	if not v:
		_running = false


func is_enabled() -> bool:
	return _enabled


func reset() -> void:
	_sample_count = 0
	_total_usec = 0
	_min_usec = 9223372036854775807
	_max_usec = 0
	_running = false


func _check_flush() -> void:
	if _sample_count <= 0:
		return
	var now_usec: int = Time.get_ticks_usec()
	if now_usec - _last_flush_usec >= _flush_interval_usec:
		_flush()


func _flush() -> void:
	if _sample_count <= 0:
		return
	var avg_ms: float = (float(_total_usec) / float(_sample_count)) / 1000.0
	var min_ms: float = float(_min_usec) / 1000.0
	var max_ms: float = float(_max_usec) / 1000.0
	print("%s %s samples=%d avg=%.2fms min=%.2fms max=%.2fms" % [
		LOG_PREFIX, _name, _sample_count, avg_ms, min_ms, max_ms
	])
	_last_flush_usec = Time.get_ticks_usec()
	reset()
