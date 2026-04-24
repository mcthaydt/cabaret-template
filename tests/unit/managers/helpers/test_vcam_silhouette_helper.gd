extends GutTest

const U_VCAM_SILHOUETTE_HELPER := preload("res://scripts/core/managers/helpers/u_vcam_silhouette_helper.gd")

func _create_mesh_target(initial_transparency: float = 0.0) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	mesh_instance.transparency = initial_transparency
	autofree(mesh_instance)
	return mesh_instance

func test_apply_sets_transparency_on_geometry_instance() -> void:
	var helper := U_VCAM_SILHOUETTE_HELPER.new()
	var target := _create_mesh_target()

	helper.apply_silhouette(target)

	assert_almost_eq(target.transparency, U_VCamSilhouetteHelper.DEFAULT_SILHOUETTE_TRANSPARENCY, 0.001)

func test_apply_preserves_material_override() -> void:
	var helper := U_VCAM_SILHOUETTE_HELPER.new()
	var target := _create_mesh_target()
	var original := StandardMaterial3D.new()
	target.material_override = original

	helper.apply_silhouette(target)

	assert_eq(target.material_override, original, "material_override should stay untouched")

func test_apply_preserves_material_overlay() -> void:
	var helper := U_VCAM_SILHOUETTE_HELPER.new()
	var target := _create_mesh_target()
	var overlay := StandardMaterial3D.new()
	target.material_overlay = overlay

	helper.apply_silhouette(target)

	assert_eq(target.material_overlay, overlay, "material_overlay should stay untouched")

func test_remove_restores_original_transparency() -> void:
	var helper := U_VCAM_SILHOUETTE_HELPER.new()
	var target := _create_mesh_target(0.3)

	helper.apply_silhouette(target)
	assert_almost_eq(target.transparency, U_VCamSilhouetteHelper.DEFAULT_SILHOUETTE_TRANSPARENCY, 0.001)

	helper.remove_silhouette(target)
	assert_almost_eq(target.transparency, 0.3, 0.001, "Should restore original transparency")
	assert_eq(helper.get_active_count(), 0)

func test_remove_all_restores_all_targets() -> void:
	var helper := U_VCAM_SILHOUETTE_HELPER.new()
	var first := _create_mesh_target(0.0)
	var second := _create_mesh_target(0.2)
	helper.apply_silhouette(first)
	helper.apply_silhouette(second)
	assert_eq(helper.get_active_count(), 2)

	helper.remove_all_silhouettes()

	assert_almost_eq(first.transparency, 0.0, 0.001)
	assert_almost_eq(second.transparency, 0.2, 0.001)
	assert_eq(helper.get_active_count(), 0)

func test_active_count_tracks_silhouettes() -> void:
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

func test_apply_on_freed_node_is_safe() -> void:
	var helper := U_VCAM_SILHOUETTE_HELPER.new()
	var target := _create_mesh_target()
	target.free()

	helper.apply_silhouette(target)
	helper.remove_silhouette(target)
	helper.remove_all_silhouettes()

	assert_eq(helper.get_active_count(), 0)

func test_null_target_is_safe() -> void:
	var helper := U_VCAM_SILHOUETTE_HELPER.new()

	helper.apply_silhouette(null)
	helper.remove_silhouette(null)
	helper.remove_all_silhouettes()

	assert_eq(helper.get_active_count(), 0)

func test_reapply_is_idempotent() -> void:
	var helper := U_VCAM_SILHOUETTE_HELPER.new()
	var target := _create_mesh_target()

	helper.apply_silhouette(target)
	helper.apply_silhouette(target)

	assert_almost_eq(target.transparency, U_VCamSilhouetteHelper.DEFAULT_SILHOUETTE_TRANSPARENCY, 0.001)
	assert_eq(helper.get_active_count(), 1, "Should not double-track")

func test_csg_target_gets_transparency() -> void:
	var helper := U_VCAM_SILHOUETTE_HELPER.new()
	var target := CSGBox3D.new()
	autofree(target)
	var csg_material := StandardMaterial3D.new()
	target.material = csg_material

	helper.apply_silhouette(target)

	assert_almost_eq(target.transparency, U_VCamSilhouetteHelper.DEFAULT_SILHOUETTE_TRANSPARENCY, 0.001)
	assert_eq(target.material, csg_material, "CSG .material should stay untouched")

	helper.remove_silhouette(target)
	assert_almost_eq(target.transparency, 0.0, 0.001)

