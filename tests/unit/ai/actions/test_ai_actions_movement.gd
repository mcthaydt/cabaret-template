extends BaseTest

const ACTION_MOVE_TO_PATH := "res://scripts/resources/ai/actions/rs_ai_action_move_to.gd"
const ACTION_MOVE_TO_DETECTED_PATH := "res://scripts/resources/ai/actions/rs_ai_action_move_to_detected.gd"
const ACTION_FLEE_FROM_DETECTED_PATH := "res://scripts/resources/ai/actions/rs_ai_action_flee_from_detected.gd"
const ACTION_WANDER_PATH := "res://scripts/resources/ai/actions/rs_ai_action_wander.gd"
const ACTION_SCAN_PATH := "res://scripts/resources/ai/actions/rs_ai_action_scan.gd"
const ACTION_ANIMATE_PATH := "res://scripts/resources/ai/actions/rs_ai_action_animate.gd"
const C_MOVE_TARGET_COMPONENT := preload("res://scripts/demo/ecs/components/c_move_target_component.gd")
const C_MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")
const C_DETECTION_COMPONENT := preload("res://scripts/demo/ecs/components/c_detection_component.gd")
const RS_MOVEMENT_SETTINGS := preload("res://scripts/resources/ecs/rs_movement_settings.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const U_AI_TASK_STATE_KEYS := preload("res://scripts/utils/ai/u_ai_task_state_keys.gd")

func _load_script(path: String) -> Script:
	var script_variant: Variant = load(path)
	assert_not_null(script_variant, "Expected script to exist: %s" % path)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func _assert_vector3_almost_eq(actual: Vector3, expected: Vector3, epsilon: float = 0.0001) -> void:
	assert_almost_eq(actual.x, expected.x, epsilon)
	assert_almost_eq(actual.y, expected.y, epsilon)
	assert_almost_eq(actual.z, expected.z, epsilon)

func _new_move_target_component() -> Variant:
	return C_MOVE_TARGET_COMPONENT.new()

func _add_movement_stack(entity: Node3D, body_position: Vector3) -> Dictionary:
	var body := CharacterBody3D.new()
	body.name = "Player_Body"
	entity.add_child(body)
	body.global_position = body_position
	var components := Node.new()
	components.name = "Components"
	entity.add_child(components)
	var movement: C_MovementComponent = C_MOVEMENT_COMPONENT.new()
	movement.name = "C_MovementComponent"
	movement.settings = RS_MOVEMENT_SETTINGS.new()
	components.add_child(movement)
	autofree(movement)
	return {"body": body, "movement": movement}

func test_move_to_action_sets_target_in_task_state() -> void:
	var action_script: Script = _load_script(ACTION_MOVE_TO_PATH)
	if action_script == null:
		return

	var action: Resource = action_script.new()
	action.set("target_position", Vector3(3.0, 0.0, 2.0))

	var context: Dictionary = {}
	var task_state: Dictionary = {}
	action.start(context, task_state)

	assert_true(task_state.has("ai_move_target"))
	var target_variant: Variant = task_state.get("ai_move_target", Vector3.ZERO)
	assert_true(target_variant is Vector3)
	if target_variant is Vector3:
		_assert_vector3_almost_eq(target_variant as Vector3, Vector3(3.0, 0.0, 2.0))

func test_move_to_action_routes_to_move_target_component_when_present() -> void:
	var action_script: Script = _load_script(ACTION_MOVE_TO_PATH)
	if action_script == null:
		return

	var action: Resource = action_script.new()
	action.set("target_position", Vector3(3.0, 0.0, 2.0))
	action.set("arrival_threshold", 0.27)
	var move_target_component: Variant = _new_move_target_component()
	autofree(move_target_component)

	var context: Dictionary = {
		"components": {
			C_MOVE_TARGET_COMPONENT.COMPONENT_TYPE: move_target_component,
		},
	}
	var task_state: Dictionary = {}
	action.start(context, task_state)

	var is_active_variant: Variant = move_target_component.get("is_active")
	assert_true(is_active_variant is bool and bool(is_active_variant))
	var target_position_variant: Variant = move_target_component.get("target_position")
	assert_true(target_position_variant is Vector3)
	if target_position_variant is Vector3:
		_assert_vector3_almost_eq(target_position_variant as Vector3, Vector3(3.0, 0.0, 2.0))
	var arrival_threshold_variant: Variant = move_target_component.get("arrival_threshold")
	assert_true(arrival_threshold_variant is float or arrival_threshold_variant is int)
	assert_almost_eq(float(arrival_threshold_variant), 0.27, 0.0001)

func test_move_to_start_writes_arrival_threshold_to_task_state() -> void:
	var action_script: Script = _load_script(ACTION_MOVE_TO_PATH)
	if action_script == null:
		return

	var action: Resource = action_script.new()
	action.set("target_position", Vector3(2.0, 0.0, 1.0))
	action.set("arrival_threshold", 0.27)

	var context: Dictionary = {}
	var task_state: Dictionary = {}
	action.start(context, task_state)

	assert_true(task_state.has("ai_arrival_threshold"))
	assert_almost_eq(float(task_state.get("ai_arrival_threshold", -1.0)), 0.27, 0.0001)

func test_move_to_action_completes_when_within_threshold() -> void:
	var action_script: Script = _load_script(ACTION_MOVE_TO_PATH)
	if action_script == null:
		return

	var action: Resource = action_script.new()
	action.set("target_position", Vector3(1.0, 0.0, 1.0))
	action.set("arrival_threshold", 0.5)

	var context: Dictionary = {
		"entity_position": Vector3(1.2, 5.0, 1.1),
	}
	var task_state: Dictionary = {}
	action.start(context, task_state)

	assert_true(action.is_complete(context, task_state))

func test_move_to_action_completion_deactivates_move_target_component() -> void:
	var action_script: Script = _load_script(ACTION_MOVE_TO_PATH)
	if action_script == null:
		return

	var action: Resource = action_script.new()
	action.set("target_position", Vector3(1.0, 0.0, 1.0))
	action.set("arrival_threshold", 0.5)
	var move_target_component: Variant = _new_move_target_component()
	autofree(move_target_component)

	var context: Dictionary = {
		"entity_position": Vector3(1.2, 5.0, 1.1),
		"components": {
			C_MOVE_TARGET_COMPONENT.COMPONENT_TYPE: move_target_component,
		},
	}
	var task_state: Dictionary = {}
	action.start(context, task_state)
	var is_active_variant: Variant = move_target_component.get("is_active")
	assert_true(is_active_variant is bool and bool(is_active_variant))

	assert_true(action.is_complete(context, task_state))
	var inactive_variant: Variant = move_target_component.get("is_active")
	assert_true(inactive_variant is bool and not bool(inactive_variant))

func test_move_to_action_stays_active_when_far() -> void:
	var action_script: Script = _load_script(ACTION_MOVE_TO_PATH)
	if action_script == null:
		return

	var action: Resource = action_script.new()
	action.set("target_position", Vector3(8.0, 0.0, 0.0))
	action.set("arrival_threshold", 0.5)

	var context: Dictionary = {
		"entity_position": Vector3.ZERO,
	}
	var task_state: Dictionary = {}
	action.start(context, task_state)

	assert_false(action.is_complete(context, task_state))

func test_move_to_action_resolves_waypoint_index() -> void:
	var action_script: Script = _load_script(ACTION_MOVE_TO_PATH)
	if action_script == null:
		return

	var action: Resource = action_script.new()
	action.set("target_position", Vector3(99.0, 0.0, 99.0))
	action.set("waypoint_index", 1)

	var context: Dictionary = {
		"waypoints": [
			Vector3(1.0, 0.0, 0.0),
			Vector3(7.0, 0.0, -2.0),
		],
	}
	var task_state: Dictionary = {}
	action.start(context, task_state)

	var target_variant: Variant = task_state.get("ai_move_target", Vector3.ZERO)
	assert_true(target_variant is Vector3)
	if target_variant is Vector3:
		_assert_vector3_almost_eq(target_variant as Vector3, Vector3(7.0, 0.0, -2.0))

func test_move_to_action_resolves_target_node_path_from_entity_context() -> void:
	var action_script: Script = _load_script(ACTION_MOVE_TO_PATH)
	if action_script == null:
		return

	var action: Resource = action_script.new()
	action.set("target_position", Vector3(99.0, 0.0, 99.0))
	action.set("target_node_path", NodePath("TargetMarker"))

	var root := Node3D.new()
	add_child_autofree(root)
	var entity := Node3D.new()
	entity.name = "E_TestAgent"
	root.add_child(entity)
	var target := Node3D.new()
	target.name = "TargetMarker"
	entity.add_child(target)
	target.global_position = Vector3(12.0, 2.0, -4.0)

	var context: Dictionary = {
		"entity": entity,
	}
	var task_state: Dictionary = {}
	action.start(context, task_state)

	var target_variant: Variant = task_state.get("ai_move_target", Vector3.ZERO)
	assert_true(target_variant is Vector3)
	if target_variant is Vector3:
		_assert_vector3_almost_eq(target_variant as Vector3, Vector3(12.0, 2.0, -4.0))

func test_move_to_action_target_node_path_falls_back_to_owner_node() -> void:
	var action_script: Script = _load_script(ACTION_MOVE_TO_PATH)
	if action_script == null:
		return

	var action: Resource = action_script.new()
	action.set("target_position", Vector3(99.0, 0.0, 99.0))
	action.set("target_node_path", NodePath("TargetMarker"))

	var root := Node3D.new()
	add_child_autofree(root)
	var owner_node := Node3D.new()
	owner_node.name = "OwnerNode"
	root.add_child(owner_node)
	var target := Node3D.new()
	target.name = "TargetMarker"
	owner_node.add_child(target)
	target.global_position = Vector3(-3.0, 1.5, 8.0)

	var context: Dictionary = {
		"owner_node": owner_node,
	}
	var task_state: Dictionary = {}
	action.start(context, task_state)

	var target_variant: Variant = task_state.get("ai_move_target", Vector3.ZERO)
	assert_true(target_variant is Vector3)
	if target_variant is Vector3:
		_assert_vector3_almost_eq(target_variant as Vector3, Vector3(-3.0, 1.5, 8.0))

func test_move_to_action_target_node_path_falls_back_to_direct_target_node() -> void:
	var action_script: Script = _load_script(ACTION_MOVE_TO_PATH)
	if action_script == null:
		return

	var action: Resource = action_script.new()
	action.set("target_position", Vector3(99.0, 0.0, 99.0))
	action.set("target_node_path", NodePath("MissingNode"))

	var root := Node3D.new()
	add_child_autofree(root)
	var direct_target := Node3D.new()
	direct_target.name = "DirectTarget"
	root.add_child(direct_target)
	direct_target.global_position = Vector3(5.0, 0.25, -6.0)

	var context: Dictionary = {
		"target_node": direct_target,
	}
	var task_state: Dictionary = {}
	action.start(context, task_state)

	var target_variant: Variant = task_state.get("ai_move_target", Vector3.ZERO)
	assert_true(target_variant is Vector3)
	if target_variant is Vector3:
		_assert_vector3_almost_eq(target_variant as Vector3, Vector3(5.0, 0.25, -6.0))

func test_wander_completion_uses_character_body_position() -> void:
	var action_script: Script = _load_script(ACTION_WANDER_PATH)
	if action_script == null:
		return
	var action: Resource = action_script.new()
	action.set("arrival_threshold", 0.5)
	var actor := Node3D.new()
	actor.name = "E_Rabbit"
	add_child_autofree(actor)
	actor.global_position = Vector3.ZERO
	var stack: Dictionary = _add_movement_stack(actor, Vector3(4.0, 0.0, 0.0))
	var move_target_component: Variant = _new_move_target_component()
	autofree(move_target_component)
	var context: Dictionary = {
		"entity": actor,
		"components": {
			C_MOVEMENT_COMPONENT.COMPONENT_TYPE: stack.get("movement"),
			C_MOVE_TARGET_COMPONENT.COMPONENT_TYPE: move_target_component,
		},
	}
	var task_state: Dictionary = {
		U_AITaskStateKeys.MOVE_TARGET: Vector3(4.2, 0.0, 0.0),
		U_AITaskStateKeys.ARRIVAL_THRESHOLD: 0.5,
		U_AITaskStateKeys.COMPLETED: false,
	}
	assert_true(action.is_complete(context, task_state), "Wander should complete from body position, not stale entity root.")

func test_wander_preserves_entity_home_anchor_across_reentries() -> void:
	var action_script: Script = _load_script(ACTION_WANDER_PATH)
	if action_script == null:
		return
	var action: Resource = action_script.new()
	action.set("home_radius", 3.0)
	var actor := Node3D.new()
	actor.name = "E_Rabbit"
	add_child_autofree(actor)
	actor.global_position = Vector3.ZERO
	var stack: Dictionary = _add_movement_stack(actor, Vector3.ZERO)
	var body: CharacterBody3D = stack.get("body") as CharacterBody3D
	var move_target_component: Variant = _new_move_target_component()
	autofree(move_target_component)
	var context: Dictionary = {
		"entity": actor,
		"components": {
			C_MOVEMENT_COMPONENT.COMPONENT_TYPE: stack.get("movement"),
			C_MOVE_TARGET_COMPONENT.COMPONENT_TYPE: move_target_component,
		},
	}
	var first_task_state: Dictionary = {}
	action.start(context, first_task_state)
	body.global_position = Vector3(100.0, 0.0, 100.0)
	var second_task_state: Dictionary = {}
	action.start(context, second_task_state)
	var second_target_variant: Variant = second_task_state.get(U_AITaskStateKeys.MOVE_TARGET, null)
	assert_true(second_target_variant is Vector3)
	if not (second_target_variant is Vector3):
		return
	var second_target: Vector3 = second_target_variant as Vector3
	var second_offset_xz := Vector2(second_target.x, second_target.z)
	assert_true(second_offset_xz.length() <= 3.0001, "Wander target should remain within original home radius despite actor drift.")

func test_flee_from_detected_uses_actor_and_threat_body_positions() -> void:
	var action_script: Script = _load_script(ACTION_FLEE_FROM_DETECTED_PATH)
	if action_script == null:
		return
	var action: Resource = action_script.new()
	action.set("flee_distance", 5.0)
	var ecs_manager: MockECSManager = MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)
	var actor := Node3D.new()
	actor.name = "E_Rabbit"
	add_child_autofree(actor)
	actor.global_position = Vector3.ZERO
	var actor_stack: Dictionary = _add_movement_stack(actor, Vector3(10.0, 0.0, 0.0))
	var threat := Node3D.new()
	threat.name = "E_Wolf"
	add_child_autofree(threat)
	threat.global_position = Vector3.ZERO
	_add_movement_stack(threat, Vector3(7.0, 0.0, 0.0))
	ecs_manager.register_entity_id(&"wolf", threat)
	var detection: C_DetectionComponent = C_DETECTION_COMPONENT.new()
	detection.last_detected_player_entity_id = &"wolf"
	detection.is_player_in_range = true
	autofree(detection)
	var move_target_component: Variant = _new_move_target_component()
	autofree(move_target_component)
	var context: Dictionary = {
		"entity": actor,
		"ecs_manager": ecs_manager,
		"components": {
			C_MOVEMENT_COMPONENT.COMPONENT_TYPE: actor_stack.get("movement"),
			C_DETECTION_COMPONENT.COMPONENT_TYPE: detection,
			C_MOVE_TARGET_COMPONENT.COMPONENT_TYPE: move_target_component,
		},
	}
	var task_state: Dictionary = {}
	action.start(context, task_state)
	var target_variant: Variant = task_state.get(U_AITaskStateKeys.MOVE_TARGET, null)
	assert_true(target_variant is Vector3)
	if target_variant is Vector3:
		_assert_vector3_almost_eq(target_variant as Vector3, Vector3(15.0, 0.0, 0.0))

