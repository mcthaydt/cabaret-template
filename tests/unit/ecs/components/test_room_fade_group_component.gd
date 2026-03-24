extends BaseTest

const C_ROOM_FADE_GROUP_COMPONENT := preload("res://scripts/ecs/components/c_room_fade_group_component.gd")
const BASE_ECS_COMPONENT := preload("res://scripts/ecs/base_ecs_component.gd")
const RS_ROOM_FADE_SETTINGS := preload("res://scripts/resources/display/vcam/rs_room_fade_settings.gd")

func test_group_tag_export_exists_with_empty_default() -> void:
	var component := C_ROOM_FADE_GROUP_COMPONENT.new()
	autofree(component)
	assert_true(_has_property(component, "group_tag"))
	assert_eq(component.group_tag, StringName(""))

func test_fade_normal_defaults_to_negative_z() -> void:
	var component := C_ROOM_FADE_GROUP_COMPONENT.new()
	autofree(component)
	assert_true(_has_property(component, "fade_normal"))
	assert_eq(component.fade_normal, Vector3(0.0, 0.0, -1.0))

func test_settings_export_accepts_room_fade_settings_resource() -> void:
	var component := C_ROOM_FADE_GROUP_COMPONENT.new()
	autofree(component)
	assert_true(_has_property(component, "settings"))
	component.settings = null
	assert_null(component.settings)
	var settings := RS_ROOM_FADE_SETTINGS.new()
	component.settings = settings
	assert_eq(component.settings, settings)

func test_current_alpha_defaults_to_one() -> void:
	var component := C_ROOM_FADE_GROUP_COMPONENT.new()
	autofree(component)
	assert_almost_eq(component.current_alpha, 1.0, 0.0001)

func test_component_type_constant_is_room_fade_group() -> void:
	assert_eq(C_ROOM_FADE_GROUP_COMPONENT.COMPONENT_TYPE, StringName("RoomFadeGroup"))

func test_collect_mesh_targets_returns_mesh_instances_in_entity_hierarchy() -> void:
	var entity_root := Node3D.new()
	add_child(entity_root)
	autofree(entity_root)

	var component := C_ROOM_FADE_GROUP_COMPONENT.new()
	entity_root.add_child(component)
	autofree(component)

	var direct_mesh := MeshInstance3D.new()
	direct_mesh.mesh = BoxMesh.new()
	entity_root.add_child(direct_mesh)
	autofree(direct_mesh)

	var nested_parent := Node3D.new()
	entity_root.add_child(nested_parent)
	autofree(nested_parent)

	var nested_mesh := MeshInstance3D.new()
	nested_mesh.mesh = BoxMesh.new()
	nested_parent.add_child(nested_mesh)
	autofree(nested_mesh)

	var targets: Array = component.collect_mesh_targets()
	assert_eq(targets.size(), 2)
	assert_true(targets.has(direct_mesh))
	assert_true(targets.has(nested_mesh))

func test_collect_mesh_targets_skips_mesh_instances_without_mesh_resource() -> void:
	var entity_root := Node3D.new()
	add_child(entity_root)
	autofree(entity_root)

	var component := C_ROOM_FADE_GROUP_COMPONENT.new()
	entity_root.add_child(component)
	autofree(component)

	var missing_mesh := MeshInstance3D.new()
	entity_root.add_child(missing_mesh)
	autofree(missing_mesh)

	var valid_mesh := MeshInstance3D.new()
	valid_mesh.mesh = BoxMesh.new()
	entity_root.add_child(valid_mesh)
	autofree(valid_mesh)

	var targets: Array = component.collect_mesh_targets()
	assert_eq(targets.size(), 1)
	assert_true(targets.has(valid_mesh))
	assert_false(targets.has(missing_mesh))

func test_collect_mesh_targets_includes_csg_shapes() -> void:
	var entity_root := Node3D.new()
	add_child(entity_root)
	autofree(entity_root)

	var component := C_ROOM_FADE_GROUP_COMPONENT.new()
	entity_root.add_child(component)
	autofree(component)

	var csg_wall := CSGBox3D.new()
	entity_root.add_child(csg_wall)
	autofree(csg_wall)

	var targets: Array = component.collect_mesh_targets()
	assert_eq(targets.size(), 1)
	assert_true(targets.has(csg_wall))

