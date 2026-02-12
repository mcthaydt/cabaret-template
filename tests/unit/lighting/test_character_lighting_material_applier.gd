extends BaseTest

const APPLIER_PATH := "res://scripts/utils/lighting/u_character_lighting_material_applier.gd"
const PARAM_ALBEDO_TEXTURE := "albedo_texture"
const PARAM_BASE_TINT := "base_tint"
const PARAM_EFFECTIVE_TINT := "effective_tint"
const PARAM_EFFECTIVE_INTENSITY := "effective_intensity"


func _applier_script() -> Script:
	var script_obj := load(APPLIER_PATH) as Script
	assert_not_null(script_obj, "Material applier helper should load: %s" % APPLIER_PATH)
	return script_obj

func _create_character_root() -> Node3D:
	var root := Node3D.new()
	root.name = "E_TestCharacterRoot"
	add_child(root)
	autofree(root)
	return root

func _create_mesh_instance(material: Material, texture: Texture2D = null) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := ArrayMesh.new()
	var box := BoxMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, box.get_mesh_arrays())
	if material != null:
		mesh.surface_set_material(0, material)
	mesh_instance.mesh = mesh
	if texture != null and material is BaseMaterial3D:
		var base_material := material as BaseMaterial3D
		base_material.albedo_texture = texture
	return mesh_instance

func _create_test_texture() -> ImageTexture:
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.7, 0.2, 0.1, 1.0))
	return ImageTexture.create_from_image(image)

func test_collect_mesh_targets_returns_nested_mesh_instances() -> void:
	var script_obj := _applier_script()
	if script_obj == null:
		return
	var applier: Variant = script_obj.new()
	var character_root := _create_character_root()

	var direct_mesh := _create_mesh_instance(StandardMaterial3D.new())
	direct_mesh.name = "DirectMesh"
	character_root.add_child(direct_mesh)
	autofree(direct_mesh)

	var nested := Node3D.new()
	nested.name = "Nested"
	character_root.add_child(nested)
	autofree(nested)

	var nested_mesh := _create_mesh_instance(StandardMaterial3D.new())
	nested_mesh.name = "NestedMesh"
	nested.add_child(nested_mesh)
	autofree(nested_mesh)

	var result: Array = applier.collect_mesh_targets(character_root)
	assert_eq(result.size(), 2)
	assert_true(result.has(direct_mesh))
	assert_true(result.has(nested_mesh))

func test_apply_character_lighting_swaps_material_and_sets_shader_params() -> void:
	var script_obj := _applier_script()
	if script_obj == null:
		return
	var applier: Variant = script_obj.new()
	var character_root := _create_character_root()
	var texture := _create_test_texture()

	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	var mesh_instance := _create_mesh_instance(material)
	character_root.add_child(mesh_instance)
	autofree(mesh_instance)

	applier.apply_character_lighting(character_root, Color(1.0, 1.0, 1.0, 1.0), Color(0.5, 0.6, 0.7, 1.0), 1.75)

	var override_material := mesh_instance.material_override as ShaderMaterial
	assert_not_null(override_material, "Mesh should receive a ShaderMaterial override.")
	var shader := override_material.shader
	assert_not_null(shader, "ShaderMaterial should have the character lighting shader assigned.")
	var shader_code: String = shader.code
	assert_true(shader_code.find("unshaded") >= 0, "Character shader must remain unshaded.")
	assert_true(shader_code.find("texture(albedo_texture") >= 0, "Character shader must sample albedo texture.")
	assert_eq(override_material.get_shader_parameter(PARAM_ALBEDO_TEXTURE), texture)
	assert_eq(override_material.get_shader_parameter(PARAM_BASE_TINT), Color(1.0, 1.0, 1.0, 1.0))
	assert_eq(override_material.get_shader_parameter(PARAM_EFFECTIVE_TINT), Color(0.5, 0.6, 0.7, 1.0))
	assert_almost_eq(float(override_material.get_shader_parameter(PARAM_EFFECTIVE_INTENSITY)), 1.75, 0.0001)

func test_apply_character_lighting_noops_when_material_is_missing() -> void:
	var script_obj := _applier_script()
	if script_obj == null:
		return
	var applier: Variant = script_obj.new()
	var character_root := _create_character_root()

	var mesh_instance := _create_mesh_instance(null)
	character_root.add_child(mesh_instance)
	autofree(mesh_instance)
	var mesh_without_resource := MeshInstance3D.new()
	character_root.add_child(mesh_without_resource)
	autofree(mesh_without_resource)

	applier.apply_character_lighting(character_root, Color.WHITE, Color.WHITE, 1.0)

	assert_null(mesh_instance.material_override, "Missing source material should leave mesh untouched.")
	assert_null(mesh_without_resource.material_override, "Missing mesh resource should be treated as a no-op.")
	assert_eq(applier.get_cached_mesh_count(), 0, "No cache entry should be created for material-less meshes.")

func test_restore_character_materials_reverts_original_override() -> void:
	var script_obj := _applier_script()
	if script_obj == null:
		return
	var applier: Variant = script_obj.new()
	var character_root := _create_character_root()
	var texture := _create_test_texture()

	var original_override := StandardMaterial3D.new()
	original_override.albedo_texture = texture
	var source_material := StandardMaterial3D.new()
	source_material.albedo_texture = texture
	var mesh_instance := _create_mesh_instance(source_material)
	mesh_instance.material_override = original_override
	character_root.add_child(mesh_instance)
	autofree(mesh_instance)

	applier.apply_character_lighting(character_root, Color.WHITE, Color(0.8, 0.8, 0.8, 1.0), 2.0)
	assert_true(mesh_instance.material_override is ShaderMaterial)

	applier.restore_character_materials(character_root)
	assert_eq(mesh_instance.material_override, original_override)
	assert_eq(applier.get_cached_mesh_count(), 0)

func test_restore_all_materials_clears_cache_after_meshes_are_freed() -> void:
	var script_obj := _applier_script()
	if script_obj == null:
		return
	var applier: Variant = script_obj.new()
	var character_root := _create_character_root()
	var texture := _create_test_texture()

	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	var mesh_instance := _create_mesh_instance(material)
	character_root.add_child(mesh_instance)
	autofree(mesh_instance)

	applier.apply_character_lighting(character_root, Color.WHITE, Color.WHITE, 1.0)
	assert_eq(applier.get_cached_mesh_count(), 1)

	character_root.queue_free()
	await get_tree().process_frame
	applier.restore_all_materials()
	assert_eq(applier.get_cached_mesh_count(), 0)