func test_flee_from_detected_clamps_target_to_home_radius_when_enabled() -> void:
	var action_script: Script = _load_script(ACTION_FLEE_FROM_DETECTED_PATH)
	if action_script == null:
		return
	var action: Resource = action_script.new()
	action.set("flee_distance", 20.0)
	action.set("clamp_to_home_radius", true)
	action.set("home_radius", 10.0)
	var ecs_manager: MockECSManager = MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)
	var actor := Node3D.new()
	actor.name = "E_Rabbit"
	add_child_autofree(actor)
	actor.global_position = Vector3.ZERO
	var actor_stack: Dictionary = _add_movement_stack(actor, Vector3.ZERO)
	var threat := Node3D.new()
	threat.name = "E_Wolf"
	add_child_autofree(threat)
	threat.global_position = Vector3.ZERO
	_add_movement_stack(threat, Vector3(5.0, 0.0, 0.0))
	ecs_manager.register_entity_id(&"wolf", threat)
	var detection: C_DetectionComponent = C_DETECTION_COMPONENT.new()
	detection.last_detected_player_entity_id = &"wolf"
	detection.is_player_in_range = true
	autofree(detection)
	var move_target_component: Variant = _new_move_target_component()
	autofree(move_target_component)
	var context: Dictionary = {
		"entity": actor,
		"ecs_manager": ecs_manager,
		"components": {
			C_MOVEMENT_COMPONENT.COMPONENT_TYPE: actor_stack.get("movement"),
			C_DETECTION_COMPONENT.COMPONENT_TYPE: detection,
			C_MOVE_TARGET_COMPONENT.COMPONENT_TYPE: move_target_component,
		},
	}
	var task_state: Dictionary = {}
	action.start(context, task_state)
	var target_variant: Variant = task_state.get(U_AITaskStateKeys.MOVE_TARGET, null)
	assert_true(target_variant is Vector3)
	if target_variant is Vector3:
		_assert_vector3_almost_eq(target_variant as Vector3, Vector3(-10.0, 0.0, 0.0))

