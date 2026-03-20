extends BaseTest

const APPLIER_PATH := "res://scripts/utils/lighting/u_room_fade_material_applier.gd"
const PARAM_FADE_ALPHA := "fade_alpha"
const PARAM_ALBEDO_TEXTURE := "albedo_texture"

func _applier_script() -> Script:
	var script_obj := load(APPLIER_PATH) as Script
	assert_not_null(script_obj, "Room fade material applier should load: %s" % APPLIER_PATH)
	return script_obj

func _create_test_texture() -> ImageTexture:
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.5, 0.8, 0.3, 1.0))
	return ImageTexture.create_from_image(image)

func _create_mesh_instance(material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := ArrayMesh.new()
	var box := BoxMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, box.get_mesh_arrays())
	if material != null:
		mesh.surface_set_material(0, material)
	mesh_instance.mesh = mesh
	return mesh_instance

func test_apply_fade_material_replaces_override_with_room_fade_shader() -> void:
	var script_obj := _applier_script()
	if script_obj == null:
		return
	var applier: Variant = script_obj.new()

	var material := StandardMaterial3D.new()
	material.albedo_texture = _create_test_texture()
	var mesh_instance := _create_mesh_instance(material)
	autofree(mesh_instance)

	applier.apply_fade_material([mesh_instance])

	var override_material := mesh_instance.material_override as ShaderMaterial
	assert_not_null(override_material)
	assert_not_null(override_material.shader)
	var shader_code: String = override_material.shader.code
	assert_true(shader_code.find("blend_mix") >= 0, "Shader should enable blend_mix render mode.")
	assert_true(shader_code.find("depth_draw_never") >= 0, "Shader should disable depth writes for transparent fades.")
	assert_eq(shader_code.find("ALPHA_SCISSOR_THRESHOLD"), -1, "Room-fade shader should not use alpha scissor cutoff.")

func test_apply_fade_material_carries_forward_albedo_texture() -> void:
	var script_obj := _applier_script()
	if script_obj == null:
		return
	var applier: Variant = script_obj.new()

	var texture := _create_test_texture()
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	var mesh_instance := _create_mesh_instance(material)
	autofree(mesh_instance)

	applier.apply_fade_material([mesh_instance])

	var override_material := mesh_instance.material_override as ShaderMaterial
	assert_not_null(override_material)
	assert_eq(override_material.get_shader_parameter(PARAM_ALBEDO_TEXTURE), texture)

func test_apply_fade_material_caches_original_material_override() -> void:
	var script_obj := _applier_script()
	if script_obj == null:
		return
	var applier: Variant = script_obj.new()

	var texture := _create_test_texture()
	var source_material := StandardMaterial3D.new()
	source_material.albedo_texture = texture
	var mesh_instance := _create_mesh_instance(source_material)
	autofree(mesh_instance)

	var original_override := StandardMaterial3D.new()
	original_override.albedo_texture = texture
	mesh_instance.material_override = original_override

	applier.apply_fade_material([mesh_instance])

	assert_true(mesh_instance.material_override is ShaderMaterial)
	assert_eq(applier.get_cached_mesh_count(), 1)

func test_update_fade_alpha_sets_uniform_on_applied_materials() -> void:
	var script_obj := _applier_script()
	if script_obj == null:
		return
	var applier: Variant = script_obj.new()

	var material := StandardMaterial3D.new()
	material.albedo_texture = _create_test_texture()
	var mesh_instance := _create_mesh_instance(material)
	autofree(mesh_instance)

	applier.apply_fade_material([mesh_instance])
	applier.update_fade_alpha([mesh_instance], 0.35)

	var override_material := mesh_instance.material_override as ShaderMaterial
	assert_not_null(override_material)
	assert_almost_eq(float(override_material.get_shader_parameter(PARAM_FADE_ALPHA)), 0.35, 0.0001)

