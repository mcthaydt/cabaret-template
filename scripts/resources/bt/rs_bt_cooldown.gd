@icon("res://assets/editor_icons/icn_resource.svg")
extends "res://scripts/resources/bt/rs_bt_decorator.gd"
class_name RS_BTCooldown

const CONTEXT_KEY_TIME := &"time"
const STATE_KEY_COOLDOWN_UNTIL := &"cooldown_until"

@export var duration: float = 0.0

func tick(context: Dictionary, state_bag: Dictionary) -> Status:
	if child == null:
		push_error("RS_BTCooldown.tick: child is null")
		return Status.FAILURE

	var now: float = _resolve_time(context)
	var cooldown_until: float = _get_cooldown_until(state_bag)
	if now < cooldown_until:
		return Status.FAILURE

	var child_status: int = child.tick(context, state_bag)
	if child_status == Status.SUCCESS:
		_set_cooldown_until(state_bag, now + maxf(duration, 0.0))
		return Status.SUCCESS
	if child_status == Status.RUNNING:
		return Status.RUNNING
	if child_status == Status.FAILURE:
		return Status.FAILURE

	push_error("RS_BTCooldown.tick: child returned invalid status %s" % str(child_status))
	return Status.FAILURE

func _resolve_time(context: Dictionary) -> float:
	var time_variant: Variant = context.get(CONTEXT_KEY_TIME, 0.0)
	if time_variant is float or time_variant is int:
		return float(time_variant)
	return 0.0

func _set_cooldown_until(state_bag: Dictionary, cooldown_until: float) -> void:
	state_bag[node_id] = {
		STATE_KEY_COOLDOWN_UNTIL: cooldown_until,
	}

func _get_cooldown_until(state_bag: Dictionary) -> float:
	var local_state: Dictionary = _get_local_state(state_bag)
	var cooldown_until_variant: Variant = local_state.get(STATE_KEY_COOLDOWN_UNTIL, -1.0)
	if cooldown_until_variant is float or cooldown_until_variant is int:
		return float(cooldown_until_variant)
	return -1.0

func _get_local_state(state_bag: Dictionary) -> Dictionary:
	var state_variant: Variant = state_bag.get(node_id, {})
	if state_variant is Dictionary:
		return state_variant as Dictionary
	return {}
