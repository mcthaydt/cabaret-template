extends BaseTest

const ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const LandingIndicatorComponentScript := preload("res://scripts/ecs/components/c_landing_indicator_component.gd")
const LandingIndicatorSystemScript := preload("res://scripts/ecs/systems/s_landing_indicator_system.gd")
const ALIGN_COMPONENT := preload("res://scripts/ecs/components/c_align_with_surface_component.gd")
const ALIGN_SYSTEM := preload("res://scripts/ecs/systems/s_align_with_surface_system.gd")

class FakeSpaceState extends Object:
	var has_hit: bool = false
	var hit_point: Vector3 = Vector3.ZERO
	var hit_normal: Vector3 = Vector3.UP
	var last_from: Vector3 = Vector3.ZERO
	var last_to: Vector3 = Vector3.ZERO
	var last_exclude: Array = []
	var call_count: int = 0

	func set_hit(point: Vector3, normal: Vector3) -> void:
		has_hit = true
		hit_point = point
		if normal.length() > 0.0:
			hit_normal = normal.normalized()
		else:
			hit_normal = Vector3.UP

	func clear_hit() -> void:
		has_hit = false

	func intersect_ray(_query: PhysicsRayQueryParameters3D) -> Dictionary:
		call_count += 1
		# Capture query for diagnostics printed by tests
		if _query != null:
			# PhysicsRayQueryParameters3D exposes 'from', 'to', and 'exclude'
			last_from = _query.from
			last_to = _query.to
			last_exclude = _query.exclude if _query.exclude != null else []
		if has_hit:
			return {
				'position': hit_point,
				'normal': hit_normal,
			}
		return {}

class FakeWorld3D extends Object:
	var direct_space_state: Object

	func _get(property: StringName):
		if property == StringName("direct_space_state"):
			return direct_space_state
		return null

class FakeBody extends CharacterBody3D:
	var _space_state: FakeSpaceState
	var _fake_world: FakeWorld3D

	func _init() -> void:
		up_direction = Vector3.UP
		_space_state = FakeSpaceState.new()
		_fake_world = FakeWorld3D.new()
		_fake_world.direct_space_state = _space_state

	@warning_ignore("native_method_override")
	func get_world_3d():
		return _fake_world

	func set_raycast_hit(point: Vector3, normal: Vector3) -> void:
		_space_state.set_hit(point, normal)

	func clear_raycast_hit() -> void:
		_space_state.clear_hit()

# Override system to ensure ray path uses our fake space state in tests
class TestLandingIndicatorSystem extends S_LandingIndicatorSystem:
	func _extract_space_state(body: CharacterBody3D) -> Object:
		var fb := body as FakeBody
		if fb != null:
			return fb._space_state
		return null

func _pump() -> void:
	await get_tree().process_frame

func _setup_entity(max_distance: float = 10.0) -> Dictionary:
	# Add state store for the landing indicator system (Phase 16)
	var store: M_StateStore = M_StateStore.new()
	add_child(store)
	await _pump()
	
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	await _pump()

	var entity := Node.new()
	entity.name = "E_LandingIndicatorTest"
	manager.add_child(entity)
	autofree(entity)
	await _pump()

	var component: C_LandingIndicatorComponent = LandingIndicatorComponentScript.new()
	component.settings = RS_LandingIndicatorSettings.new()
	component.settings.max_projection_distance = max_distance
	component.settings.ground_plane_height = 0.0
	entity.add_child(component)
	await _pump()

	var body: FakeBody = FakeBody.new()
	entity.add_child(body)
	await _pump()
	body.global_position = Vector3.ZERO
	component.character_body_path = component.get_path_to(body)

	var origin_marker: Node3D = Node3D.new()
	entity.add_child(origin_marker)
	await _pump()
	component.origin_marker_path = component.get_path_to(origin_marker)

	var landing_marker: Node3D = Node3D.new()
	landing_marker.visible = false
	entity.add_child(landing_marker)
	await _pump()
	component.landing_marker_path = component.get_path_to(landing_marker)

	var system: S_LandingIndicatorSystem = TestLandingIndicatorSystem.new()
	manager.add_child(system)
	await _pump()

	return {
		"store": store,
		"manager": manager,
		"entity": entity,
		"component": component,
		"body": body,
		"system": system,
		"origin_marker": origin_marker,
		"landing_marker": landing_marker,
	}

