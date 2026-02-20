@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_VictoryHandlerSystem

## Injected state store (for testing)
## If set, system uses this instead of U_StateUtils.get_store()
@export var state_store: I_StateStore = null
@export var required_final_area: String = "bar"

var _store: I_StateStore = null
var _event_unsubscribes: Array[Callable] = []

func _init() -> void:
	execution_priority = 300

func process_tick(__delta: float) -> void:
	# Victory processing is event-driven via ECSEventBus.
	pass

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
	if trigger == null or not is_instance_valid(trigger):
		push_warning("S_VictoryHandlerSystem: victory_execution_requested missing required payload.trigger_node")
		return
	if trigger.trigger_once and trigger.is_triggered:
		return
	if not _ensure_dependencies_ready():
		return
	if not _can_trigger_victory(trigger):
		return
	_handle_victory(trigger, payload)

func _handle_victory(trigger: C_VictoryTriggerComponent, payload: Dictionary) -> void:
	if _store != null:
		if trigger.objective_id != StringName(""):
			_store.dispatch(U_GameplayActions.trigger_victory(trigger.objective_id))
		if not trigger.area_id.is_empty():
			_store.dispatch(U_GameplayActions.mark_area_complete(trigger.area_id))
		if trigger.victory_type == C_VictoryTriggerComponent.VictoryType.GAME_COMPLETE:
			_store.dispatch(U_GameplayActions.game_complete())

	trigger.set_triggered()
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
			return false
		var state: Dictionary = _store.get_state()
		var gameplay: Dictionary = state.get("gameplay", {})
		var completed_variant: Variant = gameplay.get("completed_areas", [])
		if completed_variant is Array:
			var completed: Array = completed_variant
			if not completed.has(required_final_area):
				return false
		else:
			return false

	return true

func _ensure_dependencies_ready() -> bool:
	if _store == null:
		if state_store != null:
			_store = state_store
		else:
			_store = U_StateUtils.get_store(self)
	return _store != null

func _exit_tree() -> void:
	for unsubscribe in _event_unsubscribes:
		if unsubscribe != null and unsubscribe is Callable and (unsubscribe as Callable).is_valid():
			(unsubscribe as Callable).call()
	_event_unsubscribes.clear()
