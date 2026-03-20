extends RefCounted
class_name U_RoomFadeMaterialApplier

const SH_ROOM_FADE := preload("res://assets/shaders/sh_room_fade.gdshader")

const PARAM_FADE_ALPHA := "fade_alpha"
const PARAM_ALBEDO_TEXTURE := "albedo_texture"
const PARAM_ALBEDO_COLOR := "albedo_color"
const TARGET_TYPE_MESH := "mesh"
const TARGET_TYPE_CSG := "csg"

var _material_cache: Dictionary = {}
var _shader: Shader = SH_ROOM_FADE

func is_fade_applied(target: Node3D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	return _material_cache.has(target.get_instance_id())

func apply_fade_material(targets: Array) -> void:
	_prune_invalid_cache_entries()
	for target_variant in targets:
		if target_variant is MeshInstance3D:
			_apply_mesh_fade_material(target_variant as MeshInstance3D)
			continue
		if target_variant is CSGShape3D:
			_apply_csg_fade_material(target_variant as CSGShape3D)

func update_fade_alpha(targets: Array, alpha: float) -> void:
	var resolved_alpha: float = clampf(alpha, 0.0, 1.0)
	for target_variant in targets:
		var target_id: int = _resolve_target_id(target_variant)
		if target_id == -1:
			continue
		var shader_material := _get_cached_shader_material(target_id)
		if shader_material == null:
			continue
		shader_material.set_shader_parameter(PARAM_FADE_ALPHA, resolved_alpha)

func restore_original_materials(targets: Array) -> void:
	for target_variant in targets:
		_restore_target_material(target_variant)
	_prune_invalid_cache_entries()

func get_cached_mesh_count() -> int:
	_prune_invalid_cache_entries()
	return _material_cache.size()

func _apply_mesh_fade_material(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance == null or not is_instance_valid(mesh_instance):
		return
	if mesh_instance.mesh == null:
		return
	if _material_cache.has(mesh_instance.get_instance_id()):
		return

	var source_material := _resolve_mesh_source_material(mesh_instance)
	var albedo_texture: Texture2D = _extract_albedo_texture(source_material)
	var shader_material := _ensure_mesh_shader_material(mesh_instance)
	if shader_material == null:
		return
	_configure_shader_material(shader_material, albedo_texture)
	mesh_instance.material_override = shader_material

func _apply_csg_fade_material(csg_shape: CSGShape3D) -> void:
	if csg_shape == null or not is_instance_valid(csg_shape):
		return
	if _material_cache.has(csg_shape.get_instance_id()):
		return

	var source_material := _resolve_csg_source_material(csg_shape)
	var albedo_texture: Texture2D = _extract_albedo_texture(source_material)
	var shader_material := _ensure_csg_shader_material(csg_shape)
	if shader_material == null:
		return
	_configure_shader_material(shader_material, albedo_texture)
	csg_shape.material = shader_material

func _configure_shader_material(shader_material: ShaderMaterial, albedo_texture: Texture2D) -> void:
	shader_material.set_shader_parameter(PARAM_ALBEDO_TEXTURE, albedo_texture)
	shader_material.set_shader_parameter(PARAM_ALBEDO_COLOR, Color(1.0, 1.0, 1.0, 1.0))
	shader_material.set_shader_parameter(PARAM_FADE_ALPHA, 1.0)

func _resolve_mesh_source_material(mesh_instance: MeshInstance3D) -> Material:
	var cache_entry: Dictionary = _get_cached_entry(mesh_instance)
	if not cache_entry.is_empty():
		var original_override_variant: Variant = cache_entry.get("original_material_override", null)
		if original_override_variant is Material:
			return original_override_variant as Material

	if mesh_instance.material_override != null:
		return mesh_instance.material_override

	var mesh_resource := mesh_instance.mesh
	if mesh_resource == null:
		return null

	var surface_count: int = mesh_resource.get_surface_count()
	for surface_idx in surface_count:
		var override_material := mesh_instance.get_surface_override_material(surface_idx)
		if override_material != null:
			return override_material
		var surface_material := mesh_resource.surface_get_material(surface_idx)
		if surface_material != null:
			return surface_material
	return null

func _resolve_csg_source_material(csg_shape: CSGShape3D) -> Material:
	var cache_entry: Dictionary = _get_cached_entry(csg_shape)
	if not cache_entry.is_empty():
		var original_material_variant: Variant = cache_entry.get("original_material", null)
		if original_material_variant is Material:
			return original_material_variant as Material
	if csg_shape.material is Material:
		return csg_shape.material as Material
	return null

func _extract_albedo_texture(source_material: Material) -> Texture2D:
	if source_material == null:
		return null
	if source_material is BaseMaterial3D:
		return (source_material as BaseMaterial3D).albedo_texture

	if source_material is ShaderMaterial:
		var shader_material := source_material as ShaderMaterial
		var texture_variant: Variant = shader_material.get_shader_parameter(PARAM_ALBEDO_TEXTURE)
		if texture_variant is Texture2D:
			return texture_variant as Texture2D

	return null

func _ensure_mesh_shader_material(mesh_instance: MeshInstance3D) -> ShaderMaterial:
	var cache_key: int = mesh_instance.get_instance_id()
	var entry := _get_cached_entry(mesh_instance)
	if not entry.is_empty():
		var existing_shader_variant: Variant = entry.get("shader_material", null)
		if existing_shader_variant is ShaderMaterial:
			return existing_shader_variant as ShaderMaterial

	var shader_material := ShaderMaterial.new()
	shader_material.shader = _shader
	_material_cache[cache_key] = {
		"target_ref": weakref(mesh_instance),
		"target_type": TARGET_TYPE_MESH,
		"original_material_override": mesh_instance.material_override,
		"shader_material": shader_material,
	}
	return shader_material

func _ensure_csg_shader_material(csg_shape: CSGShape3D) -> ShaderMaterial:
	var cache_key: int = csg_shape.get_instance_id()
	var entry := _get_cached_entry(csg_shape)
	if not entry.is_empty():
		var existing_shader_variant: Variant = entry.get("shader_material", null)
		if existing_shader_variant is ShaderMaterial:
			return existing_shader_variant as ShaderMaterial

	var shader_material := ShaderMaterial.new()
	shader_material.shader = _shader
	_material_cache[cache_key] = {
		"target_ref": weakref(csg_shape),
		"target_type": TARGET_TYPE_CSG,
		"original_material": csg_shape.material,
		"shader_material": shader_material,
	}
	return shader_material

func _get_cached_shader_material(cache_key: int) -> ShaderMaterial:
	var entry: Dictionary = _get_cached_entry_by_key(cache_key)
	if entry.is_empty():
		return null
	var material_variant: Variant = entry.get("shader_material", null)
	if material_variant is ShaderMaterial:
		return material_variant as ShaderMaterial
	return null

func _get_cached_entry(target: Node3D) -> Dictionary:
	if target == null:
		return {}
	return _get_cached_entry_by_key(target.get_instance_id())

func _get_cached_entry_by_key(cache_key: int) -> Dictionary:
	var entry_variant: Variant = _material_cache.get(cache_key, null)
	if entry_variant is Dictionary:
		return entry_variant as Dictionary
	return {}

func _restore_target_material(target_variant: Variant) -> void:
	if target_variant is MeshInstance3D:
		_restore_mesh_material(target_variant as MeshInstance3D)
		return
	if target_variant is CSGShape3D:
		_restore_csg_material(target_variant as CSGShape3D)

func _restore_mesh_material(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance == null or not is_instance_valid(mesh_instance):
		return
	var cache_key: int = mesh_instance.get_instance_id()
	var entry: Dictionary = _get_cached_entry_by_key(cache_key)
	if entry.is_empty():
		return
	mesh_instance.material_override = entry.get("original_material_override", null)
	_material_cache.erase(cache_key)

func _restore_csg_material(csg_shape: CSGShape3D) -> void:
	if csg_shape == null or not is_instance_valid(csg_shape):
		return
	var cache_key: int = csg_shape.get_instance_id()
	var entry: Dictionary = _get_cached_entry_by_key(cache_key)
	if entry.is_empty():
		return
	csg_shape.material = entry.get("original_material", null)
	_material_cache.erase(cache_key)

func _prune_invalid_cache_entries() -> void:
	var stale_keys: Array[int] = []
	var keys: Array = _material_cache.keys()
	for key_variant in keys:
		var cache_key: int = int(key_variant)
		if _get_cached_target(cache_key) == null:
			stale_keys.append(cache_key)
	for cache_key in stale_keys:
		_material_cache.erase(cache_key)

func _get_cached_target(cache_key: int) -> Node3D:
	var entry_variant: Variant = _material_cache.get(cache_key, null)
	if not (entry_variant is Dictionary):
		return null
	var entry := entry_variant as Dictionary
	var target_ref_variant: Variant = entry.get("target_ref", null)
	if not (target_ref_variant is WeakRef):
		return null
	var resolved_variant: Variant = (target_ref_variant as WeakRef).get_ref()
	if not (resolved_variant is Node3D):
		return null
	var target := resolved_variant as Node3D
	if not is_instance_valid(target):
		return null
	return target

func _resolve_target_id(target_variant: Variant) -> int:
	if target_variant is MeshInstance3D:
		var mesh_instance := target_variant as MeshInstance3D
		if mesh_instance != null and is_instance_valid(mesh_instance):
			return mesh_instance.get_instance_id()
	if target_variant is CSGShape3D:
		var csg_shape := target_variant as CSGShape3D
		if csg_shape != null and is_instance_valid(csg_shape):
			return csg_shape.get_instance_id()
	return -1