func test_landing_indicator_projects_to_ground_hit() -> void:
	var context: Dictionary = await _setup_entity(5.0)
	autofree_context(context)
	var component: C_LandingIndicatorComponent = context["component"] as C_LandingIndicatorComponent
	var body: FakeBody = context["body"] as FakeBody
	var manager: M_ECSManager = context["manager"] as M_ECSManager

	body.global_position = Vector3(1.5, 2.0, -0.5)
	body.set_raycast_hit(Vector3(1.5, 0.0, -0.5), Vector3.UP)

	manager._physics_process(0.016)
	await _pump()

	assert_true(component.is_indicator_visible())
	assert_true(component.get_landing_point().is_equal_approx(Vector3(1.5, 0.0, -0.5)))
	assert_true(component.get_landing_normal().is_equal_approx(Vector3.UP))

func test_indicator_aligns_negative_z_axis_to_hit_normal_by_default() -> void:
	var context: Dictionary = await _setup_entity(10.0)
	autofree_context(context)
	var component: C_LandingIndicatorComponent = context["component"] as C_LandingIndicatorComponent
	component.settings.align_to_hit_normal = true
	component.settings.normal_axis = 2
	component.settings.normal_axis_positive = false
	var body: FakeBody = context["body"] as FakeBody
	var manager: M_ECSManager = context["manager"] as M_ECSManager
	var marker: Node3D = context["landing_marker"] as Node3D

	body.global_position = Vector3(0.5, 1.0, -0.25)
	var hit_normal: Vector3 = Vector3(0.0, 0.6, 0.8).normalized()
	body.set_raycast_hit(Vector3.ZERO, hit_normal)

	manager._physics_process(0.016)

	var basis := marker.global_transform.basis
	assert_true(basis.z.is_equal_approx(-hit_normal))
	assert_almost_eq(basis.x.dot(hit_normal), 0.0, 0.001)
	assert_almost_eq(basis.y.dot(hit_normal), 0.0, 0.001)

func test_indicator_aligns_positive_y_axis_to_hit_normal_when_configured() -> void:
	var context: Dictionary = await _setup_entity(10.0)
	autofree_context(context)
	var component: C_LandingIndicatorComponent = context["component"] as C_LandingIndicatorComponent
	component.settings.align_to_hit_normal = true
	component.settings.normal_axis = 1
	component.settings.normal_axis_positive = true
	var body: FakeBody = context["body"] as FakeBody
	var manager: M_ECSManager = context["manager"] as M_ECSManager
	var marker: Node3D = context["landing_marker"] as Node3D

	body.global_position = Vector3(-0.5, 2.0, 0.5)
	var hit_normal: Vector3 = Vector3(0.25, 0.9, 0.35).normalized()
	body.set_raycast_hit(Vector3.ZERO, hit_normal)

	manager._physics_process(0.016)

	var basis := marker.global_transform.basis
	assert_true(basis.y.is_equal_approx(hit_normal))
	assert_almost_eq(basis.x.dot(hit_normal), 0.0, 0.001)
	assert_almost_eq(basis.z.dot(hit_normal), 0.0, 0.001)

func test_ground_ray_uses_origin_lift() -> void:
	var context: Dictionary = await _setup_entity(10.0)
	autofree_context(context)
	var component: C_LandingIndicatorComponent = context["component"] as C_LandingIndicatorComponent
	component.settings.ray_origin_lift = 0.3
	var body: FakeBody = context["body"] as FakeBody
	var manager: M_ECSManager = context["manager"] as M_ECSManager

	body.global_position = Vector3(2.0, 3.0, -1.0)
	body.set_raycast_hit(Vector3(2.0, 0.0, -1.0), Vector3.UP)

	manager._physics_process(0.016)

	var expected_from := body.global_position + Vector3.UP * component.settings.ray_origin_lift
	var expected_to := body.global_position + Vector3.DOWN * component.settings.max_projection_distance
	assert_true(body._space_state.last_from.is_equal_approx(expected_from))
	assert_true(body._space_state.last_to.is_equal_approx(expected_to))

