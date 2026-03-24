extends BaseTest

const C_REGION_VISIBILITY_COMPONENT := preload(
	"res://scripts/ecs/components/c_region_visibility_component.gd"
)
const BASE_ECS_COMPONENT := preload("res://scripts/ecs/base_ecs_component.gd")
const RS_REGION_VISIBILITY_SETTINGS := preload(
	"res://scripts/resources/display/vcam/rs_region_visibility_settings.gd"
)

func test_extends_base_ecs_component() -> void:
	var component := C_REGION_VISIBILITY_COMPONENT.new()
	autofree(component)
	assert_true(component is BASE_ECS_COMPONENT)

func test_component_type_is_region_visibility() -> void:
	assert_eq(
		C_REGION_VISIBILITY_COMPONENT.COMPONENT_TYPE,
		StringName("RegionVisibility")
	)

func test_region_tag_defaults_to_empty() -> void:
	var component := C_REGION_VISIBILITY_COMPONENT.new()
	autofree(component)
	assert_eq(component.region_tag, StringName(""))

func test_current_alpha_defaults_to_one() -> void:
	var component := C_REGION_VISIBILITY_COMPONENT.new()
	autofree(component)
	assert_almost_eq(component.current_alpha, 1.0, 0.0001)

func test_is_active_region_defaults_to_false() -> void:
	var component := C_REGION_VISIBILITY_COMPONENT.new()
	autofree(component)
	assert_false(component.is_active_region)

func test_settings_accepts_region_visibility_settings_resource() -> void:
	var component := C_REGION_VISIBILITY_COMPONENT.new()
	autofree(component)
	component.settings = null
	assert_null(component.settings)
	var settings := RS_REGION_VISIBILITY_SETTINGS.new()
	component.settings = settings
	assert_eq(component.settings, settings)

func test_collect_mesh_targets_finds_mesh_instances_in_subtree() -> void:
	var entity_root := Node3D.new()
	add_child(entity_root)
	autofree(entity_root)

	var component := C_REGION_VISIBILITY_COMPONENT.new()
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

func test_collect_mesh_targets_finds_csg_shapes() -> void:
	var entity_root := Node3D.new()
	add_child(entity_root)
	autofree(entity_root)

	var component := C_REGION_VISIBILITY_COMPONENT.new()
	entity_root.add_child(component)
	autofree(component)

	var csg_box := CSGBox3D.new()
	entity_root.add_child(csg_box)
	autofree(csg_box)

	var targets: Array = component.collect_mesh_targets()
	assert_eq(targets.size(), 1)
	assert_true(targets.has(csg_box))

func test_collect_mesh_targets_caches_results() -> void:
	var entity_root := Node3D.new()
	add_child(entity_root)
	autofree(entity_root)

	var component := C_REGION_VISIBILITY_COMPONENT.new()
	entity_root.add_child(component)
	autofree(component)

	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	entity_root.add_child(mesh)
	autofree(mesh)

	var first := component.collect_mesh_targets()
	var second := component.collect_mesh_targets()
	assert_eq(first, second, "Second call should return cached result.")
	assert_true(component.is_target_cache_valid())

func test_invalidate_target_cache_forces_recollection() -> void:
	var entity_root := Node3D.new()
	add_child(entity_root)
	autofree(entity_root)

	var component := C_REGION_VISIBILITY_COMPONENT.new()
	entity_root.add_child(component)
	autofree(component)

	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	entity_root.add_child(mesh)
	autofree(mesh)

	component.collect_mesh_targets()
	component.invalidate_target_cache()
	assert_false(component.is_target_cache_valid())

	var new_mesh := MeshInstance3D.new()
	new_mesh.mesh = BoxMesh.new()
	entity_root.add_child(new_mesh)
	autofree(new_mesh)

	var targets := component.collect_mesh_targets()
	assert_eq(targets.size(), 2)
	assert_true(targets.has(new_mesh))

func test_get_region_aabb_encompasses_all_targets() -> void:
	var entity_root := Node3D.new()
	add_child(entity_root)
	autofree(entity_root)

	var component := C_REGION_VISIBILITY_COMPONENT.new()
	entity_root.add_child(component)
	autofree(component)

	var mesh_a := MeshInstance3D.new()
	mesh_a.mesh = BoxMesh.new()
	mesh_a.position = Vector3(-5.0, 0.0, 0.0)
	entity_root.add_child(mesh_a)
	autofree(mesh_a)

	var mesh_b := MeshInstance3D.new()
	mesh_b.mesh = BoxMesh.new()
	mesh_b.position = Vector3(5.0, 3.0, 10.0)
	entity_root.add_child(mesh_b)
	autofree(mesh_b)

	var aabb: AABB = component.get_region_aabb()
	assert_true(aabb.has_point(mesh_a.global_position), "AABB should contain mesh_a position.")
	assert_true(aabb.has_point(mesh_b.global_position), "AABB should contain mesh_b position.")

func test_get_region_aabb_caches_result() -> void:
	var entity_root := Node3D.new()
	add_child(entity_root)
	autofree(entity_root)

	var component := C_REGION_VISIBILITY_COMPONENT.new()
	entity_root.add_child(component)
	autofree(component)

	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	entity_root.add_child(mesh)
	autofree(mesh)

	var first := component.get_region_aabb()
	var second := component.get_region_aabb()
	assert_eq(first, second, "AABB should be cached.")

func test_get_snapshot_includes_region_tag_alpha_and_active() -> void:
	var component := C_REGION_VISIBILITY_COMPONENT.new()
	autofree(component)
	component.region_tag = StringName("bedroom_area")
	component.current_alpha = 0.5
	component.is_active_region = true

	var snapshot := component.get_snapshot()
	assert_eq(snapshot.get("region_tag", StringName("")), StringName("bedroom_area"))
	assert_almost_eq(float(snapshot.get("current_alpha", -1.0)), 0.5, 0.0001)
	assert_true(bool(snapshot.get("is_active_region", false)))

func test_is_near_region_defaults_to_false() -> void:
	var component := C_REGION_VISIBILITY_COMPONENT.new()
	autofree(component)
	assert_false(component.is_near_region)

func test_snapshot_includes_is_near_region() -> void:
	var component := C_REGION_VISIBILITY_COMPONENT.new()
	autofree(component)
	component.is_near_region = true
	var snapshot := component.get_snapshot()
	assert_true(snapshot.has("is_near_region"))
	assert_true(bool(snapshot.get("is_near_region", false)))

func test_cache_is_invalid_initially() -> void:
	var component := C_REGION_VISIBILITY_COMPONENT.new()
	autofree(component)
	assert_false(component.is_target_cache_valid())
