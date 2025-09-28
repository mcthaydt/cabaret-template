extends GutTest

const ECS_MANAGER := preload("res://scripts/ecs/ecs_manager.gd")
const ALIGN_COMPONENT := preload("res://scripts/ecs/components/align_with_surface_component.gd")
const FLOATING_COMPONENT := preload("res://scripts/ecs/components/floating_component.gd")


func _pump() -> void:
	await get_tree().process_frame

func _add_manager() -> ECS_MANAGER:
	var manager := ECS_MANAGER.new()
	add_child(manager)
	await _pump()
	return manager

func test_align_with_surface_component_defaults_and_registration() -> void:
	var manager := await _add_manager()

	var component := ALIGN_COMPONENT.new()
	add_child(component)
	await _pump()

	assert_eq(component.get_component_type(), ALIGN_COMPONENT.COMPONENT_TYPE)
	assert_almost_eq(component.smoothing_speed, 12.0, 0.001)
	assert_true(component.align_only_when_supported)
	assert_almost_eq(component.recent_support_tolerance, 0.2, 0.001)
	assert_eq(component.fallback_up_direction, Vector3.UP)

	var components := manager.get_components(ALIGN_COMPONENT.COMPONENT_TYPE)
	assert_true(components.has(component))

	component.queue_free()
	manager.queue_free()
	await _pump()

func test_align_with_surface_component_fetches_assigned_nodes() -> void:
	await _add_manager()

	var component := ALIGN_COMPONENT.new()
	add_child(component)
	await _pump()

	var body := CharacterBody3D.new()
	component.add_child(body)
	await _pump()

	var mesh := Node3D.new()
	body.add_child(mesh)
	await _pump()

	var floating := FLOATING_COMPONENT.new()
	component.add_child(floating)
	await _pump()

	component.character_body_path = component.get_path_to(body)
	component.visual_alignment_path = component.get_path_to(mesh)
	component.floating_component_path = component.get_path_to(floating)

	assert_true(component.get_character_body() == body)
	assert_true(component.get_visual_node() == mesh)
	assert_true(component.get_floating_component() == floating)

	component.queue_free()
	await _pump()

func test_align_with_surface_component_delegates_support_check() -> void:
	var component := ALIGN_COMPONENT.new()
	add_child(component)
	await _pump()

	var floating := FLOATING_COMPONENT.new()
	component.add_child(floating)
	await _pump()

	component.floating_component_path = component.get_path_to(floating)

	var now := Time.get_ticks_msec() / 1000.0
	floating.update_support_state(false, now)

	assert_false(component.has_recent_support(now, 0.1))

	floating.update_support_state(true, now)
	assert_true(component.has_recent_support(now, 0.1))

	component.queue_free()
	await _pump()
