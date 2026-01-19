extends BaseTest

const TRIGGERED_INTERACTABLE_CONTROLLER := preload("res://scripts/gameplay/triggered_interactable_controller.gd")
const BASE_INTERACTABLE_CONTROLLER := preload("res://scripts/gameplay/base_interactable_controller.gd")
const M_ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const C_PLAYER_TAG_COMPONENT := preload("res://scripts/ecs/components/c_player_tag_component.gd")
const U_ECSEventBus := preload("res://scripts/ecs/u_ecs_event_bus.gd")
const U_ServiceLocator := preload("res://scripts/core/u_service_locator.gd")

class TransitioningSceneManager:
	extends Node

	var transitioning: bool = false

	func is_transitioning() -> bool:
		return transitioning

func _pump_frames(count: int = 1) -> void:
	for _i in count:
		await get_tree().process_frame

func _pump_physics_frames(count: int = 1) -> void:
	for _i in count:
		await get_tree().physics_frame

func _setup_manager() -> void:
	var manager := M_ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await _pump_frames()

func _create_player_entity() -> Dictionary:
	var player_root := Node3D.new()
	player_root.name = "E_Player"
	add_child(player_root)
	autofree(player_root)

	var body := CharacterBody3D.new()
	body.name = "PlayerBody"
	player_root.add_child(body)

	var tag := C_PLAYER_TAG_COMPONENT.new()
	player_root.add_child(tag)

	await _pump_frames(2)

	return {
		"root": player_root,
		"body": body,
	}

func _create_controller() -> Node3D:
	var controller := TRIGGERED_INTERACTABLE_CONTROLLER.new()
	controller.name = "E_TestTrigger"
	add_child(controller)
	autofree(controller)
	await _pump_frames(2)
	return controller

func _initialize_context() -> Dictionary:
	await _setup_manager()
	var player := await _create_player_entity()
	var controller := await _create_controller()
	await _pump_frames(2)
	return {
		"controller": controller,
		"player_root": player["root"],
		"player_body": player["body"],
	}

func _arm(controller: Node3D) -> void:
	await _pump_physics_frames(2)

func test_auto_mode_activates_on_enter() -> void:
	var context := await _initialize_context()
	var controller = context["controller"]
	controller.trigger_mode = controller.TriggerMode.AUTO

	var activations: Array = []
	controller.activated.connect(func(player: Node3D) -> void:
		activations.append(player))

	var area: Area3D = controller.get_trigger_area()
	var body: CharacterBody3D = context["player_body"]

	await _arm(controller)
	area.emit_signal("body_entered", body)
	await _pump_frames()

	assert_eq(activations.size(), 1, "AUTO mode should activate immediately when the player enters.")

func test_interact_mode_requires_input_action() -> void:
	var context := await _initialize_context()
	var controller = context["controller"]
	controller.trigger_mode = controller.TriggerMode.INTERACT
	controller.interact_action = StringName("test_interact")

	if not InputMap.has_action("test_interact"):
		InputMap.add_action("test_interact")

	var activations: Array = []
	controller.activated.connect(func(player: Node3D) -> void:
		activations.append(player))

	var area: Area3D = controller.get_trigger_area()
	var body: CharacterBody3D = context["player_body"]

	await _arm(controller)
	area.emit_signal("body_entered", body)
	await _pump_frames()

	assert_eq(activations.size(), 0, "INTERACT mode should not activate on enter without input.")

	Input.action_press("test_interact")
	controller._physics_process(0.016)
	Input.action_release("test_interact")
	controller._physics_process(0.016)
	await _pump_frames()

	assert_eq(activations.size(), 1, "Pressing the interact action should activate the controller once.")

	InputMap.erase_action("test_interact")

func test_interact_action_does_not_fire_without_player() -> void:
	var controller := await _create_controller()
	controller.trigger_mode = controller.TriggerMode.INTERACT
	controller.interact_action = StringName("orphan_interact")

	if not InputMap.has_action("orphan_interact"):
		InputMap.add_action("orphan_interact")

	var activations: Array = []
	controller.activated.connect(func(player: Node3D) -> void:
		activations.append(player))

	Input.action_press("orphan_interact")
	controller._physics_process(0.016)
	Input.action_release("orphan_interact")
	controller._physics_process(0.016)
	await _pump_frames()

	assert_eq(activations.size(), 0, "Without a player inside the volume the action should do nothing.")

	InputMap.erase_action("orphan_interact")

func test_interact_prompt_events_on_enter_and_exit() -> void:
	U_ECSEventBus.reset()

	var context := await _initialize_context()
	var controller = context["controller"]
	controller.trigger_mode = controller.TriggerMode.INTERACT
	controller.interact_action = StringName("prompt_action")
	controller.interact_prompt = "Test Prompt"

	if not InputMap.has_action("prompt_action"):
		InputMap.add_action("prompt_action")

	var shows: Array = []
	var hides: Array = []
	var unsubscribe_show := U_ECSEventBus.subscribe(StringName("interact_prompt_show"), func(payload: Variant) -> void:
		shows.append(payload)
	)
	var unsubscribe_hide := U_ECSEventBus.subscribe(StringName("interact_prompt_hide"), func(payload: Variant) -> void:
		hides.append(payload)
	)

	var area: Area3D = controller.get_trigger_area()
	var body: CharacterBody3D = context["player_body"]

	await _arm(controller)
	area.emit_signal("body_entered", body)
	await _pump_frames()

	assert_eq(shows.size(), 1, "Entering the trigger should publish prompt show event once.")
	var show_event := shows[0] as Dictionary
	var show_payload := show_event.get("payload", {}) as Dictionary
	assert_eq(int(show_payload.get("controller_id", 0)), controller.get_instance_id())
	assert_eq(StringName(show_payload.get("action", StringName())), StringName("prompt_action"))
	assert_eq(String(show_payload.get("prompt", "")), "Test Prompt")

	area.emit_signal("body_exited", body)
	await _pump_frames()

	assert_eq(hides.size(), 1, "Exiting the trigger should publish prompt hide event.")
	var hide_event := hides[0] as Dictionary
	var hide_payload := hide_event.get("payload", {}) as Dictionary
	assert_eq(int(hide_payload.get("controller_id", 0)), controller.get_instance_id())

	if unsubscribe_show != null and unsubscribe_show.is_valid():
		unsubscribe_show.call()
	if unsubscribe_hide != null and unsubscribe_hide.is_valid():
		unsubscribe_hide.call()

	InputMap.erase_action("prompt_action")

func test_activation_blocked_during_scene_transition() -> void:
	var context := await _initialize_context()
	var controller = context["controller"]
	controller.trigger_mode = controller.TriggerMode.INTERACT

	var scene_manager := TransitioningSceneManager.new()
	scene_manager.name = "SceneManagerStub"
	scene_manager.transitioning = true
	add_child(scene_manager)
	autofree(scene_manager)
	# Register scene_manager with ServiceLocator so controllers can find it
	U_ServiceLocator.register(StringName("scene_manager"), scene_manager)

	var area: Area3D = controller.get_trigger_area()
	var player_body: CharacterBody3D = context["player_body"]
	await _arm(controller)
	area.emit_signal("body_entered", player_body)
	await _pump_frames()

	var player_entity: Node3D = context["player_root"]
	assert_false(controller.activate(player_entity),
		"Activation should be blocked while the scene manager is transitioning.")

	scene_manager.transitioning = false
	assert_true(controller.activate(player_entity),
		"Activation should succeed once the scene manager finishes transitioning.")

func after_each() -> void:
	U_ServiceLocator.clear()
