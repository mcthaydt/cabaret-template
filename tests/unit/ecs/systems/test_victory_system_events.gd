extends BaseTest

const S_VictorySystem := preload("res://scripts/ecs/systems/s_victory_system.gd")
const C_VictoryTriggerComponent := preload("res://scripts/ecs/components/c_victory_trigger_component.gd")
const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const RS_StateStoreSettings := preload("res://scripts/state/resources/rs_state_store_settings.gd")
const RS_GameplayInitialState := preload("res://scripts/state/resources/rs_gameplay_initial_state.gd")
const U_ECSEventBus := preload("res://scripts/ecs/u_ecs_event_bus.gd")
const U_GameplayActions := preload("res://scripts/state/actions/u_gameplay_actions.gd")

func before_each() -> void:
	U_ECSEventBus.reset()

func test_victory_event_dispatches_actions_and_marks_triggered() -> void:
	var store := M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	add_child_autofree(store)
	await get_tree().process_frame

	var actions: Array[StringName] = []
	var unsubscribe := store.subscribe(func(action: Dictionary, _state: Dictionary) -> void:
		if action != null:
			var action_type: StringName = action.get("type", StringName())
			actions.append(action_type)
	)
	add_child_autofree(Node.new())  # keep tree alive for unsubscribe cleanup

	var system := S_VictorySystem.new()
	system._store = store
	system.on_configured()

	var trigger := C_VictoryTriggerComponent.new()
	trigger.objective_id = StringName("main_objective")
	trigger.area_id = "exterior"

	var body := Node3D.new()

	U_ECSEventBus.publish(StringName("victory_triggered"), {
		"entity_id": StringName("player"),
		"trigger_node": trigger,
		"body": body,
	})
	await get_tree().process_frame

	assert_true(trigger.is_triggered, "Trigger should be marked triggered after handling victory")
	assert_true(actions.has(U_GameplayActions.ACTION_TRIGGER_VICTORY),
		"Victory action should be dispatched")
	assert_true(actions.has(U_GameplayActions.ACTION_MARK_AREA_COMPLETE),
		"Area completion should be dispatched")

	if unsubscribe != null and unsubscribe is Callable and (unsubscribe as Callable).is_valid():
		(unsubscribe as Callable).call()

func test_game_complete_gated_until_area_finished() -> void:
	var store := M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	add_child_autofree(store)
	await get_tree().process_frame

	var actions: Array[StringName] = []
	var unsubscribe := store.subscribe(func(action: Dictionary, _state: Dictionary) -> void:
		if action != null:
			actions.append(action.get("type", StringName()))
	)

	var system := S_VictorySystem.new()
	system._store = store
	system.on_configured()

	var trigger := C_VictoryTriggerComponent.new()
	trigger.victory_type = C_VictoryTriggerComponent.VictoryType.GAME_COMPLETE

	U_ECSEventBus.publish(StringName("victory_triggered"), {
		"entity_id": StringName("player"),
		"trigger_node": trigger,
		"body": Node3D.new(),
	})
	await get_tree().process_frame

	assert_false(trigger.is_triggered, "Game complete should be gated when area not completed")
	assert_false(actions.has(U_GameplayActions.ACTION_GAME_COMPLETE),
		"Game complete action should not dispatch before prerequisites")

	if unsubscribe != null and unsubscribe is Callable and (unsubscribe as Callable).is_valid():
		(unsubscribe as Callable).call()
