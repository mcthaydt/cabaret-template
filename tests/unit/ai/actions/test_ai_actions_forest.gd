extends BaseTest

const ACTION_MOVE_TO_DETECTED_PATH := "res://scripts/resources/ai/actions/rs_ai_action_move_to_detected.gd"
const ACTION_FLEE_FROM_DETECTED_PATH := "res://scripts/resources/ai/actions/rs_ai_action_flee_from_detected.gd"
const ACTION_WANDER_PATH := "res://scripts/resources/ai/actions/rs_ai_action_wander.gd"
const U_AI_TASK_STATE_KEYS_PATH := "res://scripts/utils/ai/u_ai_task_state_keys.gd"

const U_AI_TASK_STATE_KEYS := preload("res://scripts/utils/ai/u_ai_task_state_keys.gd")
const BASE_ECS_ENTITY := preload("res://scripts/ecs/base_ecs_entity.gd")
const C_DETECTION_COMPONENT := preload("res://scripts/ecs/components/c_detection_component.gd")
const C_MOVE_TARGET_COMPONENT := preload("res://scripts/ecs/components/c_move_target_component.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")

func _load_required_script(path: String) -> Script:
	var script_variant: Variant = load(path)
	assert_not_null(script_variant, "Expected script to exist: %s" % path)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func _assert_vector3_almost_eq(actual: Vector3, expected: Vector3, epsilon: float = 0.0001) -> void:
	assert_almost_eq(actual.x, expected.x, epsilon)
	assert_almost_eq(actual.y, expected.y, epsilon)
	assert_almost_eq(actual.z, expected.z, epsilon)

func _get_task_state_key_constants() -> Dictionary:
	var script_variant: Variant = load(U_AI_TASK_STATE_KEYS_PATH)
	assert_not_null(script_variant, "Expected script to exist: %s" % U_AI_TASK_STATE_KEYS_PATH)
	if not (script_variant is Script):
		return {}
	return (script_variant as Script).get_script_constant_map()

func _create_entity(parent: Node3D, name: String, position: Vector3) -> BaseECSEntity:
	var entity: BaseECSEntity = BASE_ECS_ENTITY.new()
	entity.name = name
	parent.add_child(entity)
	autofree(entity)
	entity.global_position = position
	return entity

func _create_context(
	entity: BaseECSEntity,
	detection: C_DetectionComponent,
	move_target: C_MoveTargetComponent,
	ecs_manager: MockECSManager
) -> Dictionary:
	return {
		"entity": entity,
		"components": {
			C_DETECTION_COMPONENT.COMPONENT_TYPE: detection,
			C_MOVE_TARGET_COMPONENT.COMPONENT_TYPE: move_target,
		},
		"ecs_manager": ecs_manager,
	}

func _register_detected_target(
	ecs_manager: MockECSManager,
	detection: C_DetectionComponent,
	target: BaseECSEntity
) -> void:
	var target_id: StringName = target.get_entity_id()
	ecs_manager.register_entity_id(target_id, target)
	detection.last_detected_player_entity_id = target_id

func test_move_to_detected_sets_move_target_and_task_state_from_detected_entity() -> void:
	var action_script: Script = _load_required_script(ACTION_MOVE_TO_DETECTED_PATH)
	if action_script == null:
		return

	var root := Node3D.new()
	add_child_autofree(root)
	var ecs_manager: MockECSManager = MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)

	var actor: BaseECSEntity = _create_entity(root, "E_Wolf", Vector3(2.0, 0.0, 1.0))
	var target: BaseECSEntity = _create_entity(root, "E_Rabbit", Vector3(7.0, 0.0, -3.0))
	var detection: C_DetectionComponent = C_DETECTION_COMPONENT.new()
	actor.add_child(detection)
	autofree(detection)
	var move_target: C_MoveTargetComponent = C_MOVE_TARGET_COMPONENT.new()
	actor.add_child(move_target)
	autofree(move_target)

	_register_detected_target(ecs_manager, detection, target)
	var context: Dictionary = _create_context(actor, detection, move_target, ecs_manager)
	var task_state: Dictionary = {}
	var action: Resource = action_script.new()

	action.start(context, task_state)

	assert_true(move_target.is_active, "Move-target component should be activated.")
	_assert_vector3_almost_eq(move_target.target_position, target.global_position)
	assert_true(task_state.has(U_AI_TASK_STATE_KEYS.MOVE_TARGET))
	var task_target_variant: Variant = task_state.get(U_AI_TASK_STATE_KEYS.MOVE_TARGET, null)
	assert_true(task_target_variant is Vector3)
	if task_target_variant is Vector3:
		_assert_vector3_almost_eq(task_target_variant as Vector3, target.global_position)