func test_flee_from_detected_pinned_at_home_boundary_stays_active_while_threat_persists() -> void:
	var action_script: Script = _load_script(ACTION_FLEE_FROM_DETECTED_PATH)
	if action_script == null:
		return
	var action: Resource = action_script.new()
	action.set("flee_distance", 20.0)
	action.set("arrival_threshold", 0.5)
	action.set("clamp_to_home_radius", true)
	action.set("home_radius", 10.0)
	var ecs_manager: MockECSManager = MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)
	var actor := Node3D.new()
	actor.name = "E_Rabbit"
	add_child_autofree(actor)
	actor.global_position = Vector3(-10.0, 0.0, 0.0)
	actor.set_meta(&"ai_home_anchor", Vector3.ZERO)
	var actor_stack: Dictionary = _add_movement_stack(actor, Vector3(-10.0, 0.0, 0.0))
	var threat := Node3D.new()
	threat.name = "E_Wolf"
	add_child_autofree(threat)
	threat.global_position = Vector3.ZERO
	_add_movement_stack(threat, Vector3(0.0, 0.0, 0.0))
	ecs_manager.register_entity_id(&"wolf", threat)
	var detection: C_DetectionComponent = C_DETECTION_COMPONENT.new()
	detection.last_detected_player_entity_id = &"wolf"
	detection.is_player_in_range = true
	autofree(detection)
	var move_target_component: Variant = _new_move_target_component()
	autofree(move_target_component)
	var context: Dictionary = {
		"entity": actor,
		"ecs_manager": ecs_manager,
		"components": {
			C_MOVEMENT_COMPONENT.COMPONENT_TYPE: actor_stack.get("movement"),
			C_DETECTION_COMPONENT.COMPONENT_TYPE: detection,
			C_MOVE_TARGET_COMPONENT.COMPONENT_TYPE: move_target_component,
		},
	}
	var task_state: Dictionary = {}
	action.start(context, task_state)
	var target_variant: Variant = task_state.get(U_AITaskStateKeys.MOVE_TARGET, null)
	assert_true(target_variant is Vector3)
	if target_variant is Vector3:
		_assert_vector3_almost_eq(target_variant as Vector3, Vector3(-10.0, 0.0, 0.0))
	assert_false(
		action.is_complete(context, task_state),
		"Pinned flee targets should hold active while threat remains detected instead of instant complete/restart loops."
	)

