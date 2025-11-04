extends BaseTest

const ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const PARTICLE_SYSTEM := preload("res://scripts/ecs/systems/s_jump_particles_system.gd")
const SOUND_SYSTEM := preload("res://scripts/ecs/systems/s_jump_sound_system.gd")
const EVENT_BUS := preload("res://scripts/ecs/u_ecs_event_bus.gd")

const EVENT_NAME := StringName("entity_jumped")

func before_each() -> void:
	EVENT_BUS.reset()

func _pump() -> void:
	await get_tree().process_frame

func _spawn_manager():
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)
	return manager

func test_jump_particles_system_records_spawn_request() -> void:
	var manager = _spawn_manager()
	await _pump()

	var system := PARTICLE_SYSTEM.new()
	manager.add_child(system)
	autofree(system)
	await _pump()

	var payload := {
		"position": Vector3(1, 2, 3),
		"velocity": Vector3(0, 4, 0),
		"jump_force": 12.0,
	}
	EVENT_BUS.publish(EVENT_NAME, payload)

	assert_eq(system.spawn_requests.size(), 1)
	var request: Dictionary = system.spawn_requests[0]
	assert_eq(request.get("position"), payload["position"])
	assert_eq(request.get("velocity"), payload["velocity"])
	assert_eq(request.get("jump_force"), payload["jump_force"])
	assert_true(request.has("timestamp"))
	assert_true(request["timestamp"] is float)

func test_jump_sound_system_records_play_request() -> void:
	var manager = _spawn_manager()
	await _pump()

	var system := SOUND_SYSTEM.new()
	manager.add_child(system)
	autofree(system)
	await _pump()

	var entity := Node3D.new()
	autofree(entity)
	var payload := {
		"entity": entity,
		"jump_time": 42.0,
		"jump_force": 10.5,
		"supported": true,
	}
	EVENT_BUS.publish(EVENT_NAME, payload)

	assert_eq(system.play_requests.size(), 1)
	var request: Dictionary = system.play_requests[0]
	assert_eq(request.get("entity"), payload["entity"])
	assert_eq(request.get("jump_time"), payload["jump_time"])
	assert_eq(request.get("jump_force"), payload["jump_force"])
	assert_true(request.get("supported"))