func test_move_to_detected_tick_repaths_to_live_detected_target_position() -> void:
	var action_script: Script = _load_required_script(ACTION_MOVE_TO_DETECTED_PATH)
	if action_script == null:
		return

	var root := Node3D.new()
	add_child_autofree(root)
	var ecs_manager: MockECSManager = MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)

	var actor: BaseECSEntity = _create_entity(root, "E_Wolf", Vector3.ZERO)
	var target: BaseECSEntity = _create_entity(root, "E_Rabbit", Vector3(5.0, 0.0, 0.0))
	var detection: C_DetectionComponent = C_DETECTION_COMPONENT.new()
	actor.add_child(detection)
	autofree(detection)
	var move_target: C_MoveTargetComponent = C_MOVE_TARGET_COMPONENT.new()
	actor.add_child(move_target)
	autofree(move_target)

	_register_detected_target(ecs_manager, detection, target)
	var context: Dictionary = _create_context(actor, detection, move_target, ecs_manager)
	var task_state: Dictionary = {}
	var action: Resource = action_script.new()

	action.start(context, task_state)
	var initial_target: Vector3 = move_target.target_position
	target.global_position = Vector3(7.0, 0.0, 2.0)
	action.tick(context, task_state, 0.016)

	assert_true(move_target.is_active, "Move-target component should stay active during chase repath.")
	assert_true(
		move_target.target_position != initial_target,
		"Tick should refresh move target when detected entity moves."
	)
	_assert_vector3_almost_eq(move_target.target_position, target.global_position)
	var task_target_variant: Variant = task_state.get(U_AI_TASK_STATE_KEYS.MOVE_TARGET, null)
	assert_true(task_target_variant is Vector3)
	if task_target_variant is Vector3:
		_assert_vector3_almost_eq(task_target_variant as Vector3, target.global_position)

func test_move_to_detected_stale_detection_pushes_error_and_completes() -> void:
	var action_script: Script = _load_required_script(ACTION_MOVE_TO_DETECTED_PATH)
	if action_script == null:
		return

	var root := Node3D.new()
	add_child_autofree(root)
	var ecs_manager: MockECSManager = MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)

	var actor: BaseECSEntity = _create_entity(root, "E_Wolf", Vector3.ZERO)
	var detection: C_DetectionComponent = C_DETECTION_COMPONENT.new()
	actor.add_child(detection)
	autofree(detection)
	var move_target: C_MoveTargetComponent = C_MOVE_TARGET_COMPONENT.new()
	actor.add_child(move_target)
	autofree(move_target)

	var context: Dictionary = _create_context(actor, detection, move_target, ecs_manager)
	var task_state: Dictionary = {}
	var action: Resource = action_script.new()

	action.start(context, task_state)

	assert_push_error("RS_AIActionMoveToDetected: stale detection")
	assert_true(action.is_complete(context, task_state), "Stale detection should complete immediately.")
	assert_false(move_target.is_active, "Stale detection should not activate move-target component.")

func test_flee_from_detected_sets_flee_target_away_from_detected_entity() -> void:
	var action_script: Script = _load_required_script(ACTION_FLEE_FROM_DETECTED_PATH)
	if action_script == null:
		return

	var root := Node3D.new()
	add_child_autofree(root)
	var ecs_manager: MockECSManager = MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)

	var actor: BaseECSEntity = _create_entity(root, "E_Rabbit", Vector3(4.0, 0.0, 6.0))
	var target: BaseECSEntity = _create_entity(root, "E_Wolf", Vector3(1.0, 0.0, 2.0))
	var detection: C_DetectionComponent = C_DETECTION_COMPONENT.new()
	actor.add_child(detection)
	autofree(detection)
	var move_target: C_MoveTargetComponent = C_MOVE_TARGET_COMPONENT.new()
	actor.add_child(move_target)
	autofree(move_target)

	_register_detected_target(ecs_manager, detection, target)
	var context: Dictionary = _create_context(actor, detection, move_target, ecs_manager)
	var task_state: Dictionary = {}
	var action: Resource = action_script.new()
	action.set("flee_distance", 5.0)

	action.start(context, task_state)

	var expected: Vector3 = actor.global_position + (actor.global_position - target.global_position).normalized() * 5.0
	assert_true(move_target.is_active)
	_assert_vector3_almost_eq(move_target.target_position, expected)
	assert_true(task_state.has(U_AI_TASK_STATE_KEYS.MOVE_TARGET))

