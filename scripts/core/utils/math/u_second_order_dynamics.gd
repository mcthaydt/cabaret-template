extends RefCounted
class_name U_SecondOrderDynamics

const MIN_FREQUENCY_HZ: float = 0.0001
const MAX_STEP_DELTA_SEC: float = 0.25

var _frequency_hz: float
var _damping_ratio: float
var _initial_response: float
var _y: float
var _yd: float
var _prev_target: float
var _k1: float
var _k2: float
var _k3: float

func _init(f: float, zeta: float, r: float, initial_value: float = 0.0) -> void:
	_frequency_hz = maxf(f, MIN_FREQUENCY_HZ)
	_damping_ratio = maxf(zeta, 0.0)
	_initial_response = r
	_y = initial_value
	_yd = 0.0
	_prev_target = initial_value
	_recompute_constants()

func step(target: float, dt: float) -> float:
	if dt <= 0.0:
		return _y

	var step_dt: float = minf(dt, MAX_STEP_DELTA_SEC)
	var target_velocity: float = (target - _prev_target) / step_dt
	_prev_target = target

	var stable_k2: float = maxf(
		_k2,
		maxf(
			step_dt * step_dt / 2.0 + step_dt * _k1 / 2.0,
			step_dt * _k1
		)
	)

	_y += step_dt * _yd
	_yd += step_dt * (target + _k3 * target_velocity - _y - _k1 * _yd) / stable_k2

	if is_nan(_y) or is_inf(_y):
		_y = target
	if is_nan(_yd) or is_inf(_yd):
		_yd = 0.0

	return _y

func reset(value: float) -> void:
	_y = value
	_yd = 0.0
	_prev_target = value

func get_value() -> float:
	return _y

func get_velocity() -> float:
	return _yd

func _recompute_constants() -> void:
	var omega: float = TAU * _frequency_hz
	_k1 = _damping_ratio / (PI * _frequency_hz)
	_k2 = 1.0 / (omega * omega)
	_k3 = _initial_response * _damping_ratio / omega

