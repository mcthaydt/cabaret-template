extends BaseTest

const APPLIER_PATH := "res://scripts/utils/lighting/u_wall_visibility_material_applier.gd"
const SH_WALL_VISIBILITY := preload("res://assets/shaders/sh_wall_visibility.gdshader")


func _applier_script() -> Script:
	var script_obj := load(APPLIER_PATH) as Script
	assert_not_null(script_obj, "Wall visibility material applier should load: %s" % APPLIER_PATH)
	return script_obj


func _create_applier() -> Variant:
	var script := _applier_script()
	if script == null:
		return null
	return script.new()


# --- Apply tests ---

func test_apply_visibility_material_applies_shader_to_mesh_instance() -> void:
	var applier = _create_applier()
	assert_not_null(applier)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	add_child(mesh_instance)
	autofree(mesh_instance)

	var original_material := mesh_instance.material_override
	applier.apply_visibility_material([mesh_instance])

	assert_not_null(mesh_instance.material_override, "Should have shader material override.")
	assert_eq(mesh_instance.material_override.shader, SH_WALL_VISIBILITY,
		"Shader material should use wall visibility shader.")
	assert_true(applier.is_applied(mesh_instance), "Target should be marked as applied.")


func test_apply_visibility_material_applies_shader_to_csg_shape() -> void:
	var applier = _create_applier()
	assert_not_null(applier)

	var csg_shape := CSGBox3D.new()
	add_child(csg_shape)
	autofree(csg_shape)

	applier.apply_visibility_material([csg_shape])

	assert_not_null(csg_shape.material, "CSG should have shader material.")
	assert_eq(csg_shape.material.shader, SH_WALL_VISIBILITY,
		"CSG shader material should use wall visibility shader.")
	assert_true(applier.is_applied(csg_shape), "CSG target should be marked as applied.")


func test_apply_skips_mesh_with_null_mesh() -> void:
	var applier = _create_applier()
	assert_not_null(applier)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = null
	add_child(mesh_instance)
	autofree(mesh_instance)

	applier.apply_visibility_material([mesh_instance])

	assert_false(applier.is_applied(mesh_instance), "Should skip mesh with null mesh resource.")


func test_apply_does_not_double_apply() -> void:
	var applier = _create_applier()
	assert_not_null(applier)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	add_child(mesh_instance)
	autofree(mesh_instance)

	applier.apply_visibility_material([mesh_instance])
	var first_material: ShaderMaterial = mesh_instance.material_override

	applier.apply_visibility_material([mesh_instance])
	assert_eq(mesh_instance.material_override, first_material,
		"Should not replace material on second apply.")
	assert_eq(applier.get_cached_mesh_count(), 1, "Cache should have one entry.")


func test_apply_caches_original_material_override() -> void:
	var applier = _create_applier()
	assert_not_null(applier)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	var original := StandardMaterial3D.new()
	mesh_instance.material_override = original
	add_child(mesh_instance)
	autofree(mesh_instance)

	applier.apply_visibility_material([mesh_instance])

	assert_not_null(mesh_instance.material_override, "Should have shader material.")
	assert_ne(mesh_instance.material_override, original,
		"Material override should be replaced with shader material.")


func test_apply_extracts_albedo_texture_from_base_material() -> void:
	var applier = _create_applier()
	assert_not_null(applier)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	var original := StandardMaterial3D.new()
	var test_texture := GradientTexture2D.new()
	original.albedo_texture = test_texture
	mesh_instance.material_override = original
	add_child(mesh_instance)
	autofree(mesh_instance)

	applier.apply_visibility_material([mesh_instance])

	var shader_mat: ShaderMaterial = mesh_instance.material_override as ShaderMaterial
	assert_not_null(shader_mat, "Should have shader material.")
	var extracted_texture: Variant = shader_mat.get_shader_parameter("albedo_texture")
	assert_eq(extracted_texture, test_texture,
		"Should carry forward albedo texture from original material.")


# --- Update uniforms tests ---

