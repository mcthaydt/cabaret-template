extends GutTest

const ECS_MANAGER := preload("res://scripts/ecs/ecs_manager.gd")
const ALIGN_COMPONENT := preload("res://scripts/ecs/components/align_with_surface_component.gd")
const ALIGN_SYSTEM := preload("res://scripts/ecs/systems/align_with_surface_system.gd")
const FLOATING_COMPONENT := preload("res://scripts/ecs/components/floating_component.gd")

class FakeBody extends CharacterBody3D:
	func _init() -> void:
		up_direction = Vector3.UP

class FakeVisual extends Node3D:
	pass

func _pump() -> void:
	await get_tree().process_frame

func _setup_context() -> Dictionary:
	var manager := ECS_MANAGER.new()
	add_child(manager)
	await _pump()

	var component := ALIGN_COMPONENT.new()
	component.settings = AlignSettings.new()
	add_child(component)
	await _pump()

	var body := FakeBody.new()
	component.add_child(body)
	await _pump()

	var visual := FakeVisual.new()
	body.add_child(visual)
	await _pump()

	var floating := FLOATING_COMPONENT.new()
	floating.settings = FloatingSettings.new()
	component.add_child(floating)
	await _pump()

	component.character_body_path = component.get_path_to(body)
	component.visual_alignment_path = component.get_path_to(visual)
	component.floating_component_path = component.get_path_to(floating)

	var system := ALIGN_SYSTEM.new()
	add_child(system)
	await _pump()

	return {
		"manager": manager,
		"component": component,
		"body": body,
		"visual": visual,
		"floating": floating,
		"system": system,
	}

func test_align_system_matches_visual_up_to_body_up_direction() -> void:
	var context := await _setup_context()
	var component = context["component"] as AlignWithSurfaceComponent
	component.settings.align_only_when_supported = false
	component.settings.smoothing_speed = 0.0

	var body = context["body"] as FakeBody
	var visual = context["visual"] as FakeVisual
	var system = context["system"] as AlignWithSurfaceSystem

	var slope_normal := Vector3(0.0, 0.8660254, 0.5).normalized()
	body.up_direction = slope_normal
	var basis := Basis.IDENTITY
	basis = basis.rotated(Vector3.UP, 0.3)
	body.global_transform = Transform3D(basis, Vector3.ZERO)
	visual.global_transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)
	var original_scale: Vector3 = Vector3(2.0, 1.5, 0.75)
	visual.scale = original_scale

	system._physics_process(0.016)

	var visual_up: Vector3 = visual.global_transform.basis.y.normalized()
	assert_almost_eq(visual_up.x, slope_normal.x, 0.01)
	assert_almost_eq(visual_up.y, slope_normal.y, 0.01)
	assert_almost_eq(visual_up.z, slope_normal.z, 0.01)
	assert_almost_eq(visual.scale.x, original_scale.x, 0.001)
	assert_almost_eq(visual.scale.y, original_scale.y, 0.001)
	assert_almost_eq(visual.scale.z, original_scale.z, 0.001)

	await _cleanup(context)

func test_align_system_respects_support_requirement() -> void:
	var context := await _setup_context()
	var component = context["component"] as AlignWithSurfaceComponent
	component.settings.align_only_when_supported = true
	component.settings.recent_support_tolerance = 0.1
	component.settings.smoothing_speed = 0.0

	var body = context["body"] as FakeBody
	var visual = context["visual"] as FakeVisual
	var floating = context["floating"] as FloatingComponent
	var system = context["system"] as AlignWithSurfaceSystem

	var initial_basis: Basis = visual.global_transform.basis
	var slope_normal := Vector3(0.2, 0.9, 0.4).normalized()
	body.up_direction = slope_normal

	var now := Time.get_ticks_msec() / 1000.0
	floating.update_support_state(false, now - 1.0)

	system._physics_process(0.016)

	var after_no_support: Basis = visual.global_transform.basis
	assert_vector3_approx_eq(after_no_support.y, initial_basis.y, 0.001)

	floating.update_support_state(true, now)

	system._physics_process(0.016)

	var visual_up: Vector3 = visual.global_transform.basis.y.normalized()
	assert_almost_eq(visual_up.x, slope_normal.x, 0.01)
	assert_almost_eq(visual_up.y, slope_normal.y, 0.01)
	assert_almost_eq(visual_up.z, slope_normal.z, 0.01)

	await _cleanup(context)

func _cleanup(context: Dictionary) -> void:
	for node in context.values():
		if node is Node:
			node.queue_free()
	await _pump()

func assert_vector3_approx_eq(actual: Vector3, expected: Vector3, tolerance: float) -> void:
	assert_almost_eq(actual.x, expected.x, tolerance)
	assert_almost_eq(actual.y, expected.y, tolerance)
	assert_almost_eq(actual.z, expected.z, tolerance)
