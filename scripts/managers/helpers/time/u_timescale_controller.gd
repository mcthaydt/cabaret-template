extends RefCounted
class_name U_TimescaleController

const MIN_TIMESCALE := 0.01
const MAX_TIMESCALE := 10.0

var _timescale: float = 1.0

func set_timescale(scale: float) -> void:
	_timescale = clampf(scale, MIN_TIMESCALE, MAX_TIMESCALE)

func get_timescale() -> float:
	return _timescale

func get_scaled_delta(raw_delta: float) -> float:
	return raw_delta * _timescale
