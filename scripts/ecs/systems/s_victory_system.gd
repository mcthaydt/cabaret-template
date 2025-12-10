@icon("res://resources/editor_icons/system.svg")
extends BaseECSSystem
class_name S_VictorySystem

const COMPONENT_TYPE := StringName("C_VictoryTriggerComponent")
const U_StateUtils := preload("res://scripts/state/utils/u_state_utils.gd")
const U_GameplayActions := preload("res://scripts/state/actions/u_gameplay_actions.gd")
const M_SceneManager := preload("res://scripts/managers/m_scene_manager.gd")
const U_ECSEventBus := preload("res://scripts/ecs/u_ecs_event_bus.gd")
const EVENT_VICTORY_TRIGGERED := StringName("victory_triggered")
const REQUIRED_FINAL_AREA := "interior_house"

var _store: M_StateStore = null
var _scene_manager: M_SceneManager = null
var _event_unsubscribes: Array[Callable] = []

func _init() -> void:
	execution_priority = 300

func process_tick(_delta: float) -> void:
	# Victory processing is event-driven via ECSEventBus.
	pass

func on_configured() -> void:
	_subscribe_events()

func _subscribe_events() -> void:
	_event_unsubscribes.append(U_ECSEventBus.subscribe(EVENT_VICTORY_TRIGGERED, _on_victory_triggered))

func _on_victory_triggered(event: Dictionary) -> void:
	var payload: Dictionary = event.get("payload", {})
	var trigger := payload.get("trigger_node") as C_VictoryTriggerComponent
	if trigger == null or not is_instance_valid(trigger):
		return
	if trigger.trigger_once and trigger.is_triggered:
		return
	if not _ensure_dependencies_ready():
		return
	if not _can_trigger_victory(trigger):
		return
	_handle_victory(trigger)

func _handle_victory(trigger: C_VictoryTriggerComponent) -> void:
	if _store != null:
		if trigger.objective_id != StringName(""):
			_store.dispatch(U_GameplayActions.trigger_victory(trigger.objective_id))
		if not trigger.area_id.is_empty():
			_store.dispatch(U_GameplayActions.mark_area_complete(trigger.area_id))
		if trigger.victory_type == C_VictoryTriggerComponent.VictoryType.GAME_COMPLETE:
			_store.dispatch(U_GameplayActions.game_complete())

	var target_scene := _get_target_scene(trigger)

	if _scene_manager != null and is_instance_valid(_scene_manager):
		_scene_manager.transition_to_scene(target_scene, "fade", M_SceneManager.Priority.HIGH)

	trigger.set_triggered()

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
			if not completed.has(REQUIRED_FINAL_AREA):
				return false
		else:
			return false

	return true

func _get_target_scene(trigger: C_VictoryTriggerComponent) -> StringName:
	match trigger.victory_type:
		C_VictoryTriggerComponent.VictoryType.GAME_COMPLETE:
			return StringName("victory")
		_:
			return StringName("exterior")

func _ensure_dependencies_ready() -> bool:
	if _store == null:
		_store = U_StateUtils.get_store(self)
	if _scene_manager == null:
		var managers := get_tree().get_nodes_in_group("scene_manager")
		if managers.size() > 0:
			_scene_manager = managers[0] as M_SceneManager
	return _store != null

func _exit_tree() -> void:
	for unsubscribe in _event_unsubscribes:
		if unsubscribe != null and unsubscribe is Callable and (unsubscribe as Callable).is_valid():
			(unsubscribe as Callable).call()
	_event_unsubscribes.clear()