func test_update_uniforms_sets_clip_y_and_fade() -> void:
	var applier = _create_applier()
	assert_not_null(applier)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	add_child(mesh_instance)
	autofree(mesh_instance)

	applier.apply_visibility_material([mesh_instance])
	applier.update_uniforms(mesh_instance, 5.0, 0.7)

	var shader_mat: ShaderMaterial = mesh_instance.material_override as ShaderMaterial
	assert_not_null(shader_mat)
	assert_almost_eq(float(shader_mat.get_shader_parameter("clip_y_world")), 5.0, 0.0001,
		"clip_y_world should be 5.0.")
	assert_almost_eq(float(shader_mat.get_shader_parameter("fade_amount")), 0.7, 0.0001,
		"fade_amount should be 0.7.")


func test_update_uniforms_clamps_fade_to_zero_one() -> void:
	var applier = _create_applier()
	assert_not_null(applier)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	add_child(mesh_instance)
	autofree(mesh_instance)

	applier.apply_visibility_material([mesh_instance])
	applier.update_uniforms(mesh_instance, 100.0, 1.5)

	var shader_mat: ShaderMaterial = mesh_instance.material_override as ShaderMaterial
	assert_almost_eq(float(shader_mat.get_shader_parameter("fade_amount")), 1.0, 0.0001,
		"fade_amount should clamp to 1.0.")


func test_update_clip_y_bulk_updates_targets() -> void:
	var applier = _create_applier()
	assert_not_null(applier)

	var mesh_a := MeshInstance3D.new()
	mesh_a.mesh = BoxMesh.new()
	add_child(mesh_a)
	autofree(mesh_a)

	var mesh_b := MeshInstance3D.new()
	mesh_b.mesh = BoxMesh.new()
	add_child(mesh_b)
	autofree(mesh_b)

	applier.apply_visibility_material([mesh_a, mesh_b])
	applier.update_clip_y([mesh_a, mesh_b], 7.5)

	var shader_a: ShaderMaterial = mesh_a.material_override as ShaderMaterial
	var shader_b: ShaderMaterial = mesh_b.material_override as ShaderMaterial
	assert_almost_eq(float(shader_a.get_shader_parameter("clip_y_world")), 7.5, 0.0001,
		"mesh_a clip_y should be 7.5.")
	assert_almost_eq(float(shader_b.get_shader_parameter("clip_y_world")), 7.5, 0.0001,
		"mesh_b clip_y should be 7.5.")


# --- Restore tests ---

func test_restore_original_materials_restores_mesh_override() -> void:
	var applier = _create_applier()
	assert_not_null(applier)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	var original := StandardMaterial3D.new()
	mesh_instance.material_override = original
	add_child(mesh_instance)
	autofree(mesh_instance)

	applier.apply_visibility_material([mesh_instance])
	assert_ne(mesh_instance.material_override, original, "Should have shader applied.")

	applier.restore_original_materials([mesh_instance])
	assert_eq(mesh_instance.material_override, original,
		"Should restore original material override.")
	assert_false(applier.is_applied(mesh_instance), "Should no longer be applied.")


func test_restore_original_materials_restores_csg_material() -> void:
	var applier = _create_applier()
	assert_not_null(applier)

	var csg_shape := CSGBox3D.new()
	var original := StandardMaterial3D.new()
	csg_shape.material = original
	add_child(csg_shape)
	autofree(csg_shape)

	applier.apply_visibility_material([csg_shape])
	assert_ne(csg_shape.material, original, "Should have shader applied.")

	applier.restore_original_materials([csg_shape])
	assert_eq(csg_shape.material, original,
		"Should restore original CSG material.")
	assert_false(applier.is_applied(csg_shape), "Should no longer be applied.")


func test_restore_handles_null_original_material() -> void:
	var applier = _create_applier()
	assert_not_null(applier)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	mesh_instance.material_override = null
	add_child(mesh_instance)
	autofree(mesh_instance)

	applier.apply_visibility_material([mesh_instance])
	applier.restore_original_materials([mesh_instance])

	assert_null(mesh_instance.material_override,
		"Should restore to null original material override.")


