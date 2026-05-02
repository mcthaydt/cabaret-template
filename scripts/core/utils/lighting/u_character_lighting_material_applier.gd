extends RefCounted
class_name U_CharacterLightingMaterialApplier

const SH_CHARACTER_ZONE_LIGHTING := preload("res://assets/core/shaders/sh_character_zone_lighting.gdshader")
const SH_SPRITE_ZONE_LIGHTING := preload("res://assets/core/shaders/sh_sprite_zone_lighting.gdshader")

const PARAM_ALBEDO_TEXTURE := "albedo_texture"
const PARAM_BASE_TINT := "base_tint"
const PARAM_EFFECTIVE_TINT := "effective_tint"
const PARAM_EFFECTIVE_INTENSITY := "effective_intensity"
const MIN_INTENSITY := 0.0
const MAX_INTENSITY := 8.0

var _material_cache: Dictionary = {}
var _shader: Shader = SH_CHARACTER_ZONE_LIGHTING
var _sprite_shader: Shader = SH_SPRITE_ZONE_LIGHTING
var _fallback_white_texture: ImageTexture = null

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

func apply_sprite_lighting(
	character_entity: Node,
	base_tint: Color,
	effective_tint: Color,
	effective_intensity: float
) -> void:
	_prune_invalid_cache_entries()
	var targets := collect_sprite_targets(character_entity)
	for sprite in targets:
		_apply_sprite_override(sprite, base_tint, effective_tint, effective_intensity)

func _apply_sprite_override(
	sprite: Sprite3D,
	base_tint: Color,
	effective_tint: Color,
	effective_intensity: float
) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	if sprite.texture == null:
		return

	var albedo_texture: Texture2D = sprite.texture

	var shader_material := _ensure_sprite_shader_material(sprite)
	if shader_material == null:
		return

	shader_material.set_shader_parameter(PARAM_ALBEDO_TEXTURE, albedo_texture)
	shader_material.set_shader_parameter(PARAM_BASE_TINT, base_tint)
	shader_material.set_shader_parameter(PARAM_EFFECTIVE_TINT, effective_tint)
	shader_material.set_shader_parameter(
		PARAM_EFFECTIVE_INTENSITY,
		clampf(effective_intensity, MIN_INTENSITY, MAX_INTENSITY)
	)
	sprite.material_override = shader_material

func _ensure_sprite_shader_material(sprite: Sprite3D) -> ShaderMaterial:
	var cache_key: int = sprite.get_instance_id()
	var entry_variant: Variant = _material_cache.get(cache_key, null)
	if entry_variant is Dictionary:
		var existing_entry := entry_variant as Dictionary
		var shader_material_variant: Variant = existing_entry.get("shader_material", null)
		if shader_material_variant is ShaderMaterial:
			return shader_material_variant as ShaderMaterial

	var shader_material := ShaderMaterial.new()
	shader_material.shader = _sprite_shader
	_material_cache[cache_key] = {
		"mesh_ref": weakref(sprite),
		"original_material_override": sprite.material_override,
		"shader_material": shader_material,
	}
	return shader_material

func restore_character_materials(character_entity: Node) -> void:
	var targets := collect_mesh_targets(character_entity)
	for mesh_instance in targets:
		_restore_mesh(mesh_instance)
	_prune_invalid_cache_entries()

func restore_sprite_materials(character_entity: Node) -> void:
	var targets := collect_sprite_targets(character_entity)
	for sprite in targets:
		_restore_sprite(sprite)
	_prune_invalid_cache_entries()

func _restore_sprite(sprite: Sprite3D) -> void:
	var cache_key: int = sprite.get_instance_id()
	var entry_variant: Variant = _material_cache.get(cache_key, null)
	if not (entry_variant is Dictionary):
		return
	var entry := entry_variant as Dictionary
	sprite.material_override = entry.get("original_material_override", null)
	_material_cache.erase(cache_key)

