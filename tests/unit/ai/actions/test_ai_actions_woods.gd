extends BaseTest

const U_AI_TASK_STATE_KEYS := preload("res://scripts/utils/ai/u_ai_task_state_keys.gd")
const I_AI_ACTION := preload("res://scripts/interfaces/i_ai_action.gd")
const RS_AI_ACTION_HARVEST := preload("res://scripts/resources/ai/actions/rs_ai_action_harvest.gd")
const RS_AI_ACTION_HAUL_DEPOSIT := preload("res://scripts/resources/ai/actions/rs_ai_action_haul_deposit.gd")
const RS_AI_ACTION_BUILD_STAGE := preload("res://scripts/resources/ai/actions/rs_ai_action_build_stage.gd")
const RS_AI_ACTION_DRINK := preload("res://scripts/resources/ai/actions/rs_ai_action_drink.gd")
const RS_AI_ACTION_RESERVE := preload("res://scripts/resources/ai/actions/rs_ai_action_reserve.gd")
const RS_AI_ACTION_MOVE_TO_NEAREST := preload("res://scripts/resources/ai/actions/rs_ai_action_move_to_nearest.gd")

const C_RESOURCE_NODE_COMPONENT := preload("res://scripts/ecs/components/c_resource_node_component.gd")
const C_INVENTORY_COMPONENT := preload("res://scripts/ecs/components/c_inventory_component.gd")
const C_BUILD_SITE_COMPONENT := preload("res://scripts/ecs/components/c_build_site_component.gd")
const C_NEEDS_COMPONENT := preload("res://scripts/ecs/components/c_needs_component.gd")
const C_MOVE_TARGET_COMPONENT := preload("res://scripts/ecs/components/c_move_target_component.gd")
const C_DETECTION_COMPONENT := preload("res://scripts/ecs/components/c_detection_component.gd")
const C_MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")
const RS_RESOURCE_NODE_SETTINGS := preload("res://scripts/resources/ai/world/rs_resource_node_settings.gd")
const RS_INVENTORY_SETTINGS := preload("res://scripts/resources/ai/world/rs_inventory_settings.gd")
const RS_BUILD_SITE_SETTINGS := preload("res://scripts/resources/ai/world/rs_build_site_settings.gd")
const RS_BUILD_STAGE := preload("res://scripts/resources/ai/world/rs_build_stage.gd")
const RS_NEEDS_SETTINGS := preload("res://scripts/resources/ecs/rs_needs_settings.gd")
const RS_MOVEMENT_SETTINGS := preload("res://scripts/resources/ecs/rs_movement_settings.gd")

class WoodsActionECSManagerStub extends RefCounted:
	var entities: Dictionary = {}
	var components_by_type: Dictionary = {}

	func get_entity_by_id(entity_id: StringName) -> Node:
		return entities.get(entity_id, null) as Node

	func get_components(component_type: StringName) -> Array:
		var components_variant: Variant = components_by_type.get(component_type, [])
		if components_variant is Array:
			return components_variant as Array
		return []

func _make_context(components: Dictionary = {}) -> Dictionary:
	return {"components": components, "entity_id": &"test_entity"}

func _make_resource_node(settings: RS_ResourceNodeSettings) -> C_ResourceNodeComponent:
	var resource_node: C_ResourceNodeComponent = C_RESOURCE_NODE_COMPONENT.new()
	resource_node.settings = settings
	resource_node._on_required_settings_ready()
	autofree(resource_node)
	return resource_node

func _make_inventory(allowed_types: Array[StringName], capacity: int = 4) -> C_InventoryComponent:
	var inventory: C_InventoryComponent = C_INVENTORY_COMPONENT.new()
	var settings := RS_INVENTORY_SETTINGS.new()
	settings.capacity = capacity
	settings.allowed_types = allowed_types
	inventory.settings = settings
	autofree(inventory)
	return inventory

func _make_move_target_component() -> C_MoveTargetComponent:
	var move_target: C_MoveTargetComponent = C_MOVE_TARGET_COMPONENT.new()
	autofree(move_target)
	return move_target

func _make_build_site_component(required_materials: Dictionary, placed_materials: Dictionary = {}) -> C_BuildSiteComponent:
	var build_site: C_BuildSiteComponent = C_BUILD_SITE_COMPONENT.new()
	var settings := RS_BUILD_SITE_SETTINGS.new()
	var stage := RS_BUILD_STAGE.new()
	stage.stage_id = &"stage"
	stage.required_materials = required_materials.duplicate(true)
	settings.stages = [stage]
	build_site.settings = settings
	build_site.placed_materials = placed_materials.duplicate(true)
	build_site.refresh_materials_ready()
	autofree(build_site)
	return build_site

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

# ── Harvest ──

