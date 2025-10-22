extends BaseTest

const BASE_SCENE := preload("res://templates/base_scene_template.tscn")
const EVENT_BUS := preload("res://scripts/ecs/ecs_event_bus.gd")
const PARTICLE_SYSTEM := preload("res://scripts/ecs/systems/s_jump_particles_system.gd")
const SOUND_SYSTEM := preload("res://scripts/ecs/systems/s_jump_sound_system.gd")
const ECS_UTILS := preload("res://scripts/utils/u_ecs_utils.gd")

const EVENT_NAME := StringName("entity_jumped")

func before_each() -> void:
	EVENT_BUS.reset()

func _setup_scene() -> Dictionary:
	await get_tree().process_frame
	var scene := BASE_SCENE.instantiate()
	add_child(scene)
	autofree(scene)
	await get_tree().process_frame
	await get_tree().process_frame

	var manager: M_ECSManager = scene.get_node("Managers/M_ECSManager") as M_ECSManager
	var player_root := scene.get_node("Entities/E_SpawnPoints/E_PlayerSpawn/E_Player") as Node
	var body := player_root.get_node("Player_Body") as CharacterBody3D
	var components_root := player_root.get_node("Components")

	var components := {}
	for child in components_root.get_children():
		components[child.get_component_type()] = child

	return {
		"scene": scene,
		"manager": manager,
		"body": body,
		"components": components,
	}

func test_entity_jumped_event_notifies_subscribers() -> void:
	var context := await _setup_scene()
	autofree_context(context)
	var manager: M_ECSManager = context["manager"]
	var body: CharacterBody3D = context["body"]
	var components: Dictionary = context["components"]

	var particles := PARTICLE_SYSTEM.new()
	particles.name = "S_JumpParticlesSystem"
	manager.add_child(particles)
	autofree(particles)

	var sound := SOUND_SYSTEM.new()
	sound.name = "S_JumpSoundSystem"
	manager.add_child(sound)
	autofree(sound)

	await get_tree().process_frame
	await get_tree().process_frame

	var captured_events: Array = []
	var unsubscribe: Callable = EVENT_BUS.subscribe(
		EVENT_NAME,
		func(event_data: Dictionary) -> void:
			captured_events.append(event_data)
	)

	var jump_component: C_JumpComponent = components[StringName("C_JumpComponent")]
	var input_component: C_InputComponent = components[StringName("C_InputComponent")]
	var floating_component: C_FloatingComponent = components.get(StringName("C_FloatingComponent"), null)

	body.velocity = Vector3.ZERO
	var now := ECS_UTILS.get_current_time()
	jump_component.mark_on_floor(now)
	if floating_component != null:
		floating_component.update_support_state(true, now)
	input_component.set_jump_pressed(true)

	await get_tree().process_frame
	await get_tree().process_frame

	unsubscribe.call()

	assert_eq(captured_events.size(), 1, "Exactly one jump event should be captured")
	var event_data: Dictionary = captured_events[0]
	assert_eq(event_data.get("name"), EVENT_NAME)

	var payload: Dictionary = event_data.get("payload")
	assert_not_null(payload)
	assert_eq(payload.get("entity"), body)
	assert_eq(payload.get("jump_component"), jump_component)
	assert_eq(payload.get("input_component"), input_component)
	assert_true(payload.get("jump_force", 0.0) > 0.0)

	var history := EVENT_BUS.get_event_history()
	assert_eq(history.size(), 1, "Event history should record the jump event")

	assert_eq(particles.spawn_requests.size(), 1, "Particles system should enqueue a spawn request")
	assert_eq(sound.play_requests.size(), 1, "Sound system should enqueue a play request")

	var spawn_request: Dictionary = particles.spawn_requests[0]
	assert_eq(spawn_request.get("jump_force"), payload.get("jump_force"))

	var sound_request: Dictionary = sound.play_requests[0]
	assert_eq(sound_request.get("entity"), body)
	assert_true(sound_request.get("supported") is bool)