func test_flee_from_detected_pinned_hold_releases_when_detection_clears() -> void:
	var action_script: Script = _load_script(ACTION_FLEE_FROM_DETECTED_PATH)
	if action_script == null:
		return
	var action: Resource = action_script.new()
	action.set("flee_distance", 20.0)
	action.set("arrival_threshold", 0.5)
	action.set("clamp_to_home_radius", true)
	action.set("home_radius", 10.0)
	var ecs_manager: MockECSManager = MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)
	var actor := Node3D.new()
	actor.name = "E_Rabbit"
	add_child_autofree(actor)
	actor.global_position = Vector3(-10.0, 0.0, 0.0)
	actor.set_meta(&"ai_home_anchor", Vector3.ZERO)
	var actor_stack: Dictionary = _add_movement_stack(actor, Vector3(-10.0, 0.0, 0.0))
	var threat := Node3D.new()
	threat.name = "E_Wolf"
	add_child_autofree(threat)
	threat.global_position = Vector3.ZERO
	_add_movement_stack(threat, Vector3(0.0, 0.0, 0.0))
	ecs_manager.register_entity_id(&"wolf", threat)
	var detection: C_DetectionComponent = C_DETECTION_COMPONENT.new()
	detection.last_detected_player_entity_id = &"wolf"
	detection.is_player_in_range = true
	autofree(detection)
	var move_target_component: Variant = _new_move_target_component()
	autofree(move_target_component)
	var context: Dictionary = {
		"entity": actor,
		"ecs_manager": ecs_manager,
		"components": {
			C_MOVEMENT_COMPONENT.COMPONENT_TYPE: actor_stack.get("movement"),
			C_DETECTION_COMPONENT.COMPONENT_TYPE: detection,
			C_MOVE_TARGET_COMPONENT.COMPONENT_TYPE: move_target_component,
		},
	}
	var task_state: Dictionary = {}
	action.start(context, task_state)
	assert_false(action.is_complete(context, task_state), "Pinned flee should stay active while threat is still detected.")
	detection.is_player_in_range = false
	assert_true(action.is_complete(context, task_state), "Pinned flee hold should complete once detection exits.")

