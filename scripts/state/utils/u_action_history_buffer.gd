extends RefCounted
class_name U_ActionHistoryBuffer

## Action history buffer for M_StateStore.
##
## Stores a bounded list of action entries with a timestamp and a deep-copied
## state snapshot. Intended for debug tooling and profiling.

var _action_history: Array = []
var _max_history_size: int = 1000
var _enabled: bool = true

func configure(max_history_size: int, enabled: bool) -> void:
	_max_history_size = maxi(0, max_history_size)
	_enabled = enabled
	_prune_if_needed()

func record_action(action: Dictionary, state: Dictionary) -> void:
	if not _enabled:
		return

	var timestamp: float = U_ECSUtils.get_current_time()
	var state_snapshot: Dictionary = state.duplicate(true)

	var history_entry: Dictionary = {
		"action": action.duplicate(true),
		"timestamp": timestamp,
		"state_after": state_snapshot
	}

	_action_history.append(history_entry)
	_prune_if_needed()

func get_action_history() -> Array:
	# Shallow copy for performance; entries themselves contain deep-copied snapshots.
	return _action_history.duplicate(false)

func get_last_n_actions(n: int) -> Array:
	if n <= 0:
		return []

	var history_size: int = _action_history.size()
	if n >= history_size:
		return _action_history.duplicate(false)

	var start_index: int = history_size - n
	var result: Array = []
	for i in range(start_index, history_size):
		# Shallow copy entries; state snapshots inside entries are already deep copies.
		result.append(_action_history[i])

	return result

func clear() -> void:
	_action_history.clear()

func _prune_if_needed() -> void:
	if _max_history_size <= 0:
		_action_history.clear()
		return

	# Prune oldest entries if exceeding max size (circular buffer).
	while _action_history.size() > _max_history_size:
		_action_history.remove_at(0)
