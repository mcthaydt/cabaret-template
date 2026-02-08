extends BaseTest

const ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const ALIGN_COMPONENT := preload("res://scripts/ecs/components/c_align_with_surface_component.gd")
func _pump() -> void:
	await get_tree().process_frame

func _add_manager() -> M_ECSManager:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await _pump()
	return manager

func test_align_with_surface_component_defaults_and_registration() -> void:
	var manager := await _add_manager()

	var entity := Node.new()
	entity.name = "E_TestEntity"
	add_child(entity)
	autofree(entity)

	var component: C_AlignWithSurfaceComponent = ALIGN_COMPONENT.new()
	component.settings = RS_AlignSettings.new()
	entity.add_child(component)
	autofree(component)
	await _pump()

	assert_eq(component.get_component_type(), ALIGN_COMPONENT.COMPONENT_TYPE)
	assert_almost_eq(component.settings.smoothing_speed, 12.0, 0.001)
	assert_true(component.settings.align_only_when_supported)
	assert_almost_eq(component.settings.recent_support_tolerance, 0.2, 0.001)
	assert_eq(component.settings.fallback_up_direction, Vector3.UP)

	var components := manager.get_components(ALIGN_COMPONENT.COMPONENT_TYPE)
	assert_true(components.has(component))

	var has_floating_property := false
	for property in component.get_property_list():
		if property.name == "floating_component_path":
			has_floating_property = true
			break
	assert_false(has_floating_property, "C_AlignWithSurfaceComponent should not expose floating_component_path.")

func test_align_with_surface_component_fetches_assigned_nodes() -> void:
	await _add_manager()

	var entity := Node.new()
	entity.name = "E_TestEntity"
	add_child(entity)
	autofree(entity)

	var component: C_AlignWithSurfaceComponent = ALIGN_COMPONENT.new()
	component.settings = RS_AlignSettings.new()
	entity.add_child(component)
	autofree(component)
	await _pump()

	var body := CharacterBody3D.new()
	component.add_child(body)
	await _pump()

	var mesh := Node3D.new()
	body.add_child(mesh)
	await _pump()

	component.character_body_path = component.get_path_to(body)
	component.visual_alignment_path = component.get_path_to(mesh)

	assert_true(component.get_character_body() == body)
	assert_true(component.get_visual_node() == mesh)
