@icon("res://resources/editor_icons/system.svg")
extends BaseECSSystem
class_name S_VictorySystem

const COMPONENT_TYPE := StringName("C_VictoryTriggerComponent")
const U_StateUtils := preload("res://scripts/state/utils/u_state_utils.gd")
const U_GameplayActions := preload("res://scripts/state/actions/u_gameplay_actions.gd")
const M_SceneManager := preload("res://scripts/managers/m_scene_manager.gd")

var _store: M_StateStore = null
var _scene_manager: M_SceneManager = null

func _init() -> void:
	execution_priority = 300

func process_tick(_delta: float) -> void:
	if not _ensure_dependencies_ready():
		return

	var components: Array = get_components(COMPONENT_TYPE)
	for entry in components:
		var trigger: C_VictoryTriggerComponent = entry as C_VictoryTriggerComponent
		if trigger == null or not is_instance_valid(trigger):
			continue

		if trigger.consume_trigger_request():
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
