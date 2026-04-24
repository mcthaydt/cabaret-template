extends CSGBox3D
class_name Inter_AIDemoGuardBarrier

@export var open_flag_id: StringName = StringName("showcase_guard_door_open")
@export var hide_when_open: bool = true
@export var disable_collision_when_open: bool = true

var _store: I_StateStore = null
var _is_open: bool = false

func _ready() -> void:
	_update_open_state()

func _physics_process(_delta: float) -> void:
	_update_open_state()

func _update_open_state() -> void:
	var should_open: bool = _is_flag_enabled(open_flag_id)
	if should_open == _is_open:
		return
	_is_open = should_open
	_apply_open_state()

func _apply_open_state() -> void:
	if hide_when_open:
		visible = not _is_open
	if disable_collision_when_open:
		use_collision = not _is_open

func _is_flag_enabled(flag_id: StringName) -> bool:
	if flag_id == StringName(""):
		return false
	var store: I_StateStore = _resolve_state_store()
	if store == null:
		return false
	var state: Dictionary = store.get_state()
	var flags: Dictionary = U_GameplaySelectors.get_ai_demo_flags(state)
	return bool(flags.get(flag_id, false))

func _resolve_state_store() -> I_StateStore:
	_store = U_DependencyResolution.resolve_state_store(_store, null, self)
	return _store
