extends GutTest

const U_VCAM_SILHOUETTE_HELPER := preload("res://scripts/managers/helpers/u_vcam_silhouette_helper.gd")

func _create_mesh_target() -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	autofree(mesh_instance)
	return mesh_instance

func test_apply_silhouette_sets_shader_override_on_geometry_instance() -> void:
	var helper := U_VCAM_SILHOUETTE_HELPER.new()
	var target := _create_mesh_target()

	helper.apply_silhouette(target)

	assert_true(target.material_override is ShaderMaterial)
	var silhouette_material := target.material_override as ShaderMaterial
	assert_not_null(silhouette_material.shader)

func test_apply_silhouette_preserves_original_material_state() -> void:
	var helper := U_VCAM_SILHOUETTE_HELPER.new()
	var target := _create_mesh_target()
	var original_material := StandardMaterial3D.new()
	target.material_override = original_material

	helper.apply_silhouette(target)

	assert_true(target.material_override is ShaderMaterial)
	helper.remove_silhouette(target)
	assert_eq(target.material_override, original_material)

func test_remove_silhouette_restores_original_material_override() -> void:
	var helper := U_VCAM_SILHOUETTE_HELPER.new()
	var target := _create_mesh_target()
	var original_material := StandardMaterial3D.new()
	target.material_override = original_material
	helper.apply_silhouette(target)

	helper.remove_silhouette(target)

	assert_eq(target.material_override, original_material)
	assert_eq(helper.get_active_count(), 0)

func test_remove_all_silhouettes_cleans_up_all_tracked_overrides() -> void:
	var helper := U_VCAM_SILHOUETTE_HELPER.new()
	var first := _create_mesh_target()
	var second := _create_mesh_target()
	var first_original := StandardMaterial3D.new()
	var second_original := StandardMaterial3D.new()
	first.material_override = first_original
	second.material_override = second_original
	helper.apply_silhouette(first)
	helper.apply_silhouette(second)
	assert_eq(helper.get_active_count(), 2)

	helper.remove_all_silhouettes()

	assert_eq(first.material_override, first_original)
	assert_eq(second.material_override, second_original)
	assert_eq(helper.get_active_count(), 0)

func test_get_active_count_reports_tracked_silhouette_count() -> void:
	var helper := U_VCAM_SILHOUETTE_HELPER.new()
	var first := _create_mesh_target()
	var second := _create_mesh_target()
	assert_eq(helper.get_active_count(), 0)

	helper.apply_silhouette(first)
	assert_eq(helper.get_active_count(), 1)
	helper.apply_silhouette(second)
	assert_eq(helper.get_active_count(), 2)
	helper.remove_silhouette(first)
	assert_eq(helper.get_active_count(), 1)

func test_apply_silhouette_on_freed_node_is_safe() -> void:
	var helper := U_VCAM_SILHOUETTE_HELPER.new()
	var target := _create_mesh_target()
	target.free()

	helper.apply_silhouette(target)
	helper.remove_silhouette(target)
	helper.remove_all_silhouettes()

	assert_eq(helper.get_active_count(), 0)
