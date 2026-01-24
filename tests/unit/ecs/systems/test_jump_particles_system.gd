extends BaseTest

const ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const PARTICLE_SYSTEM := preload("res://scripts/ecs/systems/s_jump_particles_system.gd")
const SETTINGS := preload("res://scripts/resources/ecs/rs_jump_particles_settings.gd")
const EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")

const EVENT_NAME := StringName("entity_jumped")

func before_each() -> void:
	EVENT_BUS.reset()

func _pump() -> void:
	await get_tree().process_frame

func _spawn_manager() -> M_ECSManager:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)
	return manager

func _create_system_with_settings(enabled: bool = true) -> Dictionary:
	var manager := _spawn_manager()
	await _pump()

	var system := PARTICLE_SYSTEM.new()
	var settings := SETTINGS.new()
	settings.enabled = enabled
	system.settings = settings
	manager.add_child(system)
	autofree(system)
	await _pump()

	return {
		"manager": manager,
		"system": system,
		"settings": settings,
	}

# Settings and Initialization Tests

func test_system_subscribes_to_entity_jumped_event_on_ready() -> void:
	var context := await _create_system_with_settings()
	autofree_context(context)
	var system: S_JumpParticlesSystem = context["system"]

	# System should have subscribed - test by publishing event
	var payload := {"position": Vector3.ZERO}
	EVENT_BUS.publish(EVENT_NAME, payload)

	assert_eq(system.spawn_requests.size(), 1, "System should queue spawn request after event")

func test_system_clears_spawn_requests_when_disabled() -> void:
	var context := await _create_system_with_settings(false)
	autofree_context(context)
	var system: S_JumpParticlesSystem = context["system"]

	# Manually add a spawn request
	system.spawn_requests.append({"position": Vector3.ZERO})

	# Process tick should clear requests when disabled
	system.process_tick(0.016)

	assert_eq(system.spawn_requests.size(), 0, "Disabled system should clear spawn requests")

func test_system_clears_spawn_requests_when_settings_null() -> void:
	var manager := _spawn_manager()
	await _pump()

	var system := PARTICLE_SYSTEM.new()
	system.settings = null
	manager.add_child(system)
	autofree(system)
	await _pump()

	# Manually add a spawn request
	system.spawn_requests.append({"position": Vector3.ZERO})

	# Process tick should clear requests when settings null
	system.process_tick(0.016)

	assert_eq(system.spawn_requests.size(), 0, "System with null settings should clear spawn requests")

# Event Subscription Tests

func test_system_unsubscribes_on_exit_tree() -> void:
	var context := await _create_system_with_settings()
	var system: S_JumpParticlesSystem = context["system"]

	# Remove system from tree
	system.get_parent().remove_child(system)
	autofree_context(context)
	autofree(system)

	# Publish event - should not be captured
	var payload := {"position": Vector3.ZERO}
	EVENT_BUS.publish(EVENT_NAME, payload)

	assert_eq(system.spawn_requests.size(), 0, "Removed system should not receive events")

func test_spawn_request_contains_correct_data() -> void:
	var context := await _create_system_with_settings()
	autofree_context(context)
	var system: S_JumpParticlesSystem = context["system"]

	var payload := {
		"position": Vector3(1, 2, 3),
		"velocity": Vector3(4, 5, 6),
		"jump_force": 15.0,
	}
	EVENT_BUS.publish(EVENT_NAME, payload)

	assert_eq(system.spawn_requests.size(), 1)
	var request: Dictionary = system.spawn_requests[0]
	assert_eq(request.get("position"), Vector3(1, 2, 3))
	assert_eq(request.get("velocity"), Vector3(4, 5, 6))
	assert_eq(request.get("jump_force"), 15.0)
	assert_true(request.has("timestamp"), "Request should have timestamp")

# Particle Spawning Tests
# Note: Full particle spawning requires current_scene, tested in integration tests
# Unit tests focus on request processing logic

func test_process_tick_clears_spawn_requests_after_processing() -> void:
	var context := await _create_system_with_settings()
	autofree_context(context)
	var system: S_JumpParticlesSystem = context["system"]

	var payload := {"position": Vector3(0, 5, 0)}
	EVENT_BUS.publish(EVENT_NAME, payload)

	assert_eq(system.spawn_requests.size(), 1, "Request should be queued")

	# Process tick should clear requests (even if spawning fails in test env)
	system.process_tick(0.016)

	assert_eq(system.spawn_requests.size(), 0, "Requests should be cleared after processing")

# Spawn Offset Tests

func test_default_spawn_offset_is_down() -> void:
	var settings := SETTINGS.new()
	assert_eq(settings.spawn_offset, Vector3.DOWN, "Default spawn_offset should be Vector3.DOWN")

# Effects Container Tests
# Note: Container creation requires current_scene, tested in integration tests

# Multiple Requests Tests

func test_multiple_spawn_requests_all_queued() -> void:
	var context := await _create_system_with_settings()
	autofree_context(context)
	var system: S_JumpParticlesSystem = context["system"]

	# Queue multiple requests
	EVENT_BUS.publish(EVENT_NAME, {"position": Vector3(0, 0, 0)})
	EVENT_BUS.publish(EVENT_NAME, {"position": Vector3(5, 0, 0)})
	EVENT_BUS.publish(EVENT_NAME, {"position": Vector3(10, 0, 0)})

	assert_eq(system.spawn_requests.size(), 3, "All requests should be queued")

func test_multiple_spawn_requests_all_cleared_after_processing() -> void:
	var context := await _create_system_with_settings()
	autofree_context(context)
	var system: S_JumpParticlesSystem = context["system"]

	# Queue multiple requests
	EVENT_BUS.publish(EVENT_NAME, {"position": Vector3(0, 0, 0)})
	EVENT_BUS.publish(EVENT_NAME, {"position": Vector3(5, 0, 0)})
	EVENT_BUS.publish(EVENT_NAME, {"position": Vector3(10, 0, 0)})

	assert_eq(system.spawn_requests.size(), 3, "All requests should be queued")

	system.process_tick(0.016)

	assert_eq(system.spawn_requests.size(), 0, "All requests should be cleared")

# Settings Validation Tests

func test_settings_emission_count_configurable() -> void:
	var settings := SETTINGS.new()
	settings.emission_count = 50
	assert_eq(settings.emission_count, 50, "Emission count should be configurable")

func test_settings_particle_lifetime_configurable() -> void:
	var settings := SETTINGS.new()
	settings.particle_lifetime = 2.0
	assert_eq(settings.particle_lifetime, 2.0, "Particle lifetime should be configurable")

func test_settings_particle_scale_configurable() -> void:
	var settings := SETTINGS.new()
	settings.particle_scale = 0.8
	assert_eq(settings.particle_scale, 0.8, "Particle scale should be configurable")

func test_settings_spread_angle_configurable() -> void:
	var settings := SETTINGS.new()
	settings.spread_angle = 120.0
	assert_eq(settings.spread_angle, 120.0, "Spread angle should be configurable")

func test_settings_initial_velocity_configurable() -> void:
	var settings := SETTINGS.new()
	settings.initial_velocity = 7.5
	assert_eq(settings.initial_velocity, 7.5, "Initial velocity should be configurable")