func test_harvest_action_extends_i_ai_action() -> void:
	var action := RS_AI_ACTION_HARVEST.new()
	assert_true(action is I_AI_ACTION, "RS_AIActionHarvest should extend I_AIAction")

func test_harvest_accumulates_elapsed_and_completes() -> void:
	var action := RS_AI_ACTION_HARVEST.new()
	action.harvest_seconds = 1.0
	var task_state: Dictionary = {}
	action.start({}, task_state)
	assert_eq(task_state.get(U_AI_TASK_STATE_KEYS.HARVEST_ELAPSED, -1.0), 0.0)
	action.tick({}, task_state, 0.5)
	action.tick({}, task_state, 0.5)
	assert_true(action.is_complete({}, task_state), "Harvest should complete after harvest_seconds elapsed.")

func test_harvest_does_not_consume_resource_when_inventory_rejects_type() -> void:
	var action := RS_AI_ACTION_HARVEST.new()
	action.harvest_seconds = 0.0
	action.harvest_amount = 1
	var resource_settings := RS_RESOURCE_NODE_SETTINGS.new()
	resource_settings.resource_type = &"water"
	resource_settings.initial_amount = 5
	var resource_node := _make_resource_node(resource_settings)
	resource_node.reserved_by_entity_id = &"test_entity"
	var inventory := _make_inventory([&"wood"], 4)
	var target_entity := autofree(Node.new())
	target_entity.add_child(resource_node)
	var ecs_manager := WoodsActionECSManagerStub.new()
	ecs_manager.entities[&"resource_target"] = target_entity
	var context: Dictionary = {
		"components": {C_INVENTORY_COMPONENT.COMPONENT_TYPE: inventory},
		"entity_id": &"test_entity",
		"ecs_manager": ecs_manager,
	}
	var task_state: Dictionary = {U_AITaskStateKeys.DETECTED_ENTITY_ID: &"resource_target"}
	action.start(context, task_state)
	assert_true(action.is_complete(context, task_state))
	assert_eq(resource_node.current_amount, 5, "Harvest should not consume stock when inventory rejects resource type.")
	assert_eq(resource_node.reserved_by_entity_id, StringName(""), "Reservation should be cleared after harvest attempt.")
	assert_eq(inventory.total(), 0, "Rejected harvest should not mutate inventory.")

func test_harvest_clears_reservation_after_success() -> void:
	var action := RS_AI_ACTION_HARVEST.new()
	action.harvest_seconds = 0.0
	action.harvest_amount = 2
	var resource_settings := RS_RESOURCE_NODE_SETTINGS.new()
	resource_settings.resource_type = &"wood"
	resource_settings.initial_amount = 5
	var resource_node := _make_resource_node(resource_settings)
	resource_node.reserved_by_entity_id = &"test_entity"
	var inventory := _make_inventory([&"wood"], 4)
	var target_entity := autofree(Node.new())
	target_entity.add_child(resource_node)
	var ecs_manager := WoodsActionECSManagerStub.new()
	ecs_manager.entities[&"resource_target"] = target_entity
	var context: Dictionary = {
		"components": {C_INVENTORY_COMPONENT.COMPONENT_TYPE: inventory},
		"entity_id": &"test_entity",
		"ecs_manager": ecs_manager,
	}
	var task_state: Dictionary = {U_AITaskStateKeys.DETECTED_ENTITY_ID: &"resource_target"}
	action.start(context, task_state)
	assert_true(action.is_complete(context, task_state))
	assert_eq(resource_node.current_amount, 3, "Harvest should consume accepted quantity from resource node.")
	assert_eq(inventory.items.get(&"wood", 0), 2, "Harvest should add accepted quantity to inventory.")
	assert_eq(resource_node.reserved_by_entity_id, StringName(""), "Reservation should be cleared after successful harvest.")

# ── HaulDeposit ──

func test_haul_deposit_extends_i_ai_action() -> void:
	var action := RS_AI_ACTION_HAUL_DEPOSIT.new()
	assert_true(action is I_AI_ACTION, "RS_AIActionHaulDeposit should extend I_AIAction")

func test_haul_deposit_completes_immediately() -> void:
	var action := RS_AI_ACTION_HAUL_DEPOSIT.new()
	var task_state: Dictionary = {}
	action.start({}, task_state)
	assert_true(action.is_complete({}, task_state), "Haul deposit should complete in start().")

