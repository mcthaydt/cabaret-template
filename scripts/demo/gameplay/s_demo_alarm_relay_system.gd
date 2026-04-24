@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_DemoAlarmRelaySystem

const U_GAMEPLAY_ACTIONS := preload("res://scripts/core/state/actions/u_gameplay_actions.gd")

@export var state_store: I_StateStore = null
@export var relay_event_name: StringName = StringName("ai_alarm_triggered")
@export var relay_flag_ids: Array[StringName] = [
	StringName("power_core_activated"),
	StringName("power_core_proximity"),
	StringName("comms_disturbance_heard"),
	StringName("comms_disturbance_proximity"),
]
@export var relay_flag_value: bool = true

var _store: I_StateStore = null
var _event_unsubscribes: Array[Callable] = []

func _init() -> void:
	execution_priority = -11

func on_configured() -> void:
	_subscribe_events()

func process_tick(_delta: float) -> void:
	# Event-driven system.
	pass

func _subscribe_events() -> void:
	if relay_event_name == StringName(""):
		return
	_event_unsubscribes.append(
		U_ECSEventBus.subscribe(relay_event_name, _on_alarm_event)
	)

func _on_alarm_event(_payload: Variant) -> void:
	var store: I_StateStore = _resolve_state_store()
	if store == null:
		return
	for flag_id_variant in relay_flag_ids:
		var flag_id: StringName = flag_id_variant
		if flag_id == StringName(""):
			continue
		store.dispatch(U_GAMEPLAY_ACTIONS.set_ai_demo_flag(flag_id, relay_flag_value))

func _resolve_state_store() -> I_StateStore:
	_store = U_DependencyResolution.resolve_state_store(_store, state_store, self)
	return _store

func _exit_tree() -> void:
	for unsubscribe in _event_unsubscribes:
		if unsubscribe != null and unsubscribe.is_valid():
			unsubscribe.call()
	_event_unsubscribes.clear()
