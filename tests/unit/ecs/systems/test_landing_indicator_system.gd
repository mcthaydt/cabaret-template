extends BaseTest

const ECS_MANAGER := preload("res://scripts/ecs/m_ecs_manager.gd")
const LandingIndicatorComponentScript := preload("res://scripts/ecs/components/c_landing_indicator_component.gd")
const LandingIndicatorSystemScript := preload("res://scripts/ecs/systems/s_landing_indicator_system.gd")

class FakeSpaceState extends Object:
	var has_hit: bool = false
	var hit_point: Vector3 = Vector3.ZERO
	var hit_normal: Vector3 = Vector3.UP

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

func _pump() -> void:
	await get_tree().process_frame

func _setup_entity(max_distance: float = 10.0) -> Dictionary:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	await _pump()

	var component: C_LandingIndicatorComponent = LandingIndicatorComponentScript.new()
	component.settings = RS_LandingIndicatorSettings.new()
	component.settings.max_projection_distance = max_distance
	component.settings.ground_plane_height = 0.0
	add_child(component)
	await _pump()

	var body: FakeBody = FakeBody.new()
	add_child(body)
	await _pump()
	body.global_position = Vector3.ZERO
	component.character_body_path = component.get_path_to(body)

	var origin_marker: Node3D = Node3D.new()
	add_child(origin_marker)
	await _pump()
	component.origin_marker_path = component.get_path_to(origin_marker)

	var landing_marker: Node3D = Node3D.new()
	landing_marker.visible = false
	add_child(landing_marker)
	await _pump()
	component.landing_marker_path = component.get_path_to(landing_marker)

	var system: S_LandingIndicatorSystem = LandingIndicatorSystemScript.new()
	add_child(system)
	await _pump()

	return {
		"manager": manager,
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
	var system: S_LandingIndicatorSystem = context["system"] as S_LandingIndicatorSystem

	body.global_position = Vector3(1.5, 2.0, -0.5)
	body.set_raycast_hit(Vector3(1.5, 0.0, -0.5), Vector3.UP)

	system._physics_process(0.016)

	assert_true(component.is_indicator_visible())
	assert_true(component.get_landing_point().is_equal_approx(Vector3(1.5, 0.0, -0.5)))
	assert_true(component.get_landing_normal().is_equal_approx(Vector3.UP))

func test_landing_indicator_hides_when_no_projection_within_range() -> void:
	var context: Dictionary = await _setup_entity(0.5)
	autofree_context(context)
	var component: C_LandingIndicatorComponent = context["component"] as C_LandingIndicatorComponent
	var body: FakeBody = context["body"] as FakeBody
	var system: S_LandingIndicatorSystem = context["system"] as S_LandingIndicatorSystem

	body.global_position = Vector3(0.0, 2.0, 0.0)
	body.clear_raycast_hit()
	component.settings.ground_plane_height = 0.0

	system._physics_process(0.016)

	assert_false(component.is_indicator_visible())
	assert_true(component.get_landing_point().is_equal_approx(Vector3.ZERO))

func test_landing_indicator_projects_to_ground_plane_when_no_hit() -> void:
	var context: Dictionary = await _setup_entity(5.0)
	autofree_context(context)
	var component: C_LandingIndicatorComponent = context["component"] as C_LandingIndicatorComponent
	var body: FakeBody = context["body"] as FakeBody
	var system: S_LandingIndicatorSystem = context["system"] as S_LandingIndicatorSystem

	body.global_position = Vector3(0.0, 1.0, 0.0)
	body.clear_raycast_hit()
	component.settings.ground_plane_height = -1.0

	system._physics_process(0.016)

	assert_true(component.is_indicator_visible())
	assert_true(component.get_landing_point().is_equal_approx(Vector3(0.0, -1.0, 0.0)))
	assert_true(component.get_landing_normal().is_equal_approx(Vector3.UP))
