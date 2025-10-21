extends BaseTest

const ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const ALIGN_COMPONENT := preload("res://scripts/ecs/components/c_align_with_surface_component.gd")
const ALIGN_SYSTEM := preload("res://scripts/ecs/systems/s_align_with_surface_system.gd")
const FLOATING_COMPONENT := preload("res://scripts/ecs/components/c_floating_component.gd")
const ECS_UTILS := preload("res://scripts/utils/u_ecs_utils.gd")

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

	var entity := Node.new()
	entity.name = "E_AlignTest"
	manager.add_child(entity)
	autofree(entity)
	await _pump()

	var component: C_AlignWithSurfaceComponent = ALIGN_COMPONENT.new()
	component.settings = RS_AlignSettings.new()
	entity.add_child(component)
	await _pump()

	var body := FakeBody.new()
	component.add_child(body)
	await _pump()

	var visual := FakeVisual.new()
	body.add_child(visual)
	await _pump()

	var floating: C_FloatingComponent = FLOATING_COMPONENT.new()
	floating.settings = RS_FloatingSettings.new()
	component.add_child(floating)
	await _pump()
	floating.character_body_path = floating.get_path_to(body)

	component.character_body_path = component.get_path_to(body)
	component.visual_alignment_path = component.get_path_to(visual)

	var system: S_AlignWithSurfaceSystem = ALIGN_SYSTEM.new()
	manager.add_child(system)
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
	autofree_context(context)
	var component = context["component"] as C_AlignWithSurfaceComponent
	component.settings.align_only_when_supported = false
	component.settings.smoothing_speed = 0.0

	var body = context["body"] as FakeBody
	var visual = context["visual"] as FakeVisual
	var manager := context["manager"] as M_ECSManager

	var slope_normal := Vector3(0.0, 0.8660254, 0.5).normalized()
	body.up_direction = slope_normal
	var basis := Basis.IDENTITY
	basis = basis.rotated(Vector3.UP, 0.3)
	body.global_transform = Transform3D(basis, Vector3.ZERO)
	visual.global_transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)
	var original_scale: Vector3 = Vector3(2.0, 1.5, 0.75)
	visual.scale = original_scale

	manager._physics_process(0.016)

	var visual_up: Vector3 = visual.global_transform.basis.y.normalized()
	assert_almost_eq(visual_up.x, slope_normal.x, 0.01)
	assert_almost_eq(visual_up.y, slope_normal.y, 0.01)
	assert_almost_eq(visual_up.z, slope_normal.z, 0.01)
	assert_almost_eq(visual.scale.x, original_scale.x, 0.001)
	assert_almost_eq(visual.scale.y, original_scale.y, 0.001)
	assert_almost_eq(visual.scale.z, original_scale.z, 0.001)

func test_align_system_respects_support_requirement() -> void:
	var context := await _setup_context()
	autofree_context(context)
	var component = context["component"] as C_AlignWithSurfaceComponent
	component.settings.align_only_when_supported = true
	component.settings.recent_support_tolerance = 0.1
	component.settings.smoothing_speed = 0.0

	var body = context["body"] as FakeBody
	var visual = context["visual"] as FakeVisual
	var floating = context["floating"] as C_FloatingComponent
	var manager := context["manager"] as M_ECSManager

	var initial_basis: Basis = visual.global_transform.basis
	var slope_normal := Vector3(0.2, 0.9, 0.4).normalized()
	body.up_direction = slope_normal

	var now := ECS_UTILS.get_current_time()
	floating.update_support_state(false, now - 1.0)

	manager._physics_process(0.016)

	var after_no_support: Basis = visual.global_transform.basis
	assert_vector3_approx_eq(after_no_support.y, initial_basis.y, 0.001)

	floating.update_support_state(true, now)

	manager._physics_process(0.016)

	var visual_up: Vector3 = visual.global_transform.basis.y.normalized()
	assert_almost_eq(visual_up.x, slope_normal.x, 0.01)
	assert_almost_eq(visual_up.y, slope_normal.y, 0.01)
	assert_almost_eq(visual_up.z, slope_normal.z, 0.01)

func assert_vector3_approx_eq(actual: Vector3, expected: Vector3, tolerance: float) -> void:
	assert_almost_eq(actual.x, expected.x, tolerance)
	assert_almost_eq(actual.y, expected.y, tolerance)
	assert_almost_eq(actual.z, expected.z, tolerance)
