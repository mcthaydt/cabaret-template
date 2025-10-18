extends GutTest

const ECS_MANAGER := preload("res://scripts/ecs/ecs_manager.gd")
const FLOATING_COMPONENT := preload("res://scripts/ecs/components/floating_component.gd")
const FLOATING_SYSTEM := preload("res://scripts/ecs/systems/floating_system.gd")

class FakeBody extends CharacterBody3D:
	func _init() -> void:
		up_direction = Vector3.UP

class FakeRayCast extends RayCast3D:
	var colliding: bool = false
	var fake_collision_point: Vector3 = Vector3.ZERO
	var fake_collision_normal: Vector3 = Vector3.UP

	func is_colliding() -> bool:
		return colliding

	func get_collision_point() -> Vector3:
		return fake_collision_point

	func get_collision_normal() -> Vector3:
		return fake_collision_normal

	func force_raycast_update() -> void:
		pass

func _pump() -> void:
	await get_tree().process_frame

func _wait(seconds: float) -> void:
	var timer: SceneTreeTimer = get_tree().create_timer(seconds)
	await timer.timeout

func _setup_entity() -> Dictionary:
	var manager: ECSManager = ECS_MANAGER.new()
	add_child(manager)
	await _pump()

	var component: FloatingComponent = FLOATING_COMPONENT.new()
	component.settings = FloatingSettings.new()
	component.settings.hover_height = 1.5
	component.settings.hover_frequency = 3.5
	component.settings.damping_ratio = 1.0
	component.settings.align_to_normal = true
	add_child(component)
	await _pump()

	var body: FakeBody = FakeBody.new()
	add_child(body)
	await _pump()

	component.character_body_path = component.get_path_to(body)

	var ray_root: Node3D = Node3D.new()
	component.add_child(ray_root)
	await _pump()

	var ray_a: FakeRayCast = FakeRayCast.new()
	ray_root.add_child(ray_a)
	await _pump()

	var ray_b: FakeRayCast = FakeRayCast.new()
	ray_root.add_child(ray_b)
	await _pump()

	component.raycast_root_path = component.get_path_to(ray_root)


	var system: FloatingSystem = FLOATING_SYSTEM.new()
	add_child(system)
	await _pump()

	return {
		"manager": manager,
		"component": component,
		"body": body,
		"system": system,
		"ray_a": ray_a,
		"ray_b": ray_b,
	}

func test_floating_system_applies_spring_force_and_aligns_to_surface_normal() -> void:
	var context: Dictionary = await _setup_entity()
	var body: FakeBody = context["body"] as FakeBody
	var ray_a: FakeRayCast = context["ray_a"] as FakeRayCast
	var ray_b: FakeRayCast = context["ray_b"] as FakeRayCast
	var system: FloatingSystem = context["system"] as FloatingSystem

	ray_a.position = Vector3.ZERO
	ray_a.colliding = true
	ray_a.fake_collision_point = Vector3(0.0, -1.2, 0.0)
	ray_a.fake_collision_normal = Vector3(0.0, 0.98, 0.2).normalized()

	ray_b.position = Vector3(0.5, 0.0, 0.0)
	ray_b.colliding = true
	ray_b.fake_collision_point = Vector3(0.5, -1.1, 0.0)
	ray_b.fake_collision_normal = Vector3(0.0, 1.0, 0.0)

	body.velocity = Vector3.ZERO

	system._physics_process(0.1)

	assert_gt(body.velocity.y, 0.0)

	var expected_normal: Vector3 = (ray_a.fake_collision_normal + ray_b.fake_collision_normal).normalized()
	assert_almost_eq(body.up_direction.x, expected_normal.x, 0.01)
	assert_almost_eq(body.up_direction.y, expected_normal.y, 0.01)
	assert_almost_eq(body.up_direction.z, expected_normal.z, 0.01)

	await _cleanup(context)

func test_floating_system_does_not_push_up_when_above_hover_height() -> void:
	var context: Dictionary = await _setup_entity()
	var body: FakeBody = context["body"] as FakeBody
	var ray_a: FakeRayCast = context["ray_a"] as FakeRayCast
	var ray_b: FakeRayCast = context["ray_b"] as FakeRayCast
	var system: FloatingSystem = context["system"] as FloatingSystem

	ray_a.colliding = true
	ray_a.fake_collision_point = Vector3(0.0, -1.8, 0.0)

	ray_b.colliding = true
	ray_b.fake_collision_point = Vector3(0.5, -1.7, 0.0)

	body.velocity = Vector3.ZERO

	system._physics_process(0.1)

	assert_lte(body.velocity.y, 0.001)

	await _cleanup(context)

func test_floating_system_updates_support_state_based_on_velocity() -> void:
	var context: Dictionary = await _setup_entity()
	var body: FakeBody = context["body"] as FakeBody
	var component: FloatingComponent = context["component"] as FloatingComponent
	var ray_a: FakeRayCast = context["ray_a"] as FakeRayCast
	var ray_b: FakeRayCast = context["ray_b"] as FakeRayCast
	var system: FloatingSystem = context["system"] as FloatingSystem

	ray_a.colliding = true
	ray_a.fake_collision_point = Vector3(0.0, -1.5, 0.0)

	ray_b.colliding = true
	ray_b.fake_collision_point = Vector3(0.5, -1.4, 0.0)

	body.velocity = Vector3.ZERO

	system._physics_process(0.016)

	assert_true(component.is_supported)

	body.velocity = Vector3(0.0, 6.0, 0.0)

	system._physics_process(0.016)

	assert_false(component.is_supported)

	await _cleanup(context)

func test_floating_system_does_not_cancel_upward_velocity_during_launch() -> void:
	var context: Dictionary = await _setup_entity()
	var body: FakeBody = context["body"] as FakeBody
	var ray_a: FakeRayCast = context["ray_a"] as FakeRayCast
	var ray_b: FakeRayCast = context["ray_b"] as FakeRayCast
	var system: FloatingSystem = context["system"] as FloatingSystem

	ray_a.colliding = true
	ray_a.fake_collision_point = Vector3(0.0, -1.2, 0.0)

	ray_b.colliding = true
	ray_b.fake_collision_point = Vector3(0.5, -1.1, 0.0)

	body.velocity = Vector3(0.0, 8.0, 0.0)

	system._physics_process(0.016)

	assert_gt(body.velocity.y, 7.5)

	await _cleanup(context)

func test_floating_system_applies_fall_gravity_without_hits() -> void:
	var context: Dictionary = await _setup_entity()
	var body: FakeBody = context["body"] as FakeBody
	var component: FloatingComponent = context["component"] as FloatingComponent
	var system: FloatingSystem = context["system"] as FloatingSystem

	component.settings.fall_gravity = 12.0
	component.settings.max_down_speed = 100.0
	body.velocity = Vector3.ZERO

	system._physics_process(0.2)

	assert_lt(body.velocity.y, 0.0)
	assert_almost_eq(body.velocity.y, -component.settings.fall_gravity * 0.2, 0.001)

	await _cleanup(context)

func _cleanup(context: Dictionary) -> void:
	for value in context.values():
		if value is Node:
			value.queue_free()
	await _pump()
