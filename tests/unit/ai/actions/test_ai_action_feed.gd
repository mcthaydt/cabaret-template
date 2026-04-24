extends BaseTest

const ACTION_FEED_PATH := "res://scripts/demo/resources/ai/actions/rs_ai_action_feed.gd"
const BASE_ECS_ENTITY := preload("res://scripts/ecs/base_ecs_entity.gd")
const C_DETECTION_COMPONENT := preload("res://scripts/demo/ecs/components/c_detection_component.gd")
const C_MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")
const C_NEEDS_COMPONENT := preload("res://scripts/demo/ecs/components/c_needs_component.gd")
const RS_NEEDS_SETTINGS := preload("res://scripts/resources/ecs/rs_needs_settings.gd")
const RS_MOVEMENT_SETTINGS := preload("res://scripts/resources/ecs/rs_movement_settings.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const U_AI_TASK_STATE_KEYS := preload("res://scripts/utils/ai/u_ai_task_state_keys.gd")

func _load_script(path: String) -> Script:
	var script_variant: Variant = load(path)
	assert_not_null(script_variant, "Expected script to exist: %s" % path)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func _build_context(hunger: float, gain_on_feed: float) -> Dictionary:
	var needs: C_NeedsComponent = C_NEEDS_COMPONENT.new()
	var settings: RS_NeedsSettings = RS_NEEDS_SETTINGS.new()
	settings.initial_hunger = hunger
	settings.gain_on_feed = gain_on_feed
	needs.settings = settings
	needs.hunger = hunger
	add_child_autofree(needs)
	return {
		"needs": needs,
		"context": {
			"components": {
				C_NEEDS_COMPONENT.COMPONENT_TYPE: needs,
			},
		},
	}

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

func test_feed_action_increases_hunger_and_completes() -> void:
	var action_script: Script = _load_script(ACTION_FEED_PATH)
	if action_script == null:
		return

	var action: Resource = action_script.new()
	var fixture: Dictionary = _build_context(0.25, 0.35)
	var needs: C_NeedsComponent = fixture.get("needs") as C_NeedsComponent
	var context: Dictionary = fixture.get("context", {})
	var task_state: Dictionary = {}

	action.start(context, task_state)

	assert_almost_eq(needs.hunger, 0.6, 0.0001)
	assert_true(action.is_complete(context, task_state))
	assert_true(bool(task_state.get(U_AI_TASK_STATE_KEYS.COMPLETED, false)))

func test_feed_action_clamps_hunger_to_one() -> void:
	var action_script: Script = _load_script(ACTION_FEED_PATH)
	if action_script == null:
		return

	var action: Resource = action_script.new()
	var fixture: Dictionary = _build_context(0.9, 0.5)
	var needs: C_NeedsComponent = fixture.get("needs") as C_NeedsComponent
	var context: Dictionary = fixture.get("context", {})
	var task_state: Dictionary = {}

	action.start(context, task_state)

	assert_eq(needs.hunger, 1.0)
	assert_true(action.is_complete(context, task_state))

func test_feed_action_missing_needs_component_pushes_error_and_completes() -> void:
	var action_script: Script = _load_script(ACTION_FEED_PATH)
	if action_script == null:
		return

	var action: Resource = action_script.new()
	var context: Dictionary = {}
	var task_state: Dictionary = {}

	action.start(context, task_state)

	assert_push_error("RS_AIActionFeed.start: missing C_NeedsComponent in context.")
	assert_true(action.is_complete(context, task_state))

func test_feed_action_consumes_pending_detected_target_when_enabled() -> void:
	var action_script: Script = _load_script(ACTION_FEED_PATH)
	if action_script == null:
		return

	var ecs_manager: MockECSManager = MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)

	var actor: BaseECSEntity = BASE_ECS_ENTITY.new()
	actor.name = "E_Wolf"
	add_child_autofree(actor)
	actor.global_position = Vector3.ZERO
	var needs: C_NeedsComponent = C_NEEDS_COMPONENT.new()
	var settings: RS_NeedsSettings = RS_NEEDS_SETTINGS.new()
	settings.initial_hunger = 0.2
	settings.gain_on_feed = 0.4
	needs.settings = settings
	needs.hunger = 0.2
	actor.add_child(needs)
	autofree(needs)

	var detection: C_DetectionComponent = C_DETECTION_COMPONENT.new()
	actor.add_child(detection)
	autofree(detection)

	var prey: BaseECSEntity = BASE_ECS_ENTITY.new()
	prey.name = "E_Rabbit"
	add_child_autofree(prey)
	prey.global_position = Vector3(0.5, 0.0, 0.0)
	var prey_id: StringName = prey.get_entity_id()
	ecs_manager.register_entity_id(prey_id, prey)

	detection.last_detected_player_entity_id = StringName("")
	detection.pending_feed_entity_id = prey_id
	detection.is_player_in_range = true

	var action: Resource = action_script.new()
	action.set("consume_detected_target", true)
	var context: Dictionary = {
		"entity": actor,
		"entity_position": actor.global_position,
		"ecs_manager": ecs_manager,
		"components": {
			C_NEEDS_COMPONENT.COMPONENT_TYPE: needs,
			C_DETECTION_COMPONENT.COMPONENT_TYPE: detection,
		},
	}
	var task_state: Dictionary = {}

	action.start(context, task_state)

	assert_true(action.is_complete(context, task_state))
	assert_almost_eq(needs.hunger, 0.6, 0.0001, "Successful consume should restore hunger.")
	assert_eq(ecs_manager.get_entity_by_id(prey_id), null, "Expected consumed prey to be unregistered from ECS manager.")
	assert_eq(detection.pending_feed_entity_id, StringName(""), "Expected pending feed target to clear after consume.")
	assert_false(detection.is_player_in_range, "Expected detection in-range state to clear after consume.")

