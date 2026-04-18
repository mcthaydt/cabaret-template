extends BaseTest

const S_AI_BEHAVIOR_SYSTEM_PATH := "res://scripts/ecs/systems/s_ai_behavior_system.gd"
const BASE_ECS_SYSTEM := preload("res://scripts/ecs/base_ecs_system.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const C_AI_BRAIN_COMPONENT := preload("res://scripts/ecs/components/c_ai_brain_component.gd")
const RS_AI_BRAIN_SETTINGS := preload("res://scripts/resources/ai/brain/rs_ai_brain_settings.gd")
const RS_AI_GOAL := preload("res://scripts/resources/ai/goals/rs_ai_goal.gd")
const RS_AI_PRIMITIVE_TASK := preload("res://scripts/resources/ai/tasks/rs_ai_primitive_task.gd")
const RS_BT_NODE := preload("res://scripts/resources/bt/rs_bt_node.gd")

class BehaviorSystemBtRecordingNode extends RS_BT_NODE:
	var tick_calls: int = 0
	var last_context: Dictionary = {}

	func tick(context: Dictionary, state_bag: Dictionary) -> Status:
		tick_calls += 1
		last_context = context.duplicate(true)
		state_bag[&"runner_tick_calls"] = tick_calls
		return Status.SUCCESS

class BehaviorSystemBtBrainSettingsShim extends RS_AI_BRAIN_SETTINGS:
	var goals: Array[RS_AIGoal] = []

class BehaviorSystemBtBrainShim extends C_AI_BRAIN_COMPONENT:
	var current_task_queue: Array[RS_AIPrimitiveTask] = []
	var current_task_index: int = 0
	var task_state: Dictionary = {}
	var suspended_goal_state: Dictionary = {}
	var debug_snapshot_updates: int = 0

	func update_debug_snapshot(snapshot: Dictionary) -> void:
		debug_snapshot_updates += 1
		super.update_debug_snapshot(snapshot)

func _load_script(path: String) -> Script:
	var script_variant: Variant = load(path)
	assert_not_null(script_variant, "Expected script to exist: %s" % path)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func _create_fixture(evaluation_interval: float = 0.0) -> Dictionary:
	var system_script: Script = _load_script(S_AI_BEHAVIOR_SYSTEM_PATH)
	if system_script == null:
		return {}

	var store: MockStateStore = MOCK_STATE_STORE.new()
	autofree(store)
	var ecs_manager: MockECSManager = MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)

	var system_variant: Variant = system_script.new()
	assert_true(system_variant is BaseECSSystem, "S_AIBehaviorSystem should extend BaseECSSystem")
	if not (system_variant is BaseECSSystem):
		return {}
	var system: BaseECSSystem = system_variant as BaseECSSystem
	autofree(system)
	system.state_store = store
	system.ecs_manager = ecs_manager
	system.configure(ecs_manager)

	var root_node: BehaviorSystemBtRecordingNode = BehaviorSystemBtRecordingNode.new()
	var brain_settings: BehaviorSystemBtBrainSettingsShim = BehaviorSystemBtBrainSettingsShim.new()
	brain_settings.root = root_node
	brain_settings.evaluation_interval = evaluation_interval

	var entity: Node3D = Node3D.new()
	entity.name = "E_TestNPC"
	add_child(entity)
	autofree(entity)

	var brain: BehaviorSystemBtBrainShim = BehaviorSystemBtBrainShim.new()
	brain.brain_settings = brain_settings
	entity.add_child(brain)
	autofree(brain)
	ecs_manager.add_component_to_entity(entity, brain)

	return {
		"system": system,
		"brain": brain,
		"root": root_node,
		"store": store,
	}

func test_bt_runner_tick_receives_context_and_state_bag() -> void:
	var fixture: Dictionary = _create_fixture(0.0)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture["system"] as BaseECSSystem
	var brain: BehaviorSystemBtBrainShim = fixture["brain"] as BehaviorSystemBtBrainShim
	var root_node: BehaviorSystemBtRecordingNode = fixture["root"] as BehaviorSystemBtRecordingNode
	system.process_tick(0.016)

	assert_eq(root_node.tick_calls, 1, "BT root should be ticked once per eligible system tick.")
	assert_true(root_node.last_context.has(&"state_store"), "BT context should include state_store.")
	assert_true(root_node.last_context.has(&"redux_state"), "BT context should include redux_state.")
	assert_true(root_node.last_context.has(&"components"), "BT context should include components.")
	assert_true(root_node.last_context.has(&"brain_component"), "BT context should include brain_component.")
	assert_eq(brain.bt_state_bag.get(&"runner_tick_calls", -1), 1, "BT runner should mutate the shared bt_state_bag.")

func test_bt_tick_honors_evaluation_interval() -> void:
	var fixture: Dictionary = _create_fixture(0.5)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture["system"] as BaseECSSystem
	var brain: BehaviorSystemBtBrainShim = fixture["brain"] as BehaviorSystemBtBrainShim
	var root_node: BehaviorSystemBtRecordingNode = fixture["root"] as BehaviorSystemBtRecordingNode
	brain.active_goal_id = &"running"

	system.process_tick(0.2)
	system.process_tick(0.2)
	assert_eq(root_node.tick_calls, 0, "BT runner should not tick before evaluation interval elapses.")
	system.process_tick(0.2)
	assert_eq(root_node.tick_calls, 1, "BT runner should tick once the evaluation interval is reached.")

func test_debug_snapshot_updates_each_tick_for_bt_brains() -> void:
	var fixture: Dictionary = _create_fixture(0.0)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture["system"] as BaseECSSystem
	var brain: BehaviorSystemBtBrainShim = fixture["brain"] as BehaviorSystemBtBrainShim
	system.process_tick(0.016)
	system.process_tick(0.016)
	assert_eq(brain.debug_snapshot_updates, 2, "BT brains should refresh debug snapshot every system tick.")