func test_restore_is_safe_when_nothing_cached() -> void:
	var applier = _create_applier()
	assert_not_null(applier)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	add_child(mesh_instance)
	autofree(mesh_instance)

	applier.restore_original_materials([mesh_instance])
	assert_null(mesh_instance.material_override, "Should remain null — nothing was cached.")


# --- is_applied tests ---

func test_is_applied_returns_false_for_uncached_target() -> void:
	var applier = _create_applier()
	assert_not_null(applier)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	add_child(mesh_instance)
	autofree(mesh_instance)

	assert_false(applier.is_applied(mesh_instance), "Should be false before apply.")


func test_is_applied_returns_true_after_apply() -> void:
	var applier = _create_applier()
	assert_not_null(applier)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	add_child(mesh_instance)
	autofree(mesh_instance)

	applier.apply_visibility_material([mesh_instance])
	assert_true(applier.is_applied(mesh_instance), "Should be true after apply.")


func test_is_applied_returns_false_for_null_target() -> void:
	var applier = _create_applier()
	assert_not_null(applier)
	assert_false(applier.is_applied(null), "Should return false for null target.")


# --- Invalidate tests ---

func test_invalidate_externally_removed_detects_mesh_override_change() -> void:
	var applier = _create_applier()
	assert_not_null(applier)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	add_child(mesh_instance)
	autofree(mesh_instance)

	applier.apply_visibility_material([mesh_instance])
	assert_true(applier.is_applied(mesh_instance))

	mesh_instance.material_override = StandardMaterial3D.new()
	applier.invalidate_externally_removed()

	assert_false(applier.is_applied(mesh_instance),
		"Should remove cache entry when material was externally changed.")


func test_invalidate_externally_removed_detects_csg_material_change() -> void:
	var applier = _create_applier()
	assert_not_null(applier)

	var csg_shape := CSGBox3D.new()
	add_child(csg_shape)
	autofree(csg_shape)

	applier.apply_visibility_material([csg_shape])
	assert_true(applier.is_applied(csg_shape))

	csg_shape.material = StandardMaterial3D.new()
	applier.invalidate_externally_removed()

	assert_false(applier.is_applied(csg_shape),
		"Should remove cache entry when CSG material was externally changed.")


# --- Dirty-flag uniform update tests ---

func test_update_uniforms_uploads_on_first_call() -> void:
	var applier = _create_applier()
	assert_not_null(applier)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	add_child(mesh_instance)
	autofree(mesh_instance)

	applier.apply_visibility_material([mesh_instance])
	var uploads_before: int = applier.shader_parameter_set_count
	applier.update_uniforms(mesh_instance, 5.0, 0.7)
	var uploads_after: int = applier.shader_parameter_set_count

	assert_eq(uploads_after - uploads_before, 2,
		"First call should upload both clip_y_world and fade_amount.")
	assert_almost_eq(float(mesh_instance.material_override.get_shader_parameter("clip_y_world")), 5.0, 0.0001,
		"clip_y_world should be 5.0.")
	assert_almost_eq(float(mesh_instance.material_override.get_shader_parameter("fade_amount")), 0.7, 0.0001,
		"fade_amount should be 0.7.")


func test_update_uniforms_skips_upload_when_unchanged() -> void:
	var applier = _create_applier()
	assert_not_null(applier)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	add_child(mesh_instance)
	autofree(mesh_instance)

	applier.apply_visibility_material([mesh_instance])
	applier.update_uniforms(mesh_instance, 5.0, 0.7)
	var uploads_after_first: int = applier.shader_parameter_set_count

	applier.update_uniforms(mesh_instance, 5.0, 0.7)
	var uploads_after_second: int = applier.shader_parameter_set_count

	assert_eq(uploads_after_second - uploads_after_first, 0,
		"Second call with same values should not upload any shader parameters.")


