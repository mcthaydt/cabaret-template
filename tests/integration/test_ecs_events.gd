extends BaseTest

const BASE_SCENE := preload("res://scenes/templates/tmpl_base_scene.tscn")
const EVENT_BUS := preload("res://scripts/ecs/u_ecs_event_bus.gd")
const JUMP_PARTICLE_SYSTEM := preload("res://scripts/ecs/systems/s_jump_particles_system.gd")
const JUMP_SOUND_SYSTEM := preload("res://scripts/ecs/systems/s_jump_sound_system.gd")
const ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")
const U_ServiceLocator = preload("res://scripts/core/u_service_locator.gd")

const EVENT_JUMPED := StringName("entity_jumped")
const EVENT_LANDED := StringName("entity_landed")

var _state_store: M_StateStore = null

func before_each() -> void:
	# Clear ServiceLocator first to ensure clean state between tests
	U_ServiceLocator.clear()

	EVENT_BUS.reset()
	# Clear state handoff to prevent interference between tests
	U_StateHandoff.clear_all()

	# Create and add M_StateStore for systems that require it
	_state_store = M_StateStore.new()
	add_child(_state_store)
	autofree(_state_store)
	U_ServiceLocator.register(StringName("state_store"), _state_store)
	await get_tree().process_frame

func after_each() -> void:
	# Clear ServiceLocator to prevent state leakage
	U_ServiceLocator.clear()

