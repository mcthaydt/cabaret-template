extends GutTest

const ECS_MANAGER := preload("res://scripts/ecs/m_ecs_manager.gd")
const FLOATING_COMPONENT := preload("res://scripts/ecs/components/c_floating_component.gd")

func _add_manager() -> M_ECSManager:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	return manager

func _pump() -> void:
	await get_tree().process_frame

func test_floating_component_defaults_and_registration() -> void:
	var manager := _add_manager()
	await _pump()

	var component: C_FloatingComponent = FLOATING_COMPONENT.new()
	component.settings = RS_FloatingSettings.new()
	add_child(component)
	await _pump()

	assert_eq(component.get_component_type(), FLOATING_COMPONENT.COMPONENT_TYPE) 
	assert_almost_eq(component.settings.hover_height, 1.5, 0.001)
	assert_almost_eq(component.settings.hover_frequency, 3.0, 0.001)
	assert_almost_eq(component.settings.damping_ratio, 1.0, 0.001)
	assert_almost_eq(component.settings.max_up_speed, 20.0, 0.001)
	assert_almost_eq(component.settings.max_down_speed, 30.0, 0.001)
	assert_almost_eq(component.settings.fall_gravity, 30.0, 0.001)
	assert_true(component.settings.align_to_normal)
	assert_false(component.is_supported)
	assert_false(component.has_recent_support(Time.get_ticks_msec() / 1000.0, 0.01))

	var components := manager.get_components(FLOATING_COMPONENT.COMPONENT_TYPE)
	assert_eq(components, [component])

	component.queue_free()
	manager.queue_free()
	await _pump()

func test_floating_component_collects_child_rays() -> void:
	var manager := _add_manager()
	await _pump()

	var component: C_FloatingComponent = FLOATING_COMPONENT.new()
	component.settings = RS_FloatingSettings.new()
	add_child(component)
	await _pump()

	var ray_root := Node3D.new()
	component.add_child(ray_root)
	await _pump()

	var ray := RayCast3D.new()
	ray_root.add_child(ray)
	await _pump()

	component.raycast_root_path = component.get_path_to(ray_root)

	var rays := component.get_raycast_nodes()
	assert_eq(rays.size(), 1)
	assert_true(rays[0] == ray)

	component.queue_free()
	manager.queue_free()
	await _pump()

func test_floating_component_tracks_recent_support_state() -> void:
	var component: C_FloatingComponent = FLOATING_COMPONENT.new()
	component.settings = RS_FloatingSettings.new()
	add_child(component)
	await _pump()

	var now := Time.get_ticks_msec() / 1000.0

	component.update_support_state(true, now)
	assert_true(component.is_supported)
	assert_true(component.has_recent_support(now, 0.1))

	component.update_support_state(false, now)
	assert_false(component.is_supported)
	assert_true(component.has_recent_support(now + 0.05, 0.1))
	assert_false(component.has_recent_support(now + 0.2, 0.1))

	component.queue_free()
	await _pump()