func test_feed_action_does_not_consume_when_outside_consume_radius() -> void:
	var action_script: Script = _load_script(ACTION_FEED_PATH)
	if action_script == null:
		return

	var ecs_manager: MockECSManager = MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)

	var actor: BaseECSEntity = BASE_ECS_ENTITY.new()
	actor.name = "E_Wolf"
	add_child_autofree(actor)
	actor.global_position = Vector3.ZERO
	var needs: C_NeedsComponent = C_NEEDS_COMPONENT.new()
	var settings: RS_NeedsSettings = RS_NEEDS_SETTINGS.new()
	settings.initial_hunger = 0.2
	settings.gain_on_feed = 0.4
	needs.settings = settings
	needs.hunger = 0.2
	actor.add_child(needs)
	autofree(needs)

	var detection: C_DetectionComponent = C_DETECTION_COMPONENT.new()
	actor.add_child(detection)
	autofree(detection)

	var prey: BaseECSEntity = BASE_ECS_ENTITY.new()
	prey.name = "E_Rabbit"
	add_child_autofree(prey)
	prey.global_position = Vector3(9.0, 0.0, 0.0)
	var prey_id: StringName = prey.get_entity_id()
	ecs_manager.register_entity_id(prey_id, prey)

	detection.pending_feed_entity_id = prey_id
	detection.is_player_in_range = true

	var action: Resource = action_script.new()
	action.set("consume_detected_target", true)
	action.set("consume_radius", 1.0)
	var context: Dictionary = {
		"entity": actor,
		"entity_position": actor.global_position,
		"ecs_manager": ecs_manager,
		"components": {
			C_NEEDS_COMPONENT.COMPONENT_TYPE: needs,
			C_DETECTION_COMPONENT.COMPONENT_TYPE: detection,
		},
	}
	var task_state: Dictionary = {}

	action.start(context, task_state)

	assert_true(action.is_complete(context, task_state))
	assert_almost_eq(needs.hunger, 0.2, 0.0001, "Failed consume should not restore hunger.")
	assert_not_null(ecs_manager.get_entity_by_id(prey_id), "Expected distant prey to remain when outside consume radius.")

func test_feed_action_consumes_using_body_positions_when_roots_are_stale() -> void:
	var action_script: Script = _load_script(ACTION_FEED_PATH)
	if action_script == null:
		return
	var ecs_manager: MockECSManager = MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)
	var actor: BaseECSEntity = BASE_ECS_ENTITY.new()
	actor.name = "E_Wolf"
	add_child_autofree(actor)
	actor.global_position = Vector3.ZERO
	var actor_stack: Dictionary = _add_movement_stack(actor, Vector3.ZERO)
	var needs: C_NeedsComponent = C_NEEDS_COMPONENT.new()
	var settings: RS_NeedsSettings = RS_NEEDS_SETTINGS.new()
	settings.initial_hunger = 0.2
	settings.gain_on_feed = 0.4
	needs.settings = settings
	needs.hunger = 0.2
	actor.add_child(needs)
	autofree(needs)
	var detection: C_DetectionComponent = C_DETECTION_COMPONENT.new()
	actor.add_child(detection)
	autofree(detection)
	var prey: BaseECSEntity = BASE_ECS_ENTITY.new()
	prey.name = "E_Rabbit"
	add_child_autofree(prey)
	prey.global_position = Vector3(20.0, 0.0, 0.0)
	_add_movement_stack(prey, Vector3(0.5, 0.0, 0.0))
	var prey_id: StringName = prey.get_entity_id()
	ecs_manager.register_entity_id(prey_id, prey)
	detection.pending_feed_entity_id = prey_id
	detection.is_player_in_range = true
	var action: Resource = action_script.new()
	action.set("consume_detected_target", true)
	action.set("consume_radius", 1.0)
	var context: Dictionary = {
		"entity": actor,
		"ecs_manager": ecs_manager,
		"components": {
			C_MOVEMENT_COMPONENT.COMPONENT_TYPE: actor_stack.get("movement"),
			C_NEEDS_COMPONENT.COMPONENT_TYPE: needs,
			C_DETECTION_COMPONENT.COMPONENT_TYPE: detection,
		},
	}
	var task_state: Dictionary = {}
	action.start(context, task_state)
	assert_almost_eq(needs.hunger, 0.6, 0.0001, "Feed should use actor/prey body positions, not stale roots.")
	assert_eq(ecs_manager.get_entity_by_id(prey_id), null, "Expected body-position consume to unregister prey.")
