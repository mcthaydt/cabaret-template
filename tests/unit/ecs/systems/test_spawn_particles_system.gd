extends GutTest

## Unit tests for S_SpawnParticlesSystem (Phase 12.4)

const M_ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const S_SPAWN_PARTICLES := preload("res://scripts/ecs/systems/s_spawn_particles_system.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/ecs/u_ecs_event_bus.gd")

var _manager: M_ECSManager
var _system: S_SpawnParticlesSystem
var _root_scene: Node3D

func before_each() -> void:
    U_ECS_EVENT_BUS.reset()

    # Create a current scene so particle effects container can be created
    _root_scene = Node3D.new()
    add_child_autofree(_root_scene)
    get_tree().current_scene = _root_scene

    _manager = M_ECS_MANAGER.new()
    add_child_autofree(_manager)
    await get_tree().process_frame

    _system = S_SpawnParticlesSystem.new()
    _manager.add_child(_system)
    autofree(_system)
    await get_tree().process_frame

func after_each() -> void:
    _manager = null
    _system = null
    _root_scene = null
    U_ECS_EVENT_BUS.reset()

func test_creates_particles_on_player_spawn_event() -> void:
    # Publish player_spawned and tick the system
    U_ECS_EVENT_BUS.publish(StringName("player_spawned"), {"position": Vector3(3, 4, 5), "spawn_point_id": StringName("sp_test")})
    await wait_physics_frames(1)

    # Effects container should exist under current_scene
    var containers := get_tree().get_nodes_in_group("effects_container")
    assert_false(containers.is_empty(), "Effects container should be created")
    var container: Node3D = containers[0] as Node3D

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