func test_minimum_clearance_without_alignment_matches_indicator_height_offset() -> void:
	var context: Dictionary = await _setup_entity(10.0)
	autofree_context(context)
	var component: C_LandingIndicatorComponent = context["component"] as C_LandingIndicatorComponent
	component.settings.align_to_hit_normal = false
	component.settings.indicator_height_offset = 0.05
	var body: FakeBody = context["body"] as FakeBody
	var manager: M_ECSManager = context["manager"] as M_ECSManager
	var marker: Node3D = context["landing_marker"] as Node3D

	body.global_position = Vector3(0.0, 1.0, 0.0)
	var hit_point := Vector3(0.0, 0.0, 0.0)
	var slope_normal := Vector3(0.0, 1.0, 1.0).normalized() # 45 degrees
	body.set_raycast_hit(hit_point, slope_normal)

	manager._physics_process(0.016)

	var displacement: Vector3 = marker.global_position - hit_point
	var marker_up: Vector3 = marker.global_transform.basis.y.normalized()
	var clearance: float = absf(displacement.dot(marker_up))
	var denom: float = clampf(absf(marker_up.dot(slope_normal)), 0.3, 1.0)
	var expected_required: float = component.settings.indicator_height_offset / denom
	var along_normal: float = absf(displacement.dot(slope_normal))
	assert_almost_eq(along_normal, expected_required, 0.001)

func test_landing_indicator_debug_logs_on_slope_raycast_and_plane_fallback() -> void:
	# Setup with generous max distance so both ray and plane can be tested
	var context: Dictionary = await _setup_entity(10.0)
	autofree_context(context)
	var component: C_LandingIndicatorComponent = context["component"] as C_LandingIndicatorComponent
	var body: FakeBody = context["body"] as FakeBody
	var manager: M_ECSManager = context["manager"] as M_ECSManager
	var marker: Node3D = context["landing_marker"] as Node3D

	# Part 1: Simulate a ramp hit with a 45-degree slope facing +Z
	body.global_position = Vector3(0.0, 1.5, 0.0)
	var slope_normal: Vector3 = Vector3(0.0, 1.0, 1.0).normalized()
	var hit_point: Vector3 = Vector3(0.0, 0.0, 0.0)
	body.set_raycast_hit(hit_point, slope_normal)

	manager._physics_process(0.016)

	var visible1 := component.is_indicator_visible()
	var point1 := component.get_landing_point()
	var normal1 := component.get_landing_normal()
	var angle_up_deg1: float = rad_to_deg(acos(clampf(normal1.dot(Vector3.UP), -1.0, 1.0)))
	var up_mismatch_deg1: float = rad_to_deg(normal1.angle_to(body.up_direction))
	var final_pos1 := marker.global_position
	var marker_up1 := marker.global_transform.basis.y.normalized()
	var angle_marker_mismatch1: float = rad_to_deg(marker_up1.angle_to(normal1))
	if body._space_state != null:
		pass

	# The indicator should be visible and positioned using the ray hit
	assert_true(visible1)
	assert_true(point1.is_equal_approx(hit_point))
	assert_true(normal1.is_equal_approx(slope_normal))

	# Part 2: Simulate a ray miss so the plane fallback is used
	body.clear_raycast_hit()
	component.settings.ground_plane_height = -0.25
	body.global_position = Vector3(0.0, 0.5, 0.0)
	manager._physics_process(0.016)

	var visible2 := component.is_indicator_visible()
	var point2 := component.get_landing_point()
	var normal2 := component.get_landing_normal()
	var final_pos2 := marker.global_position
	var dist_to_plane: float = body.global_position.y - component.settings.ground_plane_height
	pass

	assert_true(visible2)
	assert_true(point2.is_equal_approx(Vector3(0.0, component.settings.ground_plane_height, 0.0)))
	assert_true(normal2.is_equal_approx(Vector3.UP))