func _setup_scene() -> Dictionary:
	await get_tree().process_frame
	var scene := BASE_SCENE.instantiate()
	add_child(scene)
	autofree(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	# Extra wait for state store and systems to fully initialize
	await get_tree().physics_frame
	await get_tree().physics_frame

	var manager: M_ECSManager = scene.get_node("Managers/M_ECSManager") as M_ECSManager
	var player_root: Node = get_player_root(scene)
	assert_not_null(player_root, "Base scene should expose the E_Player entity")

	var body := player_root.get_node("Player_Body") as CharacterBody3D
	var components_root: Node = player_root.get_node("Components")

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
	var scene: Node = context["scene"]

	# Get existing systems from the scene instead of creating new ones
	# Systems are now organized in category groups (Feedback contains VFX/audio systems)
	var particles = scene.get_node("Systems/Feedback/S_JumpParticlesSystem")
	var sound = scene.get_node("Systems/Feedback/S_JumpSoundSystem")
	assert_not_null(particles, "Scene should have S_JumpParticlesSystem")
	assert_not_null(sound, "Scene should have S_JumpSoundSystem")

	var captured_events: Array = []
	var unsubscribe: Callable = EVENT_BUS.subscribe(
		EVENT_JUMPED,
		func(event_data: Dictionary) -> void:
			captured_events.append(event_data)
	)

	# Use Dictionary to capture data (mutable, captured by reference in lambda)
	# GDScript lambdas capture primitives by value, but objects by reference!
	var captured_data := {
		"particles_queued": false,
		"sound_queued": false,
		"particle_request": {},
		"sound_request": {},
	}

	# Subscribe BEFORE jump to capture request data when event fires
	# Requests are queued synchronously during event publication, then cleared by process_tick
	var check_sub: Callable = EVENT_BUS.subscribe(
		EVENT_JUMPED,
		func(_event_data: Dictionary) -> void:
			# Capture DURING event publication (before systems' process_tick clears the requests)
			if particles.spawn_requests.size() >= 1:
				captured_data["particles_queued"] = true
				captured_data["particle_request"] = particles.spawn_requests[0].duplicate(true)
			if sound.play_requests.size() >= 1:
				captured_data["sound_queued"] = true
				captured_data["sound_request"] = sound.play_requests[0].duplicate(true)
	)

	var jump_component: C_JumpComponent = components[StringName("C_JumpComponent")]
	var input_component: C_InputComponent = components[StringName("C_InputComponent")]
	var floating_component: C_FloatingComponent = components.get(StringName("C_FloatingComponent"), null)

	body.velocity = Vector3.ZERO
	var now := ECS_UTILS.get_current_time()
	jump_component.record_ground_height(body.global_position.y)
	jump_component.mark_on_floor(now)
	if floating_component != null:
		floating_component.update_support_state(true, now)
	input_component.set_jump_pressed(true)

	# Manually trigger physics process to run systems (physics doesn't auto-run in tests)
	manager._physics_process(1.0 / 60.0)
	
	check_sub.call()  # Unsubscribe checker

	# Validate that requests were queued when event fired
	assert_true(captured_data["particles_queued"], "Particles system should have queued spawn request during event")
	assert_true(captured_data["sound_queued"], "Sound system should have queued play request during event")

	# Validate particle spawn request data (from captured copy)
	var particle_req: Dictionary = captured_data["particle_request"]
	assert_true(particle_req.has("position"), "Spawn request should have position")
	assert_true(particle_req.has("velocity"), "Spawn request should have velocity")
	assert_true(particle_req.has("jump_force"), "Spawn request should have jump_force")
	assert_true(particle_req.has("timestamp"), "Spawn request should have timestamp")

	# Validate sound play request data (from captured copy)
	var sound_req: Dictionary = captured_data["sound_request"]
	assert_not_null(sound_req.get("entity"), "Sound request should have entity")
	assert_true(sound_req.get("supported") is bool, "Sound request should have supported bool")

	# Second frame allows process_tick to process requests
	await get_tree().process_frame

	unsubscribe.call()

	assert_eq(captured_events.size(), 1, "Exactly one jump event should be captured")
	var event_data: Dictionary = captured_events[0]
	assert_eq(event_data.get("name"), EVENT_JUMPED)

	var payload: Dictionary = event_data.get("payload")
	assert_not_null(payload)
	assert_eq(payload.get("entity"), body)
	assert_eq(payload.get("jump_component"), jump_component)
	assert_eq(payload.get("input_component"), input_component)
	assert_true(payload.get("jump_force", 0.0) > 0.0)

	var history := EVENT_BUS.get_event_history()
	assert_true(history.size() >= 1, "Event history should record at least the jump event")

	# Count jump events in history
	var jump_event_count := 0
	for event in history:
		if event.get("name") == EVENT_JUMPED:
			jump_event_count += 1
	assert_eq(jump_event_count, 1, "Event history should record exactly one jump event")

func test_entity_landed_event_publishes_event() -> void:
	var context := await _setup_scene()
	autofree_context(context)
	var manager: M_ECSManager = context["manager"]
	var body: CharacterBody3D = context["body"]
	var components: Dictionary = context["components"]
	var scene: Node = context["scene"]

	var captured_events: Array = []
	var unsubscribe: Callable = EVENT_BUS.subscribe(
		EVENT_LANDED,
		func(event_data: Dictionary) -> void:
			captured_events.append(event_data)
	)

	var jump_component: C_JumpComponent = components[StringName("C_JumpComponent")]
	var floating_component: C_FloatingComponent = components.get(StringName("C_FloatingComponent"), null)

	# Set entity in the air (not supported) with downward velocity
	var now := ECS_UTILS.get_current_time()
	if floating_component != null:
		floating_component.update_support_state(false, now)
	body.velocity = Vector3(0, -5, 0)  # Falling downward

	# Move entity off the ground to ensure it's truly airborne
	body.global_position = Vector3(0, 5, 0)

	# First physics tick (entity is in air)
	manager._physics_process(1.0 / 60.0)
	await get_tree().process_frame

	# Wait to ensure we're outside any cooldown window
	await get_tree().create_timer(0.15).timeout

	# Now mark entity as landing (becomes supported)
	body.global_position = Vector3(0, 0, 0)  # Back on ground
	var landing_time := ECS_UTILS.get_current_time()
	jump_component.record_ground_height(body.global_position.y)
	jump_component.mark_on_floor(landing_time)
	if floating_component != null:
		floating_component.update_support_state(true, landing_time)

	# Second physics tick triggers landing detection
	manager._physics_process(1.0 / 60.0)

	await get_tree().process_frame

	unsubscribe.call()

	assert_eq(captured_events.size(), 1, "Exactly one landing event should be captured")
	if captured_events.size() == 0:
		return  # Early exit if no events captured to avoid crash
	var event_data: Dictionary = captured_events[0]
	assert_eq(event_data.get("name"), EVENT_LANDED)

	var payload: Dictionary = event_data.get("payload")
	assert_not_null(payload)
	assert_eq(payload.get("entity"), body)
	assert_eq(payload.get("jump_component"), jump_component)
	assert_eq(payload.get("floating_component"), floating_component)

	var history := EVENT_BUS.get_event_history()
	assert_true(history.size() >= 1, "Event history should record at least the landing event")

	# Count landing events in history
	var landing_event_count := 0
	for event in history:
		if event.get("name") == EVENT_LANDED:
			landing_event_count += 1
	assert_eq(landing_event_count, 1, "Event history should record exactly one landing event")