func test_update_uniforms_uploads_only_clip_y_when_fade_unchanged() -> void:
	var applier = _create_applier()
	assert_not_null(applier)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	add_child(mesh_instance)
	autofree(mesh_instance)

	applier.apply_visibility_material([mesh_instance])
	applier.update_uniforms(mesh_instance, 5.0, 0.7)
	var uploads_after_first: int = applier.shader_parameter_set_count

	applier.update_uniforms(mesh_instance, 8.0, 0.7)
	var uploads_after_second: int = applier.shader_parameter_set_count

	assert_eq(uploads_after_second - uploads_after_first, 1,
		"Only clip_y_world should upload when only clip_y changes.")
	assert_almost_eq(float(mesh_instance.material_override.get_shader_parameter("clip_y_world")), 8.0, 0.0001,
		"clip_y_world should be 8.0.")


func test_update_uniforms_uploads_only_fade_when_clip_y_unchanged() -> void:
	var applier = _create_applier()
	assert_not_null(applier)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	add_child(mesh_instance)
	autofree(mesh_instance)

	applier.apply_visibility_material([mesh_instance])
	applier.update_uniforms(mesh_instance, 5.0, 0.7)
	var uploads_after_first: int = applier.shader_parameter_set_count

	applier.update_uniforms(mesh_instance, 5.0, 0.3)
	var uploads_after_second: int = applier.shader_parameter_set_count

	assert_eq(uploads_after_second - uploads_after_first, 1,
		"Only fade_amount should upload when only fade changes.")
	assert_almost_eq(float(mesh_instance.material_override.get_shader_parameter("fade_amount")), 0.3, 0.0001,
		"fade_amount should be 0.3.")


func test_update_uniforms_uploads_both_after_restore_and_reapply() -> void:
	var applier = _create_applier()
	assert_not_null(applier)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	add_child(mesh_instance)
	autofree(mesh_instance)

	applier.apply_visibility_material([mesh_instance])
	applier.update_uniforms(mesh_instance, 5.0, 0.7)
	applier.restore_original_materials([mesh_instance])

	applier.apply_visibility_material([mesh_instance])
	var uploads_before: int = applier.shader_parameter_set_count
	applier.update_uniforms(mesh_instance, 5.0, 0.7)
	var uploads_after: int = applier.shader_parameter_set_count

	assert_eq(uploads_after - uploads_before, 2,
		"After restore+reapply, both parameters should upload again.")


func test_update_uniforms_uploads_both_after_invalidate_and_reapply() -> void:
	var applier = _create_applier()
	assert_not_null(applier)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	add_child(mesh_instance)
	autofree(mesh_instance)

	applier.apply_visibility_material([mesh_instance])
	applier.update_uniforms(mesh_instance, 5.0, 0.7)

	mesh_instance.material_override = StandardMaterial3D.new()
	applier.invalidate_externally_removed()
	applier.apply_visibility_material([mesh_instance])

	var uploads_before: int = applier.shader_parameter_set_count
	applier.update_uniforms(mesh_instance, 5.0, 0.7)
	var uploads_after: int = applier.shader_parameter_set_count

	assert_eq(uploads_after - uploads_before, 2,
		"After invalidate+reapply, both parameters should upload again.")


# --- Cache count tests ---

func test_get_cached_mesh_count_reflects_active_entries() -> void:
	var applier = _create_applier()
	assert_not_null(applier)

	assert_eq(applier.get_cached_mesh_count(), 0, "Should start with no cache entries.")

	var mesh_a := MeshInstance3D.new()
	mesh_a.mesh = BoxMesh.new()
	add_child(mesh_a)
	autofree(mesh_a)

	var mesh_b := MeshInstance3D.new()
	mesh_b.mesh = BoxMesh.new()
	add_child(mesh_b)
	autofree(mesh_b)

	applier.apply_visibility_material([mesh_a, mesh_b])
	assert_eq(applier.get_cached_mesh_count(), 2, "Should have 2 cache entries.")

	applier.restore_original_materials([mesh_a])
	assert_eq(applier.get_cached_mesh_count(), 1, "Should have 1 cache entry after restore.")