func test_move_to_detected_tracks_target_body_position() -> void:
	var action_script: Script = _load_script(ACTION_MOVE_TO_DETECTED_PATH)
	if action_script == null:
		return
	var action: Resource = action_script.new()
	var ecs_manager: MockECSManager = MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)
	var actor := Node3D.new()
	actor.name = "E_Wolf"
	add_child_autofree(actor)
	var actor_stack: Dictionary = _add_movement_stack(actor, Vector3.ZERO)
	var target := Node3D.new()
	target.name = "E_Rabbit"
	add_child_autofree(target)
	target.global_position = Vector3.ZERO
	_add_movement_stack(target, Vector3(6.0, 0.0, 0.0))
	ecs_manager.register_entity_id(&"rabbit", target)
	var detection: C_DetectionComponent = C_DETECTION_COMPONENT.new()
	detection.last_detected_player_entity_id = &"rabbit"
	autofree(detection)
	var move_target_component: Variant = _new_move_target_component()
	autofree(move_target_component)
	var context: Dictionary = {
		"entity": actor,
		"ecs_manager": ecs_manager,
		"components": {
			C_MOVEMENT_COMPONENT.COMPONENT_TYPE: actor_stack.get("movement"),
			C_DETECTION_COMPONENT.COMPONENT_TYPE: detection,
			C_MOVE_TARGET_COMPONENT.COMPONENT_TYPE: move_target_component,
		},
	}
	var task_state: Dictionary = {}
	action.start(context, task_state)
	var target_variant: Variant = task_state.get(U_AITaskStateKeys.MOVE_TARGET, null)
	assert_true(target_variant is Vector3)
	if target_variant is Vector3:
		_assert_vector3_almost_eq(target_variant as Vector3, Vector3(6.0, 0.0, 0.0))

