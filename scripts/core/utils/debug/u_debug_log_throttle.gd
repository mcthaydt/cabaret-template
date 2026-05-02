extends RefCounted
class_name U_DebugLogThrottle

var _cooldowns_by_key: Dictionary = {}


func consume_budget(key: StringName, interval_sec: float) -> bool:
	var cooldown: float = float(_cooldowns_by_key.get(key, 0.0))
	if cooldown > 0.0:
		return false
	_cooldowns_by_key[key] = maxf(interval_sec, 0.0)
	return true


func tick(delta: float) -> void:
	if _cooldowns_by_key.is_empty():
		return
	var step: float = maxf(delta, 0.0)
	var stale_keys: Array = []
	for key_variant in _cooldowns_by_key.keys():
		var key: StringName = key_variant
		var cooldown: float = maxf(float(_cooldowns_by_key.get(key, 0.0)) - step, 0.0)
		if cooldown > 0.0:
			_cooldowns_by_key[key] = cooldown
			continue
		stale_keys.append(key)
	for key_variant in stale_keys:
		_cooldowns_by_key.erase(key_variant)


func clear() -> void:
	_cooldowns_by_key.clear()


func log_message(message: String) -> void:
	print(message)
