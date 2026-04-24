extends RefCounted
class_name U_VCamRuntimeState

const U_INPUT_SELECTORS := preload("res://scripts/core/state/selectors/u_input_selectors.gd")
const U_VCAM_ACTIONS := preload("res://scripts/core/state/actions/u_vcam_actions.gd")
const I_VCAM_MANAGER := preload("res://scripts/core/interfaces/i_vcam_manager.gd")

var _last_active_target_valid: bool = true
var _last_target_recovery_reason: String = ""
var _last_target_recovery_vcam_id: StringName = StringName("")

func reset_observability_state() -> void:
	_last_active_target_valid = true
	_last_target_recovery_reason = ""
	_last_target_recovery_vcam_id = StringName("")

func read_look_input(store: I_StateStore, state_snapshot: Dictionary = {}) -> Vector2:
	if store == null and state_snapshot.is_empty():
		return Vector2.ZERO
	var state: Dictionary = state_snapshot
	if state.is_empty() and store != null:
		state = store.get_state()
	return U_INPUT_SELECTORS.get_look_input(state)

func read_move_input(store: I_StateStore, state_snapshot: Dictionary = {}) -> Vector2:
	if store == null and state_snapshot.is_empty():
		return Vector2.ZERO
	var state: Dictionary = state_snapshot
	if state.is_empty() and store != null:
		state = store.get_state()
	return U_INPUT_SELECTORS.get_move_input(state)

func read_camera_center_just_pressed(store: I_StateStore, state_snapshot: Dictionary = {}) -> bool:
	if store == null and state_snapshot.is_empty():
		return false
	var state: Dictionary = state_snapshot
	if state.is_empty() and store != null:
		state = store.get_state()
	return U_INPUT_SELECTORS.is_camera_center_just_pressed(state)

func update_active_target_observability(
	vcam_id: StringName,
	manager: I_VCAM_MANAGER,
	is_valid: bool,
	recovery_reason: String = "",
	store: I_StateStore = null
) -> void:
	if manager == null:
		return
	if vcam_id != manager.get_active_vcam_id():
		return

	if _last_active_target_valid != is_valid:
		_last_active_target_valid = is_valid
		if store != null:
			store.dispatch(U_VCAM_ACTIONS.update_target_validity(is_valid))
	if is_valid:
		_last_target_recovery_reason = ""
		_last_target_recovery_vcam_id = StringName("")
		return
	if recovery_reason.is_empty():
		return
	if recovery_reason == _last_target_recovery_reason and vcam_id == _last_target_recovery_vcam_id:
		return
	_last_target_recovery_reason = recovery_reason
	_last_target_recovery_vcam_id = vcam_id
	if store != null:
		store.dispatch(U_VCAM_ACTIONS.record_recovery(recovery_reason))
	manager.set_active_vcam(StringName(""))