func test_move_to_detected_completion_radius_override_allows_feed_range_completion() -> void:
	var action_script: Script = _load_script(ACTION_MOVE_TO_DETECTED_PATH)
	if action_script == null:
		return
	var action: Resource = action_script.new()
	action.set("arrival_threshold", 0.2)
	action.set("completion_radius_override", 1.25)
	var ecs_manager: MockECSManager = MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)
	var actor := Node3D.new()
	actor.name = "E_Wolf"
	add_child_autofree(actor)
	var actor_stack: Dictionary = _add_movement_stack(actor, Vector3.ZERO)
	var target := Node3D.new()
	target.name = "E_Rabbit"
	add_child_autofree(target)
	target.global_position = Vector3.ZERO
	_add_movement_stack(target, Vector3(1.0, 0.0, 0.0))
	ecs_manager.register_entity_id(&"rabbit", target)
	var detection: C_DetectionComponent = C_DETECTION_COMPONENT.new()
	detection.last_detected_player_entity_id = &"rabbit"
	autofree(detection)
	var move_target_component: Variant = _new_move_target_component()
	autofree(move_target_component)
	var context: Dictionary = {
		"entity": actor,
		"ecs_manager": ecs_manager,
		"components": {
			C_MOVEMENT_COMPONENT.COMPONENT_TYPE: actor_stack.get("movement"),
			C_DETECTION_COMPONENT.COMPONENT_TYPE: detection,
			C_MOVE_TARGET_COMPONENT.COMPONENT_TYPE: move_target_component,
		},
	}
	var task_state: Dictionary = {}
	action.start(context, task_state)
	assert_true(action.is_complete(context, task_state), "Completion-radius override should allow success at feed range.")

