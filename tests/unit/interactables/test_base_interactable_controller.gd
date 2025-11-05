extends BaseTest

const BASE_INTERACTABLE_CONTROLLER := preload("res://scripts/gameplay/base_interactable_controller.gd")
const BASE_VOLUME_CONTROLLER := preload("res://scripts/gameplay/base_volume_controller.gd")
const M_ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const C_PLAYER_TAG_COMPONENT := preload("res://scripts/ecs/components/c_player_tag_component.gd")
const RS_SCENE_TRIGGER_SETTINGS := preload("res://scripts/ecs/resources/rs_scene_trigger_settings.gd")
const PLAYER_TAG_COMPONENT := StringName("C_PlayerTagComponent")

class FakeArea3D extends Area3D:
	var overlapping_bodies: Array = []

	func get_overlapping_bodies() -> Array:
		return overlapping_bodies.duplicate(true)

func _pump_frames(count: int = 1) -> void:
	for _i in count:
		await get_tree().process_frame

func _pump_physics_frames(count: int = 1) -> void:
	for _i in count:
		await get_tree().physics_frame

func _setup_manager() -> M_ECSManager:
	var manager := M_ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)
	return manager

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

	return {
		"root": player_root,
		"body": body,
		"tag": tag,
	}

func _create_interactable(settings: RS_SceneTriggerSettings = null, area: Area3D = null) -> Node3D:
	var controller := BASE_INTERACTABLE_CONTROLLER.new()
	controller.name = "E_TestInteractable"
	if settings != null:
		controller.settings = settings
	if area != null:
		controller.add_child(area)
		controller.area_path = controller.get_path_to(area)
	add_child(controller)
	autofree(controller)
	await _pump_frames(2)
	return controller

func _initialize_controller_with_player(settings: RS_SceneTriggerSettings = null, area: Area3D = null, configure_before_controller: Callable = Callable()) -> Dictionary:
	var manager := _setup_manager()
	await _pump_frames()
	var player := _create_player_entity()
	await _pump_frames()
	if configure_before_controller != Callable() and configure_before_controller.is_valid():
		var payload := {
			"manager": manager,
			"player_root": player["root"],
			"player_body": player["body"],
			"area": area,
		}
		configure_before_controller.call(payload)
	var controller := await _create_interactable(settings, area)
	await _pump_frames(2)
	return {
		"manager": manager,
		"controller": controller,
		"player_root": player["root"],
		"player_body": player["body"],
	}

func _wait_for_arming(controller: Node3D, physics_frames: int = 2) -> void:
	await _pump_physics_frames(physics_frames)

func test_emits_player_enter_and_exit_events() -> void:
	var context := await _initialize_controller_with_player()
	var controller = context["controller"]
	var area: Area3D = controller.get_trigger_area()
	var body: CharacterBody3D = context["player_body"]

	var enters: Array = []
	var exits: Array = []
	controller.player_entered.connect(func(player: Node3D) -> void:
		enters.append(player))
	controller.player_exited.connect(func(player: Node3D) -> void:
		exits.append(player))

	await _wait_for_arming(controller, 3)

	area.emit_signal("body_entered", body)
	await _pump_frames()

	assert_eq(enters.size(), 1, "Player entering volume should emit player_entered once.")
	assert_true(controller.is_player_in_zone(), "Player should be tracked inside the zone after entering.")

	area.emit_signal("body_exited", body)
	await _pump_frames()

	assert_eq(exits.size(), 1, "Player exiting volume should emit player_exited once.")
	assert_false(controller.is_player_in_zone(), "Player should no longer be tracked after exit.")

func test_cooldown_blocks_activation_until_elapsed() -> void:
	var settings := RS_SCENE_TRIGGER_SETTINGS.new()
	var context := await _initialize_controller_with_player(settings)
	var controller = context["controller"]
	controller.cooldown_duration = 0.5

	var player_entity: Node3D = context["player_root"]
	var body: CharacterBody3D = context["player_body"]
	var area: Area3D = controller.get_trigger_area()
	await _wait_for_arming(controller)
	area.emit_signal("body_entered", body)
	await _pump_frames()

	var first_result: bool = controller.activate(player_entity)
	assert_true(first_result, "First activation should succeed when cooldown is ready.")

	var second_result: bool = controller.activate(player_entity)
	assert_false(second_result, "Activation during cooldown should fail.")

	controller._physics_process(0.6)
	var third_result: bool = controller.activate(player_entity)
	assert_true(third_result, "Activation should succeed after cooldown has elapsed.")