func test_haul_deposit_caps_transfer_to_current_stage_missing_materials() -> void:
	var action := RS_AI_ACTION_HAUL_DEPOSIT.new()
	var inventory := _make_inventory([&"wood", &"stone"], 10)
	inventory.add(&"wood", 5)
	inventory.add(&"stone", 2)
	var build_site := _make_build_site_component({&"wood": 2, &"stone": 1}, {&"wood": 1, &"stone": 0})
	var context := _make_context({
		C_INVENTORY_COMPONENT.COMPONENT_TYPE: inventory,
		C_BUILD_SITE_COMPONENT.COMPONENT_TYPE: build_site,
	})
	var task_state: Dictionary = {}
	action.start(context, task_state)
	assert_eq(int(build_site.placed_materials.get(&"wood", 0)), 2, "Wood should cap at stage requirement.")
	assert_eq(int(build_site.placed_materials.get(&"stone", 0)), 1, "Stone should cap at stage requirement.")
	assert_eq(int(inventory.items.get(&"wood", 0)), 4, "Only one wood should be moved.")
	assert_eq(int(inventory.items.get(&"stone", 0)), 1, "Only one stone should be moved.")

func test_move_to_nearest_can_resolve_required_resource_from_build_site_missing_materials() -> void:
	var action := RS_AI_ACTION_MOVE_TO_NEAREST.new()
	action.scan_component_type = C_RESOURCE_NODE_COMPONENT.COMPONENT_TYPE
	action.scan_filter = &"is_available"
	action.set("use_build_site_missing_material", true)
	var wood_settings := RS_RESOURCE_NODE_SETTINGS.new()
	wood_settings.resource_type = &"wood"
	wood_settings.initial_amount = 5
	var stone_settings := RS_RESOURCE_NODE_SETTINGS.new()
	stone_settings.resource_type = &"stone"
	stone_settings.initial_amount = 5
	var wood_entity := autofree(Node3D.new())
	wood_entity.name = "E_WoodNode"
	wood_entity.position = Vector3(1.0, 0.0, 0.0)
	var stone_entity := autofree(Node3D.new())
	stone_entity.name = "E_StoneNode"
	stone_entity.position = Vector3(12.0, 0.0, 0.0)
	add_child(wood_entity)
	add_child(stone_entity)
	var wood_node := _make_resource_node(wood_settings)
	var stone_node := _make_resource_node(stone_settings)
	wood_entity.add_child(wood_node)
	stone_entity.add_child(stone_node)
	var move_target := _make_move_target_component()
	var build_site := _make_build_site_component({&"wood": 2, &"stone": 1}, {&"wood": 2, &"stone": 0})
	var ecs_manager := WoodsActionECSManagerStub.new()
	ecs_manager.components_by_type[C_RESOURCE_NODE_COMPONENT.COMPONENT_TYPE] = [wood_node, stone_node]
	var context := {
		"entity_position": Vector3.ZERO,
		"components": {
			C_MOVE_TARGET_COMPONENT.COMPONENT_TYPE: move_target,
			C_BUILD_SITE_COMPONENT.COMPONENT_TYPE: build_site,
		},
		"ecs_manager": ecs_manager,
	}
	var task_state: Dictionary = {}
	action.start(context, task_state)
	assert_eq(move_target.target_position, stone_entity.global_position, "Missing stone should override nearest wood target.")

# ── BuildStage ──

func test_build_stage_extends_i_ai_action() -> void:
	var action := RS_AI_ACTION_BUILD_STAGE.new()
	assert_true(action is I_AI_ACTION, "RS_AIActionBuildStage should extend I_AIAction")

func test_build_stage_accumulates_elapsed() -> void:
	var action := RS_AI_ACTION_BUILD_STAGE.new()
	var task_state: Dictionary = {}
	action.start({}, task_state)
	assert_eq(task_state.get(U_AI_TASK_STATE_KEYS.BUILD_ELAPSED, -1.0), 0.0)
	action.tick({}, task_state, 1.0)
	assert_eq(task_state.get(U_AI_TASK_STATE_KEYS.BUILD_ELAPSED, 0.0), 1.0)

# ── Drink ──

func test_drink_action_extends_i_ai_action() -> void:
	var action := RS_AI_ACTION_DRINK.new()
	assert_true(action is I_AI_ACTION, "RS_AIActionDrink should extend I_AIAction")

func test_drink_accumulates_elapsed_and_completes() -> void:
	var action := RS_AI_ACTION_DRINK.new()
	action.drink_seconds = 1.0
	var task_state: Dictionary = {}
	action.start({}, task_state)
	action.tick({}, task_state, 0.5)
	assert_false(action.is_complete({}, task_state))
	action.tick({}, task_state, 0.5)
	assert_true(action.is_complete({}, task_state), "Drink should complete after drink_seconds.")

# ── Reserve ──

func test_reserve_action_extends_i_ai_action() -> void:
	var action := RS_AI_ACTION_RESERVE.new()
	assert_true(action is I_AI_ACTION, "RS_AIActionReserve should extend I_AIAction")

func test_reserve_completes_immediately() -> void:
	var action := RS_AI_ACTION_RESERVE.new()
	var task_state: Dictionary = {}
	action.start({}, task_state)
	assert_true(action.is_complete({}, task_state), "Reserve should complete in start().")

