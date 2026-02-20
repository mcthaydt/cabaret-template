extends BaseTest

const VICTORY_HANDLER_SYSTEM := preload("res://scripts/ecs/systems/s_victory_handler_system.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")

func before_each() -> void:
	U_ECSEventBus.reset()

func _pump() -> void:
	await get_tree().process_frame

func _setup_fixture() -> Dictionary:
	var store := MOCK_STATE_STORE.new()
	autofree(store)
	store.set_slice(StringName("gameplay"), {"completed_areas": []})

	var ecs_manager := MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)

	var system := VICTORY_HANDLER_SYSTEM.new()
	autofree(system)
	system.state_store = store
	system.ecs_manager = ecs_manager
	add_child(system)
	system.configure(ecs_manager)
	await _pump()

	return {
		"system": system,
		"store": store,
	}

func _create_trigger() -> C_VictoryTriggerComponent:
	var trigger_entity := Node3D.new()
	trigger_entity.name = "E_VictoryTrigger"
	add_child(trigger_entity)
	autofree(trigger_entity)

	var trigger := C_VictoryTriggerComponent.new()
	trigger_entity.add_child(trigger)
	autofree(trigger)
	return trigger

func test_victory_execution_flow_dispatches_actions_and_sets_triggered() -> void:
	var fixture: Dictionary = await _setup_fixture()
	var store: MockStateStore = fixture["store"] as MockStateStore

	var trigger := _create_trigger()
	trigger.objective_id = StringName("main_objective")
	trigger.area_id = "exterior"
	trigger.victory_type = C_VictoryTriggerComponent.VictoryType.LEVEL_COMPLETE

	U_ECSEventBus.publish(U_ECSEventNames.EVENT_VICTORY_EXECUTION_REQUESTED, {
		"entity_id": StringName("player"),
		"trigger_node": trigger,
	})
	await _pump()

	assert_true(trigger.is_triggered, "Victory trigger should be marked triggered")

	var action_types: Array[StringName] = []
	for action in store.get_dispatched_actions():
		action_types.append(action.get("type", StringName()))

	assert_true(action_types.has(U_GameplayActions.ACTION_TRIGGER_VICTORY))
	assert_true(action_types.has(U_GameplayActions.ACTION_MARK_AREA_COMPLETE))

func test_game_complete_requires_bar_area_before_dispatch() -> void:
	var fixture: Dictionary = await _setup_fixture()
	var store: MockStateStore = fixture["store"] as MockStateStore
	var trigger := _create_trigger()
	trigger.victory_type = C_VictoryTriggerComponent.VictoryType.GAME_COMPLETE

	store.set_slice(StringName("gameplay"), {"completed_areas": ["exterior"]})
	U_ECSEventBus.publish(U_ECSEventNames.EVENT_VICTORY_EXECUTION_REQUESTED, {
		"trigger_node": trigger,
	})
	await _pump()

	assert_false(trigger.is_triggered, "GAME_COMPLETE should be gated when bar area is missing")
	var action_types_blocked: Array[StringName] = []
	for action in store.get_dispatched_actions():
		action_types_blocked.append(action.get("type", StringName()))
	assert_false(action_types_blocked.has(U_GameplayActions.ACTION_GAME_COMPLETE))

	store.clear_dispatched_actions()
	store.set_slice(StringName("gameplay"), {"completed_areas": ["bar"]})
	U_ECSEventBus.publish(U_ECSEventNames.EVENT_VICTORY_EXECUTION_REQUESTED, {
		"trigger_node": trigger,
	})
	await _pump()

	assert_true(trigger.is_triggered, "GAME_COMPLETE should execute when bar area is complete")
	var action_types_allowed: Array[StringName] = []
	for action in store.get_dispatched_actions():
		action_types_allowed.append(action.get("type", StringName()))
	assert_true(action_types_allowed.has(U_GameplayActions.ACTION_GAME_COMPLETE))

func test_trigger_once_guard_blocks_when_already_triggered() -> void:
	var fixture: Dictionary = await _setup_fixture()
	var store: MockStateStore = fixture["store"] as MockStateStore
	var trigger := _create_trigger()
	trigger.trigger_once = true
	trigger.is_triggered = true

	U_ECSEventBus.publish(U_ECSEventNames.EVENT_VICTORY_EXECUTION_REQUESTED, {
		"trigger_node": trigger,
	})
	await _pump()

	assert_eq(store.get_dispatched_actions().size(), 0, "Already-triggered trigger_once should not dispatch actions")
