extends BaseTest


func before_each() -> void:
	U_ECSEventBus.reset()

func test_victory_event_dispatches_actions_and_marks_triggered() -> void:
	var manager := M_ECSManager.new()
	add_child_autofree(manager)
	await get_tree().process_frame

	var store := M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.settings.enable_persistence = false
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
	manager.add_child(system)
	autofree(system)
	await get_tree().process_frame
	# on_configured() is automatically called by BaseECSSystem.configure()

	var trigger_entity := Node3D.new()
	trigger_entity.name = "E_VictoryTrigger"
	add_child_autofree(trigger_entity)

	var trigger := C_VictoryTriggerComponent.new()
	trigger.objective_id = StringName("main_objective")
	trigger.area_id = "exterior"
	trigger_entity.add_child(trigger)
	autofree(trigger)

	var body := Node3D.new()
	add_child_autofree(body)

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
	var manager := M_ECSManager.new()
	add_child_autofree(manager)
	await get_tree().process_frame

	var store := M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.settings.enable_persistence = false
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	add_child_autofree(store)
	await get_tree().process_frame

	var actions: Array[StringName] = []
	var unsubscribe := store.subscribe(func(action: Dictionary, _state: Dictionary) -> void:
		if action != null:
			actions.append(action.get("type", StringName()))
	)

	var system := S_VictorySystem.new()
	manager.add_child(system)
	autofree(system)
	await get_tree().process_frame
	# on_configured() is automatically called by BaseECSSystem.configure()

	var trigger_entity := Node3D.new()
	trigger_entity.name = "E_VictoryTrigger"
	add_child_autofree(trigger_entity)

	var trigger := C_VictoryTriggerComponent.new()
	trigger.victory_type = C_VictoryTriggerComponent.VictoryType.GAME_COMPLETE
	trigger_entity.add_child(trigger)
	autofree(trigger)

	var body := Node3D.new()
	add_child_autofree(body)

	U_ECSEventBus.publish(StringName("victory_triggered"), {
		"entity_id": StringName("player"),
		"trigger_node": trigger,
		"body": body,
	})
	await get_tree().process_frame

	assert_false(trigger.is_triggered, "Game complete should be gated when area not completed")
	assert_false(actions.has(U_GameplayActions.ACTION_GAME_COMPLETE),
		"Game complete action should not dispatch before prerequisites")

	if unsubscribe != null and unsubscribe is Callable and (unsubscribe as Callable).is_valid():
		(unsubscribe as Callable).call()
