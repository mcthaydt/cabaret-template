extends RefCounted
class_name U_StorePerformanceMetrics

## Performance metrics helper for M_StateStore.
##
## Tracks dispatch latency and signal emission counts for lightweight profiling.

var _dispatch_count: int = 0
var _total_dispatch_time_us: int = 0
var _signal_emit_count: int = 0
var _last_dispatch_time_us: int = 0

func start_dispatch() -> int:
	return Time.get_ticks_usec()

func finish_dispatch(start_time_us: int) -> void:
	var end_time_us: int = Time.get_ticks_usec()
	_last_dispatch_time_us = end_time_us - start_time_us
	_total_dispatch_time_us += _last_dispatch_time_us
	_dispatch_count += 1

func record_signal_emitted(count: int = 1) -> void:
	_signal_emit_count += count

func get_performance_metrics() -> Dictionary:
	var avg_time_ms: float = 0.0
	if _dispatch_count > 0:
		avg_time_ms = (_total_dispatch_time_us / _dispatch_count) / 1000.0

	var last_time_ms: float = _last_dispatch_time_us / 1000.0

	return {
		"dispatch_count": _dispatch_count,
		"avg_dispatch_time_ms": avg_time_ms,
		"last_dispatch_time_ms": last_time_ms,
		"signal_emit_count": _signal_emit_count
	}

func reset() -> void:
	_dispatch_count = 0
	_total_dispatch_time_us = 0
	_signal_emit_count = 0
	_last_dispatch_time_us = 0
