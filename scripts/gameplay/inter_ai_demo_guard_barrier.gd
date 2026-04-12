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
	var gameplay_variant: Variant = state.get("gameplay", {})
	if not (gameplay_variant is Dictionary):
		return false
	var gameplay: Dictionary = gameplay_variant as Dictionary
	var flags_variant: Variant = gameplay.get("ai_demo_flags", {})
	if not (flags_variant is Dictionary):
		return false
	var flags: Dictionary = flags_variant as Dictionary
	return bool(flags.get(flag_id, false))

func _resolve_state_store() -> I_StateStore:
	_store = U_DependencyResolution.resolve_state_store(_store, null, self)
	return _store