func test_get_fade_normal_world_transforms_local_normal_by_parent_basis() -> void:
	var entity_root := Node3D.new()
	entity_root.rotate_y(PI * 0.5)
	add_child(entity_root)
	autofree(entity_root)

	var component := C_ROOM_FADE_GROUP_COMPONENT.new()
	entity_root.add_child(component)
	autofree(component)
	component.fade_normal = Vector3(0.0, 0.0, -1.0)

	var expected := (entity_root.global_basis * component.fade_normal).normalized()
	var actual := component.get_fade_normal_world()
	assert_true(actual.distance_to(expected) <= 0.0001)

func test_get_fade_normal_world_returns_normalized_vector() -> void:
	var entity_root := Node3D.new()
	add_child(entity_root)
	autofree(entity_root)

	var component := C_ROOM_FADE_GROUP_COMPONENT.new()
	entity_root.add_child(component)
	autofree(component)
	component.fade_normal = Vector3(0.0, 0.0, -5.0)

	var actual := component.get_fade_normal_world()
	assert_almost_eq(actual.length(), 1.0, 0.0001)

func test_extends_base_ecs_component() -> void:
	var component := C_ROOM_FADE_GROUP_COMPONENT.new()
	autofree(component)
	assert_true(component is BASE_ECS_COMPONENT)

func test_get_snapshot_contains_group_tag_fade_normal_and_current_alpha() -> void:
	var component := C_ROOM_FADE_GROUP_COMPONENT.new()
	autofree(component)
	component.group_tag = StringName("back_wall")
	component.fade_normal = Vector3(0.0, 1.0, 0.0)
	component.current_alpha = 0.35

	var snapshot := component.get_snapshot()
	assert_eq(snapshot.get("group_tag", StringName("")), StringName("back_wall"))
	assert_eq(snapshot.get("fade_normal", Vector3.ZERO), Vector3(0.0, 1.0, 0.0))
	assert_almost_eq(float(snapshot.get("current_alpha", -1.0)), 0.35, 0.0001)

func test_collect_mesh_targets_returns_cached_results_on_second_call() -> void:
	var entity_root := Node3D.new()
	add_child(entity_root)
	autofree(entity_root)

	var component := C_ROOM_FADE_GROUP_COMPONENT.new()
	entity_root.add_child(component)
	autofree(component)

	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	entity_root.add_child(mesh)
	autofree(mesh)

	var first_result: Array = component.collect_mesh_targets()
	var second_result: Array = component.collect_mesh_targets()
	assert_eq(first_result.size(), 1)
	assert_eq(first_result, second_result, "Second call should return cached results.")
	assert_true(component.is_target_cache_valid(), "Cache should be valid after collection.")

func test_invalidate_target_cache_forces_fresh_collection() -> void:
	var entity_root := Node3D.new()
	add_child(entity_root)
	autofree(entity_root)

	var component := C_ROOM_FADE_GROUP_COMPONENT.new()
	entity_root.add_child(component)
	autofree(component)

	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	entity_root.add_child(mesh)
	autofree(mesh)

	var first_result: Array = component.collect_mesh_targets()
	assert_eq(first_result.size(), 1)

	component.invalidate_target_cache()

	var new_mesh := MeshInstance3D.new()
	new_mesh.mesh = BoxMesh.new()
	entity_root.add_child(new_mesh)
	autofree(new_mesh)

	var second_result: Array = component.collect_mesh_targets()
	assert_eq(second_result.size(), 2)
	assert_true(second_result.has(new_mesh))

func test_collect_mesh_targets_cache_is_empty_initially() -> void:
	var component := C_ROOM_FADE_GROUP_COMPONENT.new()
	autofree(component)
	assert_false(component.is_target_cache_valid())

func _has_property(object: Object, property_name: String) -> bool:
	for property_variant in object.get_property_list():
		if not (property_variant is Dictionary):
			continue
		var property := property_variant as Dictionary
		if str(property.get("name", "")) == property_name:
			return true
	return false
