extends BaseTest

const U_AI_TASK_STATE_KEYS := preload("res://scripts/utils/ai/u_ai_task_state_keys.gd")
const I_AI_ACTION := preload("res://scripts/interfaces/i_ai_action.gd")
const RS_AI_ACTION_HARVEST := preload("res://scripts/resources/ai/actions/rs_ai_action_harvest.gd")
const RS_AI_ACTION_HAUL_DEPOSIT := preload("res://scripts/resources/ai/actions/rs_ai_action_haul_deposit.gd")
const RS_AI_ACTION_BUILD_STAGE := preload("res://scripts/resources/ai/actions/rs_ai_action_build_stage.gd")
const RS_AI_ACTION_DRINK := preload("res://scripts/resources/ai/actions/rs_ai_action_drink.gd")
const RS_AI_ACTION_RESERVE := preload("res://scripts/resources/ai/actions/rs_ai_action_reserve.gd")

const C_RESOURCE_NODE_COMPONENT := preload("res://scripts/ecs/components/c_resource_node_component.gd")
const C_INVENTORY_COMPONENT := preload("res://scripts/ecs/components/c_inventory_component.gd")
const C_BUILD_SITE_COMPONENT := preload("res://scripts/ecs/components/c_build_site_component.gd")
const C_NEEDS_COMPONENT := preload("res://scripts/ecs/components/c_needs_component.gd")
const RS_RESOURCE_NODE_SETTINGS := preload("res://scripts/resources/ai/world/rs_resource_node_settings.gd")
const RS_INVENTORY_SETTINGS := preload("res://scripts/resources/ai/world/rs_inventory_settings.gd")
const RS_BUILD_SITE_SETTINGS := preload("res://scripts/resources/ai/world/rs_build_site_settings.gd")
const RS_BUILD_STAGE := preload("res://scripts/resources/ai/world/rs_build_stage.gd")
const RS_NEEDS_SETTINGS := preload("res://scripts/resources/ecs/rs_needs_settings.gd")

func _make_context(components: Dictionary = {}) -> Dictionary:
	return {"components": components, "entity_id": &"test_entity"}

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

# ── HaulDeposit ──

func test_haul_deposit_extends_i_ai_action() -> void:
	var action := RS_AI_ACTION_HAUL_DEPOSIT.new()
	assert_true(action is I_AI_ACTION, "RS_AIActionHaulDeposit should extend I_AIAction")

func test_haul_deposit_completes_immediately() -> void:
	var action := RS_AI_ACTION_HAUL_DEPOSIT.new()
	var task_state: Dictionary = {}
	action.start({}, task_state)
	assert_true(action.is_complete({}, task_state), "Haul deposit should complete in start().")

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

# ── Task state key constants ──

func test_new_task_state_keys_exist() -> void:
	assert_eq(U_AI_TASK_STATE_KEYS.HARVEST_ELAPSED, &"harvest_elapsed")
	assert_eq(U_AI_TASK_STATE_KEYS.BUILD_ELAPSED, &"build_elapsed")
	assert_eq(U_AI_TASK_STATE_KEYS.INVENTORY_RESERVED_TYPE, &"inventory_reserved_type")