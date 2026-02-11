extends BaseTest

const TRIGGERED_INTERACTABLE_CONTROLLER := preload("res://scripts/gameplay/triggered_interactable_controller.gd")
const BASE_INTERACTABLE_CONTROLLER := preload("res://scripts/gameplay/base_interactable_controller.gd")
const M_ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const C_PLAYER_TAG_COMPONENT := preload("res://scripts/ecs/components/c_player_tag_component.gd")
const I_SCENE_MANAGER := preload("res://scripts/interfaces/i_scene_manager.gd")
const INTERACTION_HINT_TEXTURE := preload("res://assets/textures/tex_icon.svg")

class TransitioningSceneManager:
	extends I_SCENE_MANAGER

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

func _arm(_controller: Node3D) -> void:
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

func test_world_hint_shows_in_interact_mode_when_player_enters_unblocked_zone() -> void:
	var context := await _initialize_context()
	var controller = context["controller"]
	controller.trigger_mode = controller.TriggerMode.INTERACT
	controller.interaction_hint_enabled = true
	controller.interaction_hint_icon = INTERACTION_HINT_TEXTURE

	var area: Area3D = controller.get_trigger_area()
	var body: CharacterBody3D = context["player_body"]
	await _arm(controller)

	area.emit_signal("body_entered", body)
	await _pump_physics_frames(1)

	var icon := controller.get_node_or_null("SO_InteractionHintIcon") as Sprite3D
	assert_not_null(icon, "Interact-mode controller should create world hint icon when configured.")
	assert_true(icon.visible, "World hint icon should be visible when player is in range and interaction is available.")

func test_world_hint_visible_out_of_range_when_unblocked() -> void:
	var context := await _initialize_context()
	var controller = context["controller"]
	controller.trigger_mode = controller.TriggerMode.INTERACT
	controller.interaction_hint_enabled = true
	controller.interaction_hint_icon = INTERACTION_HINT_TEXTURE

	await _arm(controller)
	await _pump_physics_frames(1)

	var icon := controller.get_node_or_null("SO_InteractionHintIcon") as Sprite3D
	assert_not_null(icon, "World hint icon should be created when configured.")
	assert_true(icon.visible, "World hint should stay visible even when player is out of range.")

func test_world_hint_uses_camera_facing_render_defaults() -> void:
	var context := await _initialize_context()
	var controller = context["controller"]
	controller.trigger_mode = controller.TriggerMode.INTERACT
	controller.interaction_hint_enabled = true
	controller.interaction_hint_icon = INTERACTION_HINT_TEXTURE

	var area: Area3D = controller.get_trigger_area()
	var body: CharacterBody3D = context["player_body"]
	await _arm(controller)

	area.emit_signal("body_entered", body)
	await _pump_physics_frames(1)

	var icon := controller.get_node_or_null("SO_InteractionHintIcon") as Sprite3D
	assert_not_null(icon, "World hint icon should be created when configured.")
	assert_eq(icon.billboard, BaseMaterial3D.BILLBOARD_ENABLED,
		"World hint icon should billboard toward the active camera.")
	assert_true(icon.double_sided, "World hint icon should render from both sides.")
	assert_false(icon.shaded, "World hint icon should remain readable regardless of scene lighting.")

func test_world_hint_stays_visible_when_player_exits_zone() -> void:
	var context := await _initialize_context()
	var controller = context["controller"]
	controller.trigger_mode = controller.TriggerMode.INTERACT
	controller.interaction_hint_enabled = true
	controller.interaction_hint_icon = INTERACTION_HINT_TEXTURE

	var area: Area3D = controller.get_trigger_area()
	var body: CharacterBody3D = context["player_body"]
	await _arm(controller)

	area.emit_signal("body_entered", body)
	await _pump_physics_frames(1)
	var icon := controller.get_node_or_null("SO_InteractionHintIcon") as Sprite3D
	assert_not_null(icon)
	assert_true(icon.visible, "World hint should show when entering range.")

	area.emit_signal("body_exited", body)
	await _pump_physics_frames(1)
	assert_true(icon.visible, "World hint should remain visible after player leaves range.")

func test_world_hint_suppressed_while_scene_transition_blocked() -> void:
	var context := await _initialize_context()
	var controller = context["controller"]
	controller.trigger_mode = controller.TriggerMode.INTERACT
	controller.interaction_hint_enabled = true
	controller.interaction_hint_icon = INTERACTION_HINT_TEXTURE

	var scene_manager := TransitioningSceneManager.new()
	scene_manager.name = "SceneManagerStub"
	scene_manager.transitioning = true
	add_child(scene_manager)
	autofree(scene_manager)
	U_ServiceLocator.register(StringName("scene_manager"), scene_manager)

	var area: Area3D = controller.get_trigger_area()
	var body: CharacterBody3D = context["player_body"]
	await _arm(controller)

	area.emit_signal("body_entered", body)
	await _pump_physics_frames(1)

	var icon := controller.get_node_or_null("SO_InteractionHintIcon") as Sprite3D
	assert_not_null(icon, "World hint icon node should still be created when configured.")
	assert_false(icon.visible, "World hint should remain hidden while transitions are blocking interaction.")

func test_world_hint_coexists_with_hud_prompt_show_event() -> void:
	U_ECSEventBus.reset()
	var context := await _initialize_context()
	var controller = context["controller"]
	controller.trigger_mode = controller.TriggerMode.INTERACT
	controller.interaction_hint_enabled = true
	controller.interaction_hint_icon = INTERACTION_HINT_TEXTURE

	var shows: Array = []
	var unsubscribe_show := U_ECSEventBus.subscribe(StringName("interact_prompt_show"), func(payload: Variant) -> void:
		shows.append(payload)
	)

	var area: Area3D = controller.get_trigger_area()
	var body: CharacterBody3D = context["player_body"]
	await _arm(controller)
	area.emit_signal("body_entered", body)
	await _pump_physics_frames(1)

	var icon := controller.get_node_or_null("SO_InteractionHintIcon") as Sprite3D
	assert_not_null(icon, "World hint icon should be created when configured.")
	assert_true(icon.visible, "World hint icon should be visible when unblocked.")
	assert_eq(shows.size(), 1, "HUD prompt show event should still publish while world hint is visible.")

	if unsubscribe_show != null and unsubscribe_show.is_valid():
		unsubscribe_show.call()

func test_world_hint_hidden_while_interact_blocker_active() -> void:
	var context := await _initialize_context()
	var controller = context["controller"]
	controller.trigger_mode = controller.TriggerMode.INTERACT
	controller.interaction_hint_enabled = true
	controller.interaction_hint_icon = INTERACTION_HINT_TEXTURE

	var area: Area3D = controller.get_trigger_area()
	var body: CharacterBody3D = context["player_body"]
	await _arm(controller)
	area.emit_signal("body_entered", body)
	await _pump_physics_frames(1)

	var icon := controller.get_node_or_null("SO_InteractionHintIcon") as Sprite3D
	assert_not_null(icon)
	assert_true(icon.visible, "World hint should show before blocker is active.")

	U_InteractBlocker.block()
	controller._physics_process(0.016)
	assert_false(icon.visible, "World hint should hide while interact blocker is active.")
	U_InteractBlocker.cleanup()

func after_each() -> void:
	U_InteractBlocker.cleanup()
	U_ServiceLocator.clear()
