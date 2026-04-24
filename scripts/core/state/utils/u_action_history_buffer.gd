extends RefCounted
class_name U_ActionHistoryBuffer

## Action history buffer for M_StateStore.
##
## Ring buffer storing bounded action entries with timestamps and deep-copied
## state snapshots. Intended for debug tooling and profiling.
## Disabled on mobile to avoid expensive deep copies.

var _buffer: Array = []
var _head: int = 0  # Next write position
var _count: int = 0  # Number of valid entries
var _max_history_size: int = 1000
var _enabled: bool = true

func configure(max_history_size: int, enabled: bool) -> void:
	_max_history_size = maxi(0, max_history_size)
	_enabled = enabled
	if _max_history_size == 0 or not _enabled:
		_buffer.clear()
		_head = 0
		_count = 0
	else:
		_buffer.resize(_max_history_size)
		# Reset ring buffer state
		_head = 0
		_count = 0

func record_action(action: Dictionary, state: Dictionary) -> void:
	if not _enabled or _max_history_size <= 0:
		return

	var timestamp: float = U_ECSUtils.get_current_time()
	var state_snapshot: Dictionary = state.duplicate(true)

	var history_entry: Dictionary = {
		"action": action.duplicate(true),
		"timestamp": timestamp,
		"state_after": state_snapshot
	}

	if _buffer.size() < _max_history_size:
		_buffer.resize(_max_history_size)

	_buffer[_head] = history_entry
	_head = (_head + 1) % _max_history_size
	_count = mini(_count + 1, _max_history_size)

func get_action_history() -> Array:
	if _count == 0:
		return []

	var result: Array = []
	result.resize(_count)
	var start: int = (_head - _count + _max_history_size) % _max_history_size
	for i in range(_count):
		var idx: int = (start + i) % _max_history_size
		result[i] = _buffer[idx]

	return result

func get_last_n_actions(n: int) -> Array:
	if n <= 0 or _count == 0:
		return []

	var actual_n: int = mini(n, _count)
	var result: Array = []
	result.resize(actual_n)
	# Last N entries end at _head - 1
	var end_offset: int = _head - 1
	for i in range(actual_n):
		var idx: int = (end_offset - i + _max_history_size) % _max_history_size
		result[actual_n - 1 - i] = _buffer[idx]

	return result

func clear() -> void:
	_buffer.clear()
	_head = 0
	_count = 0