func test_restore_original_materials_restores_and_clears_cache() -> void:
	var script_obj := _applier_script()
	if script_obj == null:
		return
	var applier: Variant = script_obj.new()

	var texture := _create_test_texture()
	var source_material := StandardMaterial3D.new()
	source_material.albedo_texture = texture
	var mesh_instance := _create_mesh_instance(source_material)
	autofree(mesh_instance)

	var original_override := StandardMaterial3D.new()
	original_override.albedo_texture = texture
	mesh_instance.material_override = original_override

	applier.apply_fade_material([mesh_instance])
	assert_true(mesh_instance.material_override is ShaderMaterial)
	assert_eq(applier.get_cached_mesh_count(), 1)

	applier.restore_original_materials([mesh_instance])
	assert_eq(mesh_instance.material_override, original_override)
	assert_eq(applier.get_cached_mesh_count(), 0)

func test_restore_original_materials_is_safe_when_nothing_cached() -> void:
	var script_obj := _applier_script()
	if script_obj == null:
		return
	var applier: Variant = script_obj.new()

	var mesh_instance := _create_mesh_instance(null)
	autofree(mesh_instance)

	applier.restore_original_materials([mesh_instance])
	assert_eq(applier.get_cached_mesh_count(), 0)
	assert_null(mesh_instance.material_override)

func test_apply_fade_material_skips_reconfiguration_for_already_applied_target() -> void:
	var script_obj := _applier_script()
	if script_obj == null:
		return
	var applier: Variant = script_obj.new()

	var material := StandardMaterial3D.new()
	material.albedo_texture = _create_test_texture()
	var mesh_instance := _create_mesh_instance(material)
	autofree(mesh_instance)

	applier.apply_fade_material([mesh_instance])
	applier.update_fade_alpha([mesh_instance], 0.5)

	applier.apply_fade_material([mesh_instance])

	var override_material := mesh_instance.material_override as ShaderMaterial
	assert_not_null(override_material)
	assert_almost_eq(float(override_material.get_shader_parameter(PARAM_FADE_ALPHA)), 0.5, 0.0001,
		"Alpha should remain 0.5 after second apply (not reset to 1.0).")

func test_is_fade_applied_returns_true_after_apply() -> void:
	var script_obj := _applier_script()
	if script_obj == null:
		return
	var applier: Variant = script_obj.new()

	var material := StandardMaterial3D.new()
	material.albedo_texture = _create_test_texture()
	var mesh_instance := _create_mesh_instance(material)
	autofree(mesh_instance)

	applier.apply_fade_material([mesh_instance])
	assert_true(applier.is_fade_applied(mesh_instance))

func test_is_fade_applied_returns_false_before_apply() -> void:
	var script_obj := _applier_script()
	if script_obj == null:
		return
	var applier: Variant = script_obj.new()

	var mesh_instance := _create_mesh_instance(null)
	autofree(mesh_instance)

	assert_false(applier.is_fade_applied(mesh_instance))

func test_is_fade_applied_returns_false_after_restore() -> void:
	var script_obj := _applier_script()
	if script_obj == null:
		return
	var applier: Variant = script_obj.new()

	var material := StandardMaterial3D.new()
	material.albedo_texture = _create_test_texture()
	var mesh_instance := _create_mesh_instance(material)
	autofree(mesh_instance)

	applier.apply_fade_material([mesh_instance])
	assert_true(applier.is_fade_applied(mesh_instance))

	applier.restore_original_materials([mesh_instance])
	assert_false(applier.is_fade_applied(mesh_instance))

func test_apply_and_restore_supports_csg_shapes() -> void:
	var script_obj := _applier_script()
	if script_obj == null:
		return
	var applier: Variant = script_obj.new()

	var original_material := StandardMaterial3D.new()
	original_material.albedo_texture = _create_test_texture()
	var csg_shape := CSGBox3D.new()
	csg_shape.material = original_material
	autofree(csg_shape)

	applier.apply_fade_material([csg_shape])
	assert_true(csg_shape.material is ShaderMaterial)
	applier.update_fade_alpha([csg_shape], 0.4)
	var fade_material := csg_shape.material as ShaderMaterial
	assert_not_null(fade_material)
	assert_almost_eq(float(fade_material.get_shader_parameter(PARAM_FADE_ALPHA)), 0.4, 0.0001)

	applier.restore_original_materials([csg_shape])
	assert_eq(csg_shape.material, original_material)
