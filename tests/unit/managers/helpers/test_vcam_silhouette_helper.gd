extends GutTest

const U_VCAM_SILHOUETTE_HELPER := preload("res://scripts/managers/helpers/u_vcam_silhouette_helper.gd")

func _create_entity_with_meshes(mesh_count: int) -> Node3D:
	var root := Node3D.new()
	add_child_autofree(root)
	for i in mesh_count:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = BoxMesh.new()
		root.add_child(mesh_instance)
	return root

func _create_entity_with_nested_meshes() -> Node3D:
	var root := Node3D.new()
	add_child_autofree(root)
	var child := Node3D.new()
	root.add_child(child)
	var grandchild := MeshInstance3D.new()
	grandchild.mesh = BoxMesh.new()
	child.add_child(grandchild)
	var deep := Node3D.new()
	grandchild.add_child(deep)
	var deep_mesh := MeshInstance3D.new()
	deep_mesh.mesh = BoxMesh.new()
	deep.add_child(deep_mesh)
	return root

func test_apply_sets_material_overlay_on_child_meshes() -> void:
	var helper := U_VCAM_SILHOUETTE_HELPER.new()
	var entity := _create_entity_with_meshes(2)

	helper.apply_silhouette(entity)

	for child in entity.get_children():
		var mesh := child as MeshInstance3D
		if mesh == null:
			continue
		assert_true(mesh.material_overlay is ShaderMaterial, "Child mesh should have overlay set")

func test_apply_does_not_touch_material_override() -> void:
	var helper := U_VCAM_SILHOUETTE_HELPER.new()
	var entity := _create_entity_with_meshes(1)
	var mesh: MeshInstance3D = entity.get_child(0) as MeshInstance3D
	var original := StandardMaterial3D.new()
	mesh.material_override = original

	helper.apply_silhouette(entity)

	assert_eq(mesh.material_override, original, "material_override should remain unchanged")

func test_apply_preserves_existing_material_overlay() -> void:
	var helper := U_VCAM_SILHOUETTE_HELPER.new()
	var entity := _create_entity_with_meshes(1)
	var mesh: MeshInstance3D = entity.get_child(0) as MeshInstance3D
	var original_overlay := StandardMaterial3D.new()
	mesh.material_overlay = original_overlay

	helper.apply_silhouette(entity)

	assert_true(mesh.material_overlay is ShaderMaterial, "Should apply silhouette overlay")

	helper.remove_silhouette(entity)

	assert_eq(mesh.material_overlay, original_overlay, "Should restore original overlay after remove")

func test_remove_restores_all_mesh_overlays() -> void:
	var helper := U_VCAM_SILHOUETTE_HELPER.new()
	var entity := _create_entity_with_meshes(2)
	var mesh_a: MeshInstance3D = entity.get_child(0) as MeshInstance3D
	var mesh_b: MeshInstance3D = entity.get_child(1) as MeshInstance3D
	var overlay_a := StandardMaterial3D.new()
	var overlay_b := ShaderMaterial.new()
	mesh_a.material_overlay = overlay_a
	mesh_b.material_overlay = overlay_b

	helper.apply_silhouette(entity)
	helper.remove_silhouette(entity)

	assert_eq(mesh_a.material_overlay, overlay_a, "Mesh A overlay should be restored")
	assert_eq(mesh_b.material_overlay, overlay_b, "Mesh B overlay should be restored")

func test_remove_all_clears_all_tracked_entities() -> void:
	var helper := U_VCAM_SILHOUETTE_HELPER.new()
	var entity_a := _create_entity_with_meshes(1)
	var entity_b := _create_entity_with_meshes(1)

	helper.apply_silhouette(entity_a)
	helper.apply_silhouette(entity_b)
	assert_eq(helper.get_active_count(), 2)

	helper.remove_all_silhouettes()

	assert_eq(helper.get_active_count(), 0)
	assert_null((entity_a.get_child(0) as MeshInstance3D).material_overlay, "Entity A mesh overlay should be cleared")
	assert_null((entity_b.get_child(0) as MeshInstance3D).material_overlay, "Entity B mesh overlay should be cleared")

func test_active_count_tracks_mesh_instances() -> void:
	var helper := U_VCAM_SILHOUETTE_HELPER.new()
	var entity := _create_entity_with_meshes(3)

	helper.apply_silhouette(entity)

	assert_eq(helper.get_active_count(), 3, "Entity with 3 meshes = count 3")

