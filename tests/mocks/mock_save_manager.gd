extends Node

## Mock Save Manager for autosave scheduler tests
## Tracks autosave requests without actually performing saves

var autosave_request_count: int = 0
var last_autosave_priority: int = 0
var _is_saving: bool = false
var _is_loading: bool = false

func _init() -> void:
	name = "MockSaveManager"
	add_to_group("save_manager")

func _ready() -> void:
	# Register with ServiceLocator if available
	if has_node("/root/U_ServiceLocator"):
		var locator = get_node("/root/U_ServiceLocator")
		if locator.has_method("register"):
			locator.register(StringName("save_manager"), self)

func request_autosave(priority: int = 0) -> void:
	autosave_request_count += 1
	last_autosave_priority = priority

func is_locked() -> bool:
	return _is_saving or _is_loading

func set_locked(locked: bool) -> void:
	_is_saving = locked
	_is_loading = locked

func reset() -> void:
	autosave_request_count = 0
	last_autosave_priority = 0
	_is_saving = false
	_is_loading = false
