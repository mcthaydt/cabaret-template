extends RefCounted
class_name U_CharacterLightingMaterialApplier

const SH_CHARACTER_ZONE_LIGHTING := preload("res://assets/shaders/sh_character_zone_lighting.gdshader")

const PARAM_ALBEDO_TEXTURE := "albedo_texture"
const PARAM_BASE_TINT := "base_tint"
const PARAM_EFFECTIVE_TINT := "effective_tint"
const PARAM_EFFECTIVE_INTENSITY := "effective_intensity"
const MIN_INTENSITY := 0.0
const MAX_INTENSITY := 8.0

var _material_cache: Dictionary = {}
var _shader: Shader = SH_CHARACTER_ZONE_LIGHTING

func collect_mesh_targets(character_entity: Node) -> Array[MeshInstance3D]:
	var targets: Array[MeshInstance3D] = []
	if character_entity == null or not is_instance_valid(character_entity):
		return targets
	_collect_mesh_targets_recursive(character_entity, targets)
	return targets

func apply_character_lighting(
	character_entity: Node,
	base_tint: Color,
	effective_tint: Color,
	effective_intensity: float
) -> void:
	_prune_invalid_cache_entries()
	var targets := collect_mesh_targets(character_entity)
	for mesh_instance in targets:
		_apply_mesh_override(mesh_instance, base_tint, effective_tint, effective_intensity)

func restore_character_materials(character_entity: Node) -> void:
	var targets := collect_mesh_targets(character_entity)
	for mesh_instance in targets:
		_restore_mesh(mesh_instance)
	_prune_invalid_cache_entries()

func restore_all_materials() -> void:
	var keys: Array = _material_cache.keys()
	for key_variant in keys:
		var cache_key: int = int(key_variant)
		var mesh_instance := _get_cached_mesh(cache_key)
		if mesh_instance == null:
			continue
		var entry_variant: Variant = _material_cache.get(cache_key, null)
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		mesh_instance.material_override = entry.get("original_material_override", null)
	_material_cache.clear()

func get_cached_mesh_count() -> int:
	_prune_invalid_cache_entries()
	return _material_cache.size()

func _collect_mesh_targets_recursive(node: Node, targets: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			targets.append(mesh_instance)

	var children: Array = node.get_children()
	for child_variant in children:
		if child_variant is Node:
			_collect_mesh_targets_recursive(child_variant as Node, targets)

func _apply_mesh_override(
	mesh_instance: MeshInstance3D,
	base_tint: Color,
	effective_tint: Color,
	effective_intensity: float
) -> void:
	if mesh_instance == null or not is_instance_valid(mesh_instance):
		return
	if mesh_instance.mesh == null:
		return

	var source_material := _resolve_source_material(mesh_instance)
	if source_material == null:
		return

	var albedo_texture := _extract_albedo_texture(source_material)
	if albedo_texture == null:
		return

	var shader_material := _ensure_shader_material(mesh_instance)
	if shader_material == null:
		return

	shader_material.set_shader_parameter(PARAM_ALBEDO_TEXTURE, albedo_texture)
	shader_material.set_shader_parameter(PARAM_BASE_TINT, base_tint)
	shader_material.set_shader_parameter(PARAM_EFFECTIVE_TINT, effective_tint)
	shader_material.set_shader_parameter(
		PARAM_EFFECTIVE_INTENSITY,
		clampf(effective_intensity, MIN_INTENSITY, MAX_INTENSITY)
	)
	mesh_instance.material_override = shader_material

func _resolve_source_material(mesh_instance: MeshInstance3D) -> Material:
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

func _extract_albedo_texture(source_material: Material) -> Texture2D:
	if source_material is BaseMaterial3D:
		var base_material := source_material as BaseMaterial3D
		return base_material.albedo_texture

	if source_material is ShaderMaterial:
		var shader_material := source_material as ShaderMaterial
		var texture_variant: Variant = shader_material.get_shader_parameter(PARAM_ALBEDO_TEXTURE)
		if texture_variant is Texture2D:
			return texture_variant as Texture2D
	return null

func _ensure_shader_material(mesh_instance: MeshInstance3D) -> ShaderMaterial:
	var cache_key: int = mesh_instance.get_instance_id()
	var entry_variant: Variant = _material_cache.get(cache_key, null)
	if entry_variant is Dictionary:
		var existing_entry := entry_variant as Dictionary
		var shader_material_variant: Variant = existing_entry.get("shader_material", null)
		if shader_material_variant is ShaderMaterial:
			return shader_material_variant as ShaderMaterial

	var shader_material := ShaderMaterial.new()
	shader_material.shader = _shader
	_material_cache[cache_key] = {
		"mesh_ref": weakref(mesh_instance),
		"original_material_override": mesh_instance.material_override,
		"shader_material": shader_material,
	}
	return shader_material

func _restore_mesh(mesh_instance: MeshInstance3D) -> void:
	var cache_key: int = mesh_instance.get_instance_id()
	var entry_variant: Variant = _material_cache.get(cache_key, null)
	if not (entry_variant is Dictionary):
		return
	var entry := entry_variant as Dictionary
	mesh_instance.material_override = entry.get("original_material_override", null)
	_material_cache.erase(cache_key)

func _prune_invalid_cache_entries() -> void:
	var stale_keys: Array[int] = []
	var keys: Array = _material_cache.keys()
	for key_variant in keys:
		var cache_key: int = int(key_variant)
		if _get_cached_mesh(cache_key) == null:
			stale_keys.append(cache_key)
	for cache_key in stale_keys:
		_material_cache.erase(cache_key)

func _get_cached_mesh(cache_key: int) -> MeshInstance3D:
	var entry_variant: Variant = _material_cache.get(cache_key, null)
	if not (entry_variant is Dictionary):
		return null
	var entry := entry_variant as Dictionary
	var mesh_ref_variant: Variant = entry.get("mesh_ref", null)
	if not (mesh_ref_variant is WeakRef):
		return null
	var resolved_variant: Variant = (mesh_ref_variant as WeakRef).get_ref()
	if not (resolved_variant is MeshInstance3D):
		return null
	var mesh_instance := resolved_variant as MeshInstance3D
	if not is_instance_valid(mesh_instance):
		return null
	return mesh_instance