func test_remove_all_handles_freed_targets_gracefully() -> void:
	var helper := U_VCAM_SILHOUETTE_HELPER.new()
	var first := _create_mesh_target()
	var second := _create_mesh_target()
	helper.apply_silhouette(first)
	helper.apply_silhouette(second)
	first.free()

	helper.remove_all_silhouettes()

	assert_almost_eq(second.transparency, 0.0, 0.001)
	assert_eq(helper.get_active_count(), 0)

func test_foreign_shader_override_preserved_through_cycle() -> void:
	var helper := U_VCAM_SILHOUETTE_HELPER.new()
	var target := _create_mesh_target()
	var foreign_shader := ShaderMaterial.new()
	foreign_shader.shader = Shader.new()
	target.material_override = foreign_shader

	helper.apply_silhouette(target)
	helper.remove_silhouette(target)

	assert_eq(target.material_override, foreign_shader, "Foreign shader should survive apply/remove cycle")

func test_update_silhouettes_requires_two_consecutive_frames_before_apply() -> void:
	var helper := U_VCAM_SILHOUETTE_HELPER.new()
	var target := _create_mesh_target()

	helper.update_silhouettes([target], true)
	assert_almost_eq(target.transparency, 0.0, 0.001, "First detection frame should not apply silhouette yet")
	assert_eq(helper.get_active_count(), 0)

	helper.update_silhouettes([target], true)
	assert_almost_eq(target.transparency, U_VCamSilhouetteHelper.DEFAULT_SILHOUETTE_TRANSPARENCY, 0.001)
	assert_eq(helper.get_active_count(), 1)

func test_update_silhouettes_uses_single_frame_grace_before_removal() -> void:
	var helper := U_VCAM_SILHOUETTE_HELPER.new()
	var target := _create_mesh_target()

	helper.update_silhouettes([target], true)
	helper.update_silhouettes([target], true)
	assert_eq(helper.get_active_count(), 1)

	helper.update_silhouettes([], true)
	assert_eq(helper.get_active_count(), 1, "One missing frame should keep silhouette active")
	assert_almost_eq(target.transparency, U_VCamSilhouetteHelper.DEFAULT_SILHOUETTE_TRANSPARENCY, 0.001)

	helper.update_silhouettes([], true)
	assert_eq(helper.get_active_count(), 0, "Second missing frame should clear silhouette")
	assert_almost_eq(target.transparency, 0.0, 0.001)

func test_update_silhouettes_does_not_reapply_when_occluders_unchanged() -> void:
	var helper := U_VCAM_SILHOUETTE_HELPER.new()
	var target := _create_mesh_target()

	helper.update_silhouettes([target], true)
	helper.update_silhouettes([target], true)
	assert_eq(helper.get_active_count(), 1)

	target.transparency = 0.25
	helper.update_silhouettes([target], true)
	assert_almost_eq(target.transparency, 0.25, 0.001, "Stable occluder set should not force reapply every frame")
	assert_eq(helper.get_active_count(), 1)

func test_update_silhouettes_ignores_order_changes_without_flicker() -> void:
	var helper := U_VCAM_SILHOUETTE_HELPER.new()
	var first := _create_mesh_target()
	var second := _create_mesh_target()

	helper.update_silhouettes([first, second], true)
	helper.update_silhouettes([second, first], true)
	assert_eq(helper.get_active_count(), 2)
	assert_almost_eq(first.transparency, U_VCamSilhouetteHelper.DEFAULT_SILHOUETTE_TRANSPARENCY, 0.001)
	assert_almost_eq(second.transparency, U_VCamSilhouetteHelper.DEFAULT_SILHOUETTE_TRANSPARENCY, 0.001)

	helper.update_silhouettes([first, second], true)
	assert_eq(helper.get_active_count(), 2, "Order-only changes should not churn active silhouettes")