func test_scan_action_completes_after_duration() -> void:
	var action_script: Script = _load_script(ACTION_SCAN_PATH)
	if action_script == null:
		return

	var action: Resource = action_script.new()
	action.set("scan_duration", 0.4)
	action.set("rotation_speed", 2.0)

	var context: Dictionary = {}
	var task_state: Dictionary = {}
	action.start(context, task_state)

	assert_true(bool(task_state.get("scan_active", false)))
	assert_almost_eq(float(task_state.get("scan_rotation_speed", -1.0)), 2.0, 0.0001)

	action.tick(context, task_state, 0.1)
	assert_false(action.is_complete(context, task_state))
	action.tick(context, task_state, 0.3)
	assert_true(action.is_complete(context, task_state))
	assert_false(bool(task_state.get("scan_active", true)))

func test_animate_stub_sets_state_field() -> void:
	var action_script: Script = _load_script(ACTION_ANIMATE_PATH)
	if action_script == null:
		return

	var action: Resource = action_script.new()
	action.set("animation_state", StringName("alert"))

	var context: Dictionary = {}
	var task_state: Dictionary = {}
	action.start(context, task_state)

	assert_eq(task_state.get("animation_state", StringName()), StringName("alert"))

func test_animate_stub_completes_immediately() -> void:
	var action_script: Script = _load_script(ACTION_ANIMATE_PATH)
	if action_script == null:
		return

	var action: Resource = action_script.new()
	action.set("animation_state", StringName("scan"))

	var context: Dictionary = {}
	var task_state: Dictionary = {}
	action.start(context, task_state)

	assert_true(action.is_complete(context, task_state))