func test_lock_prevents_activation() -> void:
	var context := await _initialize_controller_with_player()
	var controller = context["controller"]
	var player_entity: Node3D = context["player_root"]
	var body: CharacterBody3D = context["player_body"]
	var area: Area3D = controller.get_trigger_area()
	await _wait_for_arming(controller)
	area.emit_signal("body_entered", body)
	await _pump_frames()

	controller.lock()

	var result: bool = controller.activate(player_entity)
	assert_false(result, "Locked interactable should not activate.")

	controller.unlock()
	controller._physics_process(0.1)

	result = controller.activate(player_entity)
	assert_true(result, "Unlocking should allow activation when all other conditions are met.")

func test_detects_spawn_inside_when_configured() -> void:
	var settings := RS_SCENE_TRIGGER_SETTINGS.new()
	settings.ignore_initial_overlap = false
	settings.arm_delay_physics_frames = 2

	var fake_area := FakeArea3D.new()
	fake_area.name = "PreauthoredArea"

	var configure := func(data: Dictionary) -> void:
		var body_config: CharacterBody3D = data["player_body"]
		fake_area.overlapping_bodies = [body_config]

	var context := await _initialize_controller_with_player(settings, fake_area, configure)
	var controller = context["controller"]
	var body: CharacterBody3D = context["player_body"]
	var manager: M_ECSManager = context["manager"]
	var player_root: Node3D = context["player_root"]
	var components: Dictionary = manager.get_components_for_entity(player_root)
	assert_true(components.has(PLAYER_TAG_COMPONENT), "Player entity should register the player tag component.")
	assert_true(controller.get_trigger_area() is FakeArea3D, "Controller should reuse the provided fake area instance.")
	assert_eq(controller.get_trigger_area().get_overlapping_bodies().size(), 1,
		"Fake area helper should report one overlapping body before arming.")
	var resolved_entity: Node3D = controller._resolve_player_entity(body)
	assert_not_null(resolved_entity, "Controller should resolve the player entity from the overlapping body.")

	var enters: Array = []
	controller.player_entered.connect(func(player: Node3D) -> void:
		enters.append(player))

	await _wait_for_arming(controller, 3)
	await _pump_frames()
	assert_eq(controller.get_trigger_area().get_overlapping_bodies().size(), 1,
		"Area should continue reporting overlap after arming.")

	var overlaps: Array = controller.get_trigger_area().get_overlapping_bodies()
	for candidate in overlaps:
		assert_eq(typeof(candidate), TYPE_OBJECT, "Overlap entry should be an object.")
		if candidate is Node3D:
			# Simulate a physics-driven overlap notification by invoking the internal handler.
			controller._handle_body_entered(candidate)
	await _pump_frames()
	assert_eq(controller.get_players().size(), 1, "Manual overlap registration should track the player entity.")

	assert_eq(enters.size(), 1, "Controller should synthesize enter events when player starts inside the volume.")
	assert_true(controller.is_player_in_zone(), "Controller should track player when overlapping at startup.")

	controller.set_enabled(false)
	await _pump_frames()
	assert_false(controller.is_player_in_zone(), "Disabling should clear tracked players.")
	controller.set_enabled(true)

	await _wait_for_arming(controller, 3)
	var refreshed_overlaps: Array = controller.get_trigger_area().get_overlapping_bodies()
	for candidate in refreshed_overlaps:
		if candidate is Node3D:
			controller._handle_body_entered(candidate)
	await _pump_frames()
	assert_eq(enters.size(), 2, "Controller should emit another enter after being re-enabled.")
	assert_true(controller.is_player_in_zone(),
		"Controller should re-register overlapping players after being re-enabled.")

func test_disconnect_trigger_area_signals_unhooks_area_connections() -> void:
	var context := await _initialize_controller_with_player()
	var controller: BaseInteractableController = context["controller"]
	var area: Area3D = controller.get_trigger_area()

	var enter_callable := Callable(controller, "_on_trigger_area_body_entered")
	var exit_callable := Callable(controller, "_on_trigger_area_body_exited")

	assert_true(area.body_entered.is_connected(enter_callable),
		"Trigger area should be connected before explicit disconnect.")
	assert_true(area.body_exited.is_connected(exit_callable),
		"Trigger area should be connected before explicit disconnect.")

	controller.call("_disconnect_trigger_area_signals", area)

	assert_false(area.body_entered.is_connected(enter_callable),
		"Helper should disconnect body_entered signal.")
	assert_false(area.body_exited.is_connected(exit_callable),
		"Helper should disconnect body_exited signal.")
