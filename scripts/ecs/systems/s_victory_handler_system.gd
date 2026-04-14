@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_VictoryHandlerSystem

## Injected state store (for testing)
## If set, system uses this instead of U_StateUtils.get_store()
@export var state_store: I_StateStore = null
@export var game_config: RS_GameConfig = null
const DEBUG_VICTORY_TRACE := false

var _store: I_StateStore = null
var _event_unsubscribes: Array[Callable] = []

func _init() -> void:
	execution_priority = 300
	if game_config == null:
		game_config = RS_GameConfig.new()

func process_tick(__delta: float) -> void:
	# Victory processing is event-driven via ECSEventBus.
	pass

func _debug_log(message: String) -> void:
	if not DEBUG_VICTORY_TRACE:
		return
	print("[VictoryDebug][S_VictoryHandlerSystem] %s" % message)

func _debug_gameplay_slice(label: String) -> void:
	if not DEBUG_VICTORY_TRACE:
		return
	if _store == null:
		_debug_log("%s gameplay=<no_store>" % label)
		return
	var state: Dictionary = _store.get_state()
	_debug_log(
		"%s gameplay.completed_areas=%s gameplay.game_completed=%s gameplay.last_victory_objective=%s"
		% [
			label,
			str(U_GameplaySelectors.get_completed_areas(state)),
			str(U_GameplaySelectors.get_game_completed(state)),
			str(U_GameplaySelectors.get_last_victory_objective(state)),
		]
	)

func _debug_objectives_slice(label: String) -> void:
	if not DEBUG_VICTORY_TRACE:
		return
	if _store == null:
		_debug_log("%s objectives=<no_store>" % label)
		return
	var state: Dictionary = _store.get_state()
	_debug_log(
		"%s objectives.statuses=%s objectives.active_set_id=%s"
		% [
			label,
			str(U_ObjectivesSelectors.get_statuses_snapshot(state)),
			str(U_ObjectivesSelectors.get_active_set_id(state)),
		]
	)

func _victory_type_to_string(value: int) -> String:
	match value:
		C_VictoryTriggerComponent.VictoryType.LEVEL_COMPLETE:
			return "LEVEL_COMPLETE"
		C_VictoryTriggerComponent.VictoryType.GAME_COMPLETE:
			return "GAME_COMPLETE"
		_:
			return "UNKNOWN(%s)" % str(value)

func on_configured() -> void:
	_subscribe_events()

func _subscribe_events() -> void:
	# Priority 10: Process state updates before scene manager transitions (priority 5)
	_event_unsubscribes.append(U_ECSEventBus.subscribe(
		U_ECSEventNames.EVENT_VICTORY_EXECUTION_REQUESTED,
		_on_victory_execution_requested,
		10
	))

func _on_victory_execution_requested(event: Dictionary) -> void:
	var payload: Dictionary = event.get("payload", {})
	var trigger := payload.get("trigger_node") as C_VictoryTriggerComponent
	_debug_log("received victory_execution_requested payload=%s" % str(payload))
	if trigger == null or not is_instance_valid(trigger):
		push_warning("S_VictoryHandlerSystem: victory_execution_requested missing required payload.trigger_node")
		_debug_log("dropping request: payload.trigger_node missing or invalid")
		return
	_debug_log(
		"trigger details objective_id=%s area_id=%s victory_type=%s trigger_once=%s is_triggered=%s"
		% [
			str(trigger.objective_id),
			trigger.area_id,
			_victory_type_to_string(int(trigger.victory_type)),
			str(trigger.trigger_once),
			str(trigger.is_triggered),
		]
	)
	if trigger.trigger_once and trigger.is_triggered:
		_debug_log("dropping request: trigger_once already consumed")
		return
	if not _ensure_dependencies_ready():
		_debug_log("dropping request: state store dependency missing")
		return
	_debug_gameplay_slice("before _can_trigger_victory")
	_debug_objectives_slice("before _can_trigger_victory")
	if not _can_trigger_victory(trigger):
		_debug_log("dropping request: _can_trigger_victory returned false")
		return
	_debug_log("victory request accepted; executing victory flow")
	_handle_victory(trigger, payload)

func _handle_victory(trigger: C_VictoryTriggerComponent, payload: Dictionary) -> void:
	_debug_gameplay_slice("before dispatching victory gameplay actions")
	if _store != null:
		if trigger.objective_id != StringName(""):
			_store.dispatch(U_GameplayActions.trigger_victory(
				trigger.objective_id,
				str(payload.get("entity_id", "")),
				payload.get("body", null)
			))
		if not trigger.area_id.is_empty():
			_store.dispatch(U_GameplayActions.mark_area_complete(trigger.area_id))
		if trigger.victory_type == C_VictoryTriggerComponent.VictoryType.GAME_COMPLETE:
			_store.dispatch(U_GameplayActions.game_complete())
	_debug_gameplay_slice("after dispatching victory gameplay actions")
	_debug_objectives_slice("after dispatching victory gameplay actions")
	_debug_log(
		"dispatched gameplay updates objective_id=%s area_id=%s victory_type=%s"
		% [
			str(trigger.objective_id),
			trigger.area_id,
			_victory_type_to_string(int(trigger.victory_type)),
		]
	)

	trigger.set_triggered()
	_debug_log("trigger marked consumed; publishing victory_executed")
	U_ECSEventBus.publish(U_ECSEventNames.EVENT_VICTORY_EXECUTED, {
		"entity_id": payload.get("entity_id", null),
		"trigger_node": trigger,
		"body": payload.get("body", null),
	})

func _can_trigger_victory(trigger: C_VictoryTriggerComponent) -> bool:
	if trigger == null:
		return false

	if trigger.victory_type == C_VictoryTriggerComponent.VictoryType.GAME_COMPLETE:
		if _store == null:
			_debug_log("GAME_COMPLETE gate failed: state store is null")
			return false
		var state: Dictionary = _store.get_state()
		var completed: Array = U_GameplaySelectors.get_completed_areas(state)
		if not completed.has(game_config.required_final_area):
			_debug_log(
				"GAME_COMPLETE gate failed: required_final_area=%s completed_areas=%s"
				% [game_config.required_final_area, str(completed)]
			)
			return false
		_debug_log(
			"GAME_COMPLETE gate passed: required_final_area=%s completed_areas=%s"
			% [game_config.required_final_area, str(completed)]
		)

	return true

func _ensure_dependencies_ready() -> bool:
	if _store == null:
		if state_store != null:
			_store = state_store
			_debug_log("resolved state store from injected dependency")
		else:
			_store = U_StateUtils.get_store(self)
			_debug_log("resolved state store via U_StateUtils.get_store: %s" % str(_store != null))
	return _store != null

func _exit_tree() -> void:
	for unsubscribe in _event_unsubscribes:
		if unsubscribe != null and unsubscribe is Callable and (unsubscribe as Callable).is_valid():
			(unsubscribe as Callable).call()
	_event_unsubscribes.clear()