func test_landing_indicator_logs_when_visual_up_differs_from_hit_normal() -> void:
	# Setup
	var context: Dictionary = await _setup_entity(10.0)
	autofree_context(context)
	var component: C_LandingIndicatorComponent = context["component"] as C_LandingIndicatorComponent
	# Disable alignment to show mismatch in this test
	component.settings.align_to_hit_normal = false
	var body: FakeBody = context["body"] as FakeBody
	var landing_system: S_LandingIndicatorSystem = context["system"] as S_LandingIndicatorSystem
	var marker: Node3D = context["landing_marker"] as Node3D
	var entity: Node = context["entity"] as Node
	var manager: M_ECSManager = context["manager"] as M_ECSManager
	landing_system.execution_priority = 90

	# Create a visual and align component/system that will rotate the visual regardless of support
	var align_component: C_AlignWithSurfaceComponent = ALIGN_COMPONENT.new()
	align_component.settings = RS_AlignSettings.new()
	align_component.settings.align_only_when_supported = false
	align_component.settings.smoothing_speed = 0.0
	entity.add_child(align_component)
	# Ensure this extra node is cleaned up after the test
	autofree(align_component)
	await _pump()

	var visual := Node3D.new()
	body.add_child(visual)
	# Visual is parented under body, but register anyway for explicit cleanup
	autofree(visual)
	# Reparent marker under visual so it inherits orientation
	if marker.get_parent() != null:
		marker.get_parent().remove_child(marker)
	visual.add_child(marker)
	await _pump()
	component.landing_marker_path = component.get_path_to(marker)

	align_component.character_body_path = align_component.get_path_to(body)
	align_component.visual_alignment_path = align_component.get_path_to(visual)

	var align_system: S_AlignWithSurfaceSystem = ALIGN_SYSTEM.new()
	align_system.execution_priority = 80
	manager.add_child(align_system)
	# Ensure this extra system node is cleaned up after the test
	autofree(align_system)
	await _pump()

	# Configure a hit normal that differs from the body.up_direction
	body.global_position = Vector3(0.0, 1.25, 0.0)
	var hit_point: Vector3 = Vector3(0.0, 0.0, 0.0)
	var hit_normal: Vector3 = Vector3(0.0, 1.0, 0.5).normalized() # ~26.565° tilt in +Z
	var align_up: Vector3 = Vector3(0.0, 1.0, 0.2).normalized()  # shallower tilt to force mismatch
	body.set_raycast_hit(hit_point, hit_normal)
	body.up_direction = align_up

	# First align the visual, then compute landing indicator
	manager._physics_process(0.016)

	var visible := component.is_indicator_visible()
	var point := component.get_landing_point()
	var normal := component.get_landing_normal()
	var marker_up := marker.global_transform.basis.y.normalized()
	var angle_mismatch_deg: float = rad_to_deg(marker_up.angle_to(normal))
	var height_offset: float = component.settings.indicator_height_offset
	var separation_along_marker_up: float = height_offset * clampf(marker_up.dot(normal), -1.0, 1.0)
	pass

	# Sanity checks (do not constrain the exact numeric values beyond general expectations)
	assert_true(visible)
	assert_true(point.is_equal_approx(hit_point))
	# Expect a meaningful mismatch
	assert_true(angle_mismatch_deg > 0.0)

func test_landing_indicator_hides_when_no_projection_within_range() -> void:
	var context: Dictionary = await _setup_entity(0.5)
	autofree_context(context)
	var component: C_LandingIndicatorComponent = context["component"] as C_LandingIndicatorComponent
	var body: FakeBody = context["body"] as FakeBody
	var manager: M_ECSManager = context["manager"] as M_ECSManager

	body.global_position = Vector3(0.0, 2.0, 0.0)
	body.clear_raycast_hit()
	component.settings.ground_plane_height = 0.0

	manager._physics_process(0.016)

	assert_false(component.is_indicator_visible())
	assert_true(component.get_landing_point().is_equal_approx(Vector3.ZERO))

func test_landing_indicator_projects_to_ground_plane_when_no_hit() -> void:
	var context: Dictionary = await _setup_entity(5.0)
	autofree_context(context)
	var component: C_LandingIndicatorComponent = context["component"] as C_LandingIndicatorComponent
	var body: FakeBody = context["body"] as FakeBody
	var manager: M_ECSManager = context["manager"] as M_ECSManager

	body.global_position = Vector3(0.0, 1.0, 0.0)
	body.clear_raycast_hit()
	component.settings.ground_plane_height = -1.0

	manager._physics_process(0.016)

	assert_true(component.is_indicator_visible())
	assert_true(component.get_landing_point().is_equal_approx(Vector3(0.0, -1.0, 0.0)))
	assert_true(component.get_landing_normal().is_equal_approx(Vector3.UP))
