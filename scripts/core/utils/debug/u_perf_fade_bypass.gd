extends RefCounted
class_name U_PerfFadeBypass

## Mobile perf diagnostic toggle for room/region fade systems.
## When enabled, visibility systems keep targets fully opaque.

static var _enabled: bool = false

static func set_enabled(enabled: bool) -> void:
	_enabled = enabled

static func is_enabled() -> bool:
	return _enabled

static func reset() -> void:
	_enabled = false