func restore_all_materials() -> void:
	var keys: Array = _material_cache.keys()
	for key_variant in keys:
		var cache_key: int = int(key_variant)
		var node := _get_cached_node(cache_key)
		if node == null:
			continue
		var entry_variant: Variant = _material_cache.get(cache_key, null)
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		node.set("material_override", entry.get("original_material_override", null))
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

func collect_sprite_targets(character_entity: Node) -> Array[Sprite3D]:
	var targets: Array[Sprite3D] = []
	if character_entity == null or not is_instance_valid(character_entity):
		return targets
	_collect_sprite_targets_recursive(character_entity, targets)
	return targets

func _collect_sprite_targets_recursive(node: Node, targets: Array[Sprite3D]) -> void:
	if node is Sprite3D:
		var sprite := node as Sprite3D
		if sprite.texture != null and sprite.name != &"GroundIndicator":
			targets.append(sprite)

	var children: Array = node.get_children()
	for child_variant in children:
		if child_variant is Node:
			_collect_sprite_targets_recursive(child_variant as Node, targets)

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
	var albedo_color := _extract_albedo_color(source_material)

	# When no texture exists (e.g. albedo_color-only materials like E_Sentry),
	# use a white fallback so the shader still runs and applies zone lighting.
	if albedo_texture == null:
		albedo_texture = _get_fallback_white_texture()

	# Forward the original albedo_color as base_tint so color-only materials
	# are preserved when the shader replaces the source material.
	var resolved_base_tint := base_tint
	if albedo_color != Color.WHITE:
		resolved_base_tint = albedo_color

	var shader_material := _ensure_shader_material(mesh_instance)
	if shader_material == null:
		return

	shader_material.set_shader_parameter(PARAM_ALBEDO_TEXTURE, albedo_texture)
	shader_material.set_shader_parameter(PARAM_BASE_TINT, resolved_base_tint)
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


func _extract_albedo_color(source_material: Material) -> Color:
	if source_material is BaseMaterial3D:
		var base_material := source_material as BaseMaterial3D
		return base_material.albedo_color

	if source_material is ShaderMaterial:
		var shader_material := source_material as ShaderMaterial
		var color_variant: Variant = shader_material.get_shader_parameter(PARAM_BASE_TINT)
		if color_variant is Color:
			return color_variant as Color

	return Color.WHITE


func _get_fallback_white_texture() -> ImageTexture:
	if _fallback_white_texture != null and is_instance_valid(_fallback_white_texture):
		return _fallback_white_texture
	var image := Image.create(1, 1, false, Image.FORMAT_RGB8)
	image.fill(Color.WHITE)
	_fallback_white_texture = ImageTexture.create_from_image(image)
	return _fallback_white_texture

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

func _restore_mesh(node: Node) -> void:
	var cache_key: int = node.get_instance_id()
	var entry_variant: Variant = _material_cache.get(cache_key, null)
	if not (entry_variant is Dictionary):
		return
	var entry := entry_variant as Dictionary
	node.set("material_override", entry.get("original_material_override", null))
	_material_cache.erase(cache_key)

func _prune_invalid_cache_entries() -> void:
	var stale_keys: Array[int] = []
	var keys: Array = _material_cache.keys()
	for key_variant in keys:
		var cache_key: int = int(key_variant)
		if _get_cached_node(cache_key) == null:
			stale_keys.append(cache_key)
	for cache_key in stale_keys:
		_material_cache.erase(cache_key)

func _get_cached_node(cache_key: int) -> Node:
	var entry_variant: Variant = _material_cache.get(cache_key, null)
	if not (entry_variant is Dictionary):
		return null
	var entry := entry_variant as Dictionary
	var ref_key := "mesh_ref"
	var ref_variant: Variant = entry.get(ref_key, null)
	if not (ref_variant is WeakRef):
		return null
	var resolved_variant: Variant = (ref_variant as WeakRef).get_ref()
	if not (resolved_variant is Node):
		return null
	var node := resolved_variant as Node
	if not is_instance_valid(node):
		return null
	return node
