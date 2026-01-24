extends GutTest

## Unit tests for S_SpawnParticlesSystem (Phase 12.4)

const M_ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const S_SPAWN_PARTICLES := preload("res://scripts/ecs/systems/s_spawn_particles_system.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/ecs/u_ecs_event_bus.gd")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_VFX_INITIAL_STATE := preload("res://scripts/resources/state/rs_vfx_initial_state.gd")
const U_VFX_ACTIONS := preload("res://scripts/state/actions/u_vfx_actions.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

var _manager: M_ECSManager
var _system: S_SpawnParticlesSystem
var _root_scene: Node3D
var _store: M_StateStore

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	U_ECS_EVENT_BUS.reset()

	# Create a current scene so particle effects container can be created
	var tree := get_tree()
	_root_scene = Node3D.new()
	tree.root.add_child(_root_scene)
	await tree.process_frame
	if tree.has_method("set_current_scene"):
		tree.set_current_scene(_root_scene)
	else:
		tree.current_scene = _root_scene

	_manager = M_ECS_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	_store = _create_store()
	add_child_autofree(_store)
	await get_tree().process_frame

	_system = S_SpawnParticlesSystem.new()
	_manager.add_child(_system)
	autofree(_system)
	await get_tree().process_frame

func after_each() -> void:
	if is_instance_valid(_root_scene):
		_root_scene.queue_free()
	await get_tree().process_frame
	_manager = null
	_system = null
	_root_scene = null
	_store = null
	U_ECS_EVENT_BUS.reset()
	U_SERVICE_LOCATOR.clear()

func _create_store() -> M_StateStore:
	var store := M_STATE_STORE.new()
	store.settings = RS_STATE_STORE_SETTINGS.new()
	store.settings.enable_persistence = false
	store.settings.enable_debug_logging = false
	store.settings.enable_debug_overlay = false
	store.vfx_initial_state = RS_VFX_INITIAL_STATE.new()
	return store

func test_creates_particles_on_player_spawn_event() -> void:
	# Publish player_spawned and tick the system
	U_ECS_EVENT_BUS.publish(StringName("player_spawned"), {"position": Vector3(3, 4, 5), "spawn_point_id": StringName("sp_test")})
	await wait_physics_frames(1)

	# Effects container should exist under current_scene
	var container: Node3D = _root_scene.get_node_or_null("EffectsContainer") as Node3D
	assert_not_null(container, "Effects container should be created")

	# At least one GPUParticles3D should be spawned under container
	var has_particles := false
	for child in container.get_children():
		if child is GPUParticles3D:
			has_particles = true
			break
	assert_true(has_particles, "Should spawn GPUParticles3D when event received")

func test_disabled_system_clears_requests_and_spawns_nothing() -> void:
	# Disable system
	_system.enabled = false

	U_ECS_EVENT_BUS.publish(StringName("player_spawned"), {"position": Vector3.ZERO})
	await wait_physics_frames(1)

	# Ensure no effects container was created under current test scene
	var local_container := _root_scene.get_node_or_null("EffectsContainer")
	assert_null(local_container, "No local effects container should be created when disabled")

func test_global_particles_disabled_prevents_spawning() -> void:
	_store.dispatch(U_VFX_ACTIONS.set_particles_enabled(false))

	U_ECS_EVENT_BUS.publish(StringName("player_spawned"), {"position": Vector3(3, 4, 5), "spawn_point_id": StringName("sp_test")})
	await wait_physics_frames(1)

	var local_container := _root_scene.get_node_or_null("EffectsContainer")
	assert_null(local_container, "No local effects container should be created when particles are disabled")