func test_null_entity_is_safe() -> void:
	var helper := U_VCAM_SILHOUETTE_HELPER.new()

	helper.apply_silhouette(null)
	helper.remove_silhouette(null)
	helper.remove_all_silhouettes()

	assert_eq(helper.get_active_count(), 0)

func test_freed_entity_is_safe() -> void:
	var helper := U_VCAM_SILHOUETTE_HELPER.new()
	var entity := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	entity.add_child(mesh)
	entity.free()

	helper.apply_silhouette(entity)
	helper.remove_silhouette(entity)

	assert_eq(helper.get_active_count(), 0)

func test_skips_meshes_without_mesh_resource() -> void:
	var helper := U_VCAM_SILHOUETTE_HELPER.new()
	var entity := Node3D.new()
	add_child_autofree(entity)
	var empty_mesh := MeshInstance3D.new()
	entity.add_child(empty_mesh)
	var valid_mesh := MeshInstance3D.new()
	valid_mesh.mesh = BoxMesh.new()
	entity.add_child(valid_mesh)

	helper.apply_silhouette(entity)

	assert_null(empty_mesh.material_overlay, "Mesh without resource should be skipped")
	assert_true(valid_mesh.material_overlay is ShaderMaterial, "Valid mesh should get overlay")
	assert_eq(helper.get_active_count(), 1)

func test_reapply_is_idempotent() -> void:
	var helper := U_VCAM_SILHOUETTE_HELPER.new()
	var entity := _create_entity_with_meshes(1)

	helper.apply_silhouette(entity)
	var first_overlay: Material = (entity.get_child(0) as MeshInstance3D).material_overlay

	helper.apply_silhouette(entity)
	var second_overlay: Material = (entity.get_child(0) as MeshInstance3D).material_overlay

	assert_eq(first_overlay, second_overlay, "Same shader on reapply")
	assert_eq(helper.get_active_count(), 1, "No double-tracking")

func test_shader_material_has_render_priority() -> void:
	var helper := U_VCAM_SILHOUETTE_HELPER.new()
	var entity := _create_entity_with_meshes(1)

	helper.apply_silhouette(entity)

	var mesh: MeshInstance3D = entity.get_child(0) as MeshInstance3D
	var overlay := mesh.material_overlay as ShaderMaterial
	assert_not_null(overlay, "Should have ShaderMaterial overlay")
	assert_eq(overlay.render_priority, 10, "Render priority should be 10")

func test_collects_nested_meshes() -> void:
	var helper := U_VCAM_SILHOUETTE_HELPER.new()
	var entity := _create_entity_with_nested_meshes()

	helper.apply_silhouette(entity)

	assert_eq(helper.get_active_count(), 2, "Should find both nested meshes")

func test_freed_mesh_during_remove_is_safe() -> void:
	var helper := U_VCAM_SILHOUETTE_HELPER.new()
	var entity := Node3D.new()
	add_child_autofree(entity)
	var mesh_a := MeshInstance3D.new()
	mesh_a.mesh = BoxMesh.new()
	entity.add_child(mesh_a)
	var mesh_b := MeshInstance3D.new()
	mesh_b.mesh = BoxMesh.new()
	entity.add_child(mesh_b)

	helper.apply_silhouette(entity)
	assert_eq(helper.get_active_count(), 2)

	mesh_a.free()
	helper.remove_silhouette(entity)

	assert_eq(helper.get_active_count(), 0, "Should prune freed mesh and remove remaining")

func test_csg_children_not_targeted() -> void:
	var helper := U_VCAM_SILHOUETTE_HELPER.new()
	var entity := Node3D.new()
	add_child_autofree(entity)
	var csg := CSGBox3D.new()
	var csg_material := StandardMaterial3D.new()
	csg.material = csg_material
	entity.add_child(csg)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	entity.add_child(mesh)

	helper.apply_silhouette(entity)

	assert_eq(csg.material, csg_material, "CSG material should be untouched")
	assert_true(mesh.material_overlay is ShaderMaterial, "MeshInstance3D should get overlay")
	assert_eq(helper.get_active_count(), 1, "Only MeshInstance3D counted")
