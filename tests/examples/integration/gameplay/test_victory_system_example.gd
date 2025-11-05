extends GutTest

## Integration tests for victory system gameplay mechanics (Phase 8.5)
##
## Validates that C_VictoryTriggerComponent + S_VictorySystem:
## - Detect player entering goal zone
## - Dispatch victory state actions (trigger_victory, mark_area_complete, game_complete)
## - Transition to correct scenes based on victory type

const M_SCENE_MANAGER := preload("res://scripts/managers/m_scene_manager.gd")
const M_ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/state/resources/rs_state_store_settings.gd")
const RS_GAMEPLAY_INITIAL_STATE := preload("res://scripts/state/resources/rs_gameplay_initial_state.gd")
const RS_SCENE_INITIAL_STATE := preload("res://scripts/state/resources/rs_scene_initial_state.gd")

const PLAYER_TAG_COMPONENT_PATH := "res://scripts/ecs/components/c_player_tag_component.gd"
const VICTORY_COMPONENT_PATH := "res://scripts/ecs/components/c_victory_trigger_component.gd"
const VICTORY_SYSTEM_PATH := "res://scripts/ecs/systems/s_victory_system.gd"

var _root: Node
var _state_store: M_StateStore
var _ecs_manager: M_ECSManager
var _scene_manager_stub: TestSceneManager


func before_each() -> void:
	_root = Node.new()
	add_child_autofree(_root)

	_state_store = M_STATE_STORE.new()
	_state_store.settings = RS_STATE_STORE_SETTINGS.new()
	_state_store.gameplay_initial_state = RS_GAMEPLAY_INITIAL_STATE.new()
	_state_store.scene_initial_state = RS_SCENE_INITIAL_STATE.new()
	_root.add_child(_state_store)

	_scene_manager_stub = TestSceneManager.new()
	_root.add_child(_scene_manager_stub)

	_ecs_manager = M_ECS_MANAGER.new()
	_root.add_child(_ecs_manager)

	await get_tree().process_frame

func after_each() -> void:
	_root = null
	_state_store = null
	_ecs_manager = null
	_scene_manager_stub = null

func _prepare_victory_fixture() -> Dictionary:
	var victory_component_script: Script = load(VICTORY_COMPONENT_PATH)
	if not assert_not_null(victory_component_script, "C_VictoryTriggerComponent script must exist"):
		return {}

	var victory_system_script: Script = load(VICTORY_SYSTEM_PATH)
	if not assert_not_null(victory_system_script, "S_VictorySystem script must exist"):
		return {}

	var player_tag_script: Script = load(PLAYER_TAG_COMPONENT_PATH)
	if not assert_not_null(player_tag_script, "C_PlayerTagComponent script must exist"):
		return {}

	var entities := Node3D.new()
	entities.name = "Entities"
	_root.add_child(entities)

	var player_entity := Node3D.new()
	player_entity.name = "E_PlayerTest"
	entities.add_child(player_entity)

	var player_body := CharacterBody3D.new()
	player_body.name = "Body"
	player_body.set_meta("entity_id", "E_Player")
	player_entity.add_child(player_body)

	var player_tag_component: Node = player_tag_script.new()
	player_entity.add_child(player_tag_component)

	var systems := Node.new()
	systems.name = "Systems"
	_root.add_child(systems)

	var core := Node.new()
	core.name = "Core"
	systems.add_child(core)

	var victory_system: Node = victory_system_script.new()
	victory_system.name = "S_VictorySystem"
	core.add_child(victory_system)

	var objectives := Node3D.new()
	objectives.name = "Objectives"
	_root.add_child(objectives)

	await wait_physics_frames(2)

	return {
		"player_entity": player_entity,
		"player_body": player_body,
		"victory_component_script": victory_component_script,
		"victory_system": victory_system,
		"objectives_root": objectives
	}