# ── MoveToNearest ──

func test_move_to_nearest_filters_resource_type() -> void:
	var action := RS_AI_ACTION_MOVE_TO_NEAREST.new()
	action.scan_component_type = C_RESOURCE_NODE_COMPONENT.COMPONENT_TYPE
	action.scan_filter = &"is_available"
	action.scan_required_resource_type = &"wood"
	var wood_settings := RS_RESOURCE_NODE_SETTINGS.new()
	wood_settings.resource_type = &"wood"
	wood_settings.initial_amount = 5
	var stone_settings := RS_RESOURCE_NODE_SETTINGS.new()
	stone_settings.resource_type = &"stone"
	stone_settings.initial_amount = 5
	var wood_entity := autofree(Node3D.new())
	wood_entity.name = "E_WoodNode"
	wood_entity.position = Vector3(12.0, 0.0, 0.0)
	var stone_entity := autofree(Node3D.new())
	stone_entity.name = "E_StoneNode"
	stone_entity.position = Vector3(1.0, 0.0, 0.0)
	add_child(wood_entity)
	add_child(stone_entity)
	var wood_node := _make_resource_node(wood_settings)
	var stone_node := _make_resource_node(stone_settings)
	wood_entity.add_child(wood_node)
	stone_entity.add_child(stone_node)
	var move_target := _make_move_target_component()
	var detection: C_DetectionComponent = C_DETECTION_COMPONENT.new()
	autofree(detection)
	var components := {
		C_MOVE_TARGET_COMPONENT.COMPONENT_TYPE: move_target,
		C_DETECTION_COMPONENT.COMPONENT_TYPE: detection,
	}
	var ecs_manager := WoodsActionECSManagerStub.new()
	ecs_manager.components_by_type[C_RESOURCE_NODE_COMPONENT.COMPONENT_TYPE] = [stone_node, wood_node]
	var context: Dictionary = {
		"entity_position": Vector3.ZERO,
		"components": components,
		"ecs_manager": ecs_manager,
	}
	var task_state: Dictionary = {}
	action.start(context, task_state)
	assert_true(move_target.is_active, "Move target should activate when a matching resource exists.")
	assert_eq(move_target.target_position, wood_entity.global_position, "Action should ignore nearer non-matching resource types.")
	assert_eq(detection.last_scan_entity_id, &"woodnode")

func test_move_to_nearest_completion_uses_character_body_position() -> void:
	var action := RS_AI_ACTION_MOVE_TO_NEAREST.new()
	action.scan_component_type = C_RESOURCE_NODE_COMPONENT.COMPONENT_TYPE
	action.scan_required_resource_type = &"wood"
	action.arrival_threshold = 0.5
	var actor := Node3D.new()
	actor.name = "E_TestBuilder"
	add_child_autofree(actor)
	actor.global_position = Vector3.ZERO
	var actor_stack: Dictionary = _add_movement_stack(actor, Vector3.ZERO)
	var movement: C_MovementComponent = actor_stack.get("movement") as C_MovementComponent
	var body: CharacterBody3D = actor_stack.get("body") as CharacterBody3D
	var wood_settings := RS_RESOURCE_NODE_SETTINGS.new()
	wood_settings.resource_type = &"wood"
	wood_settings.initial_amount = 5
	var wood_entity := Node3D.new()
	wood_entity.name = "E_WoodNode"
	add_child_autofree(wood_entity)
	wood_entity.global_position = Vector3(8.0, 0.0, 0.0)
	var wood_node := _make_resource_node(wood_settings)
	wood_entity.add_child(wood_node)
	var move_target := _make_move_target_component()
	var ecs_manager := WoodsActionECSManagerStub.new()
	ecs_manager.components_by_type[C_RESOURCE_NODE_COMPONENT.COMPONENT_TYPE] = [wood_node]
	var context: Dictionary = {
		"entity": actor,
		"components": {
			C_MOVEMENT_COMPONENT.COMPONENT_TYPE: movement,
			C_MOVE_TARGET_COMPONENT.COMPONENT_TYPE: move_target,
		},
		"ecs_manager": ecs_manager,
	}
	var task_state: Dictionary = {}
	action.start(context, task_state)
	body.global_position = Vector3(8.2, 0.0, 0.0)
	assert_true(action.is_complete(context, task_state), "MoveToNearest should complete from moving body position, not stale entity root.")

# ── Task state key constants ──

func test_new_task_state_keys_exist() -> void:
	assert_eq(U_AI_TASK_STATE_KEYS.HARVEST_ELAPSED, &"harvest_elapsed")
	assert_eq(U_AI_TASK_STATE_KEYS.BUILD_ELAPSED, &"build_elapsed")
	assert_eq(U_AI_TASK_STATE_KEYS.INVENTORY_RESERVED_TYPE, &"inventory_reserved_type")