func test_flee_from_detected_stale_detection_pushes_error_and_completes() -> void:
	var action_script: Script = _load_required_script(ACTION_FLEE_FROM_DETECTED_PATH)
	if action_script == null:
		return

	var root := Node3D.new()
	add_child_autofree(root)
	var ecs_manager: MockECSManager = MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)

	var actor: BaseECSEntity = _create_entity(root, "E_Rabbit", Vector3.ZERO)
	var detection: C_DetectionComponent = C_DETECTION_COMPONENT.new()
	actor.add_child(detection)
	autofree(detection)
	var move_target: C_MoveTargetComponent = C_MOVE_TARGET_COMPONENT.new()
	actor.add_child(move_target)
	autofree(move_target)

	var context: Dictionary = _create_context(actor, detection, move_target, ecs_manager)
	var task_state: Dictionary = {}
	var action: Resource = action_script.new()

	action.start(context, task_state)

	assert_push_error("RS_AIActionFleeFromDetected.start")
	assert_true(action.is_complete(context, task_state))
	assert_false(move_target.is_active)

func test_wander_home_key_constant_exists() -> void:
	var constants: Dictionary = _get_task_state_key_constants()
	assert_true(constants.has("WANDER_HOME"), "U_AITaskStateKeys should define WANDER_HOME.")
	if not constants.has("WANDER_HOME"):
		return
	assert_eq(constants.get("WANDER_HOME", StringName("")), StringName("ai_wander_home"))

func test_wander_captures_home_once_and_targets_within_home_radius() -> void:
	var action_script: Script = _load_required_script(ACTION_WANDER_PATH)
	if action_script == null:
		return

	var constants: Dictionary = _get_task_state_key_constants()
	assert_true(constants.has("WANDER_HOME"), "WANDER_HOME key must exist before wander action can run.")
	if not constants.has("WANDER_HOME"):
		return
	var wander_home_key: StringName = constants.get("WANDER_HOME", StringName("")) as StringName

	var root := Node3D.new()
	add_child_autofree(root)
	var actor: BaseECSEntity = _create_entity(root, "E_Deer", Vector3(10.0, 0.0, -4.0))
	var move_target: C_MoveTargetComponent = C_MOVE_TARGET_COMPONENT.new()
	actor.add_child(move_target)
	autofree(move_target)

	var context: Dictionary = {
		"entity": actor,
		"components": {
			C_MOVE_TARGET_COMPONENT.COMPONENT_TYPE: move_target,
		},
	}
	var task_state: Dictionary = {}
	var action: Resource = action_script.new()
	action.set("home_radius", 6.0)

	action.start(context, task_state)

	assert_true(task_state.has(wander_home_key), "Wander start should capture the home position once.")
	var home_variant: Variant = task_state.get(wander_home_key, null)
	assert_true(home_variant is Vector3)
	if not (home_variant is Vector3):
		return
	var home_position: Vector3 = home_variant as Vector3
	_assert_vector3_almost_eq(home_position, Vector3(10.0, 0.0, -4.0))

	var move_target_variant: Variant = task_state.get(U_AI_TASK_STATE_KEYS.MOVE_TARGET, null)
	assert_true(move_target_variant is Vector3)
	if move_target_variant is Vector3:
		var move_target_value: Vector3 = move_target_variant as Vector3
		var offset_xz: Vector2 = Vector2(move_target_value.x - home_position.x, move_target_value.z - home_position.z)
		assert_true(offset_xz.length() <= 6.0001, "Wander target should remain inside home_radius.")

	actor.global_position = Vector3(-100.0, 0.0, -100.0)
	action.start(context, task_state)
	var preserved_home_variant: Variant = task_state.get(wander_home_key, null)
	assert_true(preserved_home_variant is Vector3)
	if preserved_home_variant is Vector3:
		_assert_vector3_almost_eq(preserved_home_variant as Vector3, home_position)