func _create_victory_trigger(script: Script, parent: Node, name: String, objective_id: StringName, victory_type: int, area_id: String) -> Node:
	var trigger_entity := Node3D.new()
	trigger_entity.name = name
	parent.add_child(trigger_entity)

	var trigger_component: Node = script.new()
	trigger_component.set("objective_id", objective_id)
	trigger_component.set("victory_type", victory_type)
	trigger_component.set("area_id", area_id)
	trigger_entity.add_child(trigger_component)
	return trigger_component

func _emit_goal_entry(trigger_component: Node, body: Node3D) -> void:
	if trigger_component == null:
		return
	if not trigger_component.has_method("get_trigger_area"):
		fail_test("C_VictoryTriggerComponent should expose get_trigger_area() for tests")
		return
	var area: Area3D = trigger_component.get_trigger_area()
	if area == null:
		fail_test("Victory trigger missing Area3D child")
		return
	area.emit_signal("body_entered", body)

func test_level_complete_triggers_hub_transition_and_marks_area() -> void:
	var fixture := await _prepare_victory_fixture()
	if fixture.is_empty():
		return

	var trigger_component: Node = _create_victory_trigger(
		fixture["victory_component_script"],
		fixture["objectives_root"],
		"E_GoalZone",
		StringName("goal_01"),
		0,  # VictoryType.LEVEL_COMPLETE
		"interior_house"
	)

	await wait_physics_frames(2)

	var transitions_before := _scene_manager_stub.transition_calls.size()
	_emit_goal_entry(trigger_component, fixture["player_body"])
	await wait_physics_frames(2)

	assert_eq(_scene_manager_stub.transition_calls.size(), transitions_before + 1, "Victory should enqueue scene transition")
	var call: Dictionary = _scene_manager_stub.transition_calls[-1]
	assert_eq(call.get("scene_id"), StringName("exterior"), "Level victory should return to exterior hub")
	assert_eq(call.get("transition_type"), "fade", "Victory transition should use fade")

	var gameplay_state: Dictionary = _state_store.get_state().get("gameplay", {})
	var completed_areas: Array = gameplay_state.get("completed_areas", [])
	assert_true(completed_areas.has("interior_house"), "Victory should mark area as completed")
	assert_eq(gameplay_state.get("last_victory_objective"), StringName("goal_01"), "State should track last victory objective")

func test_game_complete_triggers_victory_scene_and_flag() -> void:
	var fixture := await _prepare_victory_fixture()
	if fixture.is_empty():
		return

	var trigger_component: Node = _create_victory_trigger(
		fixture["victory_component_script"],
		fixture["objectives_root"],
		"E_FinalGoal",
		StringName("goal_final"),
		1,  # VictoryType.GAME_COMPLETE
		"final_dungeon"
	)

	await wait_physics_frames(2)

	var transitions_before := _scene_manager_stub.transition_calls.size()
	_emit_goal_entry(trigger_component, fixture["player_body"])
	await wait_physics_frames(2)

	assert_eq(_scene_manager_stub.transition_calls.size(), transitions_before + 1, "Game completion should transition scenes once")
	var call: Dictionary = _scene_manager_stub.transition_calls[-1]
	assert_eq(call.get("scene_id"), StringName("victory"), "Game complete should route to victory scene")

	var gameplay_state: Dictionary = _state_store.get_state().get("gameplay", {})
	assert_true(gameplay_state.get("game_completed", false), "State should record game completion flag")
	assert_eq(gameplay_state.get("last_victory_objective"), StringName("goal_final"), "Last victory objective should update on game completion")

class TestSceneManager:
	extends Node

	var transition_calls: Array = []
	var _is_transitioning: bool = false

	func _ready() -> void:
		add_to_group("scene_manager")

	func transition_to_scene(scene_id: StringName, transition_type: String, priority: int = M_SCENE_MANAGER.Priority.HIGH) -> void:
		transition_calls.append({
			"scene_id": scene_id,
			"transition_type": transition_type,
			"priority": priority
		})
		_is_transitioning = true

	func is_transitioning() -> bool:
		return _is_transitioning

	func reset_transition_state() -> void:
		_is_transitioning = false
