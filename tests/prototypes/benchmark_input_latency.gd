extends RefCounted

## Prototype helper for measuring keyboard and mouse input latency.
##
## Tracks the delta between when an input event is received and when the game
## loop processes it (simulating `_physics_process`). Used to validate the
## < 16 ms target defined in the Input Manager plan.

const TARGET_LATENCY_MS := 16.0
const KEYBOARD_DEVICE := StringName("keyboard")
const MOUSE_DEVICE := StringName("mouse")
const MOUSE_SAMPLE_ID := StringName("mouse:motion")

var _keyboard_bindings: Dictionary = {}
var _latency_samples: Dictionary = {}
var _pending_samples: Array[Dictionary] = []
var _mouse_tracking_enabled: bool = false
var _time_provider: Callable

func _init(time_provider: Callable = Callable()) -> void:
	_time_provider = time_provider if time_provider.is_valid() else Callable(self, "_default_time_provider")

func configure_keyboard_binding(action_name: StringName, physical_keycode: int) -> void:
	_keyboard_bindings[action_name] = physical_keycode
	_ensure_sample_array(_sample_id(KEYBOARD_DEVICE, action_name))

func enable_mouse_motion_tracking(enable: bool) -> void:
	_mouse_tracking_enabled = enable
	if enable:
		_ensure_sample_array(MOUSE_SAMPLE_ID)

func ingest_input_event(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		_handle_keyboard_event(event)
	elif _mouse_tracking_enabled and event is InputEventMouseMotion:
		if event.relative.length_squared() > 0.0:
			_start_sample(MOUSE_SAMPLE_ID)

func process_frame() -> void:
	if _pending_samples.is_empty():
		return

	var now_us := _get_time()
	for pending in _pending_samples:
		var latency_ms : float = max(float(now_us - pending.start_us) / 1000.0, 0.0)
		_latency_samples[pending.sample_id].append(latency_ms)

	_pending_samples.clear()

func get_sample_summary(sample_id: StringName) -> Dictionary:
	var samples: Array = _latency_samples.get(sample_id, [])
	return _summarize_samples(samples)

func get_overall_summary() -> Dictionary:
	var all_samples: Array = []
	for sample_list in _latency_samples.values():
		all_samples += sample_list
	var summary := _summarize_samples(all_samples)
	summary["sample_count"] = all_samples.size()
	return summary

func reset() -> void:
	_latency_samples.clear()
	_pending_samples.clear()
	_keyboard_bindings.clear()
	_mouse_tracking_enabled = false

func _handle_keyboard_event(event: InputEventKey) -> void:
	for action_name in _keyboard_bindings.keys():
		if event.physical_keycode == _keyboard_bindings[action_name]:
			_start_sample(_sample_id(KEYBOARD_DEVICE, action_name))

func _start_sample(sample_id: StringName) -> void:
	_pending_samples.append({
		"id": sample_id,
		"start_us": _get_time(),
		"sample_id": sample_id,
	})
	_ensure_sample_array(sample_id)

func _ensure_sample_array(sample_id: StringName) -> void:
	if not _latency_samples.has(sample_id):
		_latency_samples[sample_id] = []

func _sample_id(device: StringName, action_name: StringName) -> StringName:
	return StringName("%s:%s" % [device, action_name])

func _summarize_samples(samples: Array) -> Dictionary:
	if samples.is_empty():
		return {
			"average_ms": 0.0,
			"max_ms": 0.0,
			"min_ms": 0.0,
			"within_target": true,
		}

	var total := 0.0
	var max_ms := -INF
	var min_ms := INF
	for sample in samples:
		var value : float = max(float(sample), 0.0)
		total += value
		max_ms = max(max_ms, value)
		min_ms = min(min_ms, value)

	var average := total / samples.size()
	return {
		"average_ms": average,
		"max_ms": max_ms,
		"min_ms": min_ms,
		"within_target": max_ms <= TARGET_LATENCY_MS,
	}

func _get_time() -> int:
	return int(_time_provider.call())

func _default_time_provider() -> int:
	return Time.get_ticks_usec()
