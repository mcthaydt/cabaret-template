extends RefCounted
class_name U_InputCaptureGuard

## Tracks whether any UI element is actively capturing raw input.

static var _active_capture_count: int = 0

static func begin_capture() -> void:
	_active_capture_count += 1

static func end_capture() -> void:
	if _active_capture_count <= 0:
		_active_capture_count = 0
		return
	_active_capture_count -= 1

static func is_capture_active() -> bool:
	return _active_capture_count > 0
