extends RefCounted
class_name U_VCamSilhouetteHelper

const SH_VCAM_SILHOUETTE := preload("res://assets/shaders/sh_vcam_silhouette_shader.gdshader")
const TARGET_TYPE_GEOMETRY := "geometry"
const TARGET_TYPE_CSG := "csg"

var _tracked_targets: Dictionary = {}
var _shader: Shader = SH_VCAM_SILHOUETTE

func apply_silhouette(target_variant: Variant) -> void:
	var target: GeometryInstance3D = _resolve_live_geometry(target_variant)
	if target == null:
		return
	if _has_foreign_shader_material(target):
		return
	_prune_invalid_targets()

	var target_id: int = target.get_instance_id()
	var entry: Dictionary = _get_entry(target_id)
	if entry.is_empty():
		entry = _create_entry(target)
		_tracked_targets[target_id] = entry

	var shader_material: ShaderMaterial = entry.get("shader_material", null) as ShaderMaterial
	if shader_material == null:
		return
	_apply_shader_material(target, shader_material)

func remove_silhouette(target_variant: Variant) -> void:
	var target: GeometryInstance3D = _resolve_live_geometry(target_variant)
	if target == null:
		return
	var target_id: int = target.get_instance_id()
	var entry: Dictionary = _get_entry(target_id)
	if entry.is_empty():
		return

	if is_instance_valid(target):
		_restore_original_material(target, entry)
	_tracked_targets.erase(target_id)

func remove_all_silhouettes() -> void:
	var target_ids: Array = _tracked_targets.keys()
	for target_id_variant in target_ids:
		var target_id: int = int(target_id_variant)
		var entry: Dictionary = _get_entry(target_id)
		if entry.is_empty():
			continue
		var target: GeometryInstance3D = _resolve_target(entry)
		if target != null:
			_restore_original_material(target, entry)
		_tracked_targets.erase(target_id)

func get_active_count() -> int:
	_prune_invalid_targets()
	return _tracked_targets.size()

func _create_entry(target: GeometryInstance3D) -> Dictionary:
	var shader_material := ShaderMaterial.new()
	shader_material.shader = _shader

	var target_type: String = TARGET_TYPE_GEOMETRY
	var original_csg_material: Material = null
	var csg := target as CSGShape3D
	if csg != null:
		target_type = TARGET_TYPE_CSG
		original_csg_material = csg.material

	return {
		"target_ref": weakref(target),
		"target_type": target_type,
		"shader_material": shader_material,
		"original_material_override": target.material_override,
		"original_csg_material": original_csg_material,
	}

func _apply_shader_material(target: GeometryInstance3D, shader_material: ShaderMaterial) -> void:
	var csg := target as CSGShape3D
	if csg != null:
		csg.material = shader_material
		return
	target.material_override = shader_material

func _restore_original_material(target: GeometryInstance3D, entry: Dictionary) -> void:
	var target_type: String = String(entry.get("target_type", TARGET_TYPE_GEOMETRY))
	if target_type == TARGET_TYPE_CSG:
		var csg := target as CSGShape3D
		if csg != null:
			var original_csg: Variant = entry.get("original_csg_material", null)
			csg.material = original_csg as Material
		target.material_override = entry.get("original_material_override", null) as Material
		return
	target.material_override = entry.get("original_material_override", null) as Material

func _prune_invalid_targets() -> void:
	var stale_ids: Array[int] = []
	var target_ids: Array = _tracked_targets.keys()
	for target_id_variant in target_ids:
		var target_id: int = int(target_id_variant)
		var entry: Dictionary = _get_entry(target_id)
		if entry.is_empty():
			stale_ids.append(target_id)
			continue
		if _resolve_target(entry) == null:
			stale_ids.append(target_id)

	for target_id in stale_ids:
		_tracked_targets.erase(target_id)

func _get_entry(target_id: int) -> Dictionary:
	var entry_variant: Variant = _tracked_targets.get(target_id, null)
	if entry_variant is Dictionary:
		return entry_variant as Dictionary
	return {}

func _resolve_target(entry: Dictionary) -> GeometryInstance3D:
	var target_ref_variant: Variant = entry.get("target_ref", null)
	if not (target_ref_variant is WeakRef):
		return null
	var target_variant: Variant = (target_ref_variant as WeakRef).get_ref()
	if not (target_variant is GeometryInstance3D):
		return null
	var target := target_variant as GeometryInstance3D
	if target == null or not is_instance_valid(target):
		return null
	return target

func _resolve_live_geometry(target_variant: Variant) -> GeometryInstance3D:
	if typeof(target_variant) != TYPE_OBJECT:
		return null
	if target_variant == null:
		return null
	if not is_instance_valid(target_variant):
		return null
	if not (target_variant is GeometryInstance3D):
		return null
	return target_variant as GeometryInstance3D

func _has_foreign_shader_material(target: GeometryInstance3D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var csg := target as CSGShape3D
	if csg != null:
		if csg.material is ShaderMaterial:
			var shader_mat := csg.material as ShaderMaterial
			if shader_mat.shader != _shader:
				return true
		return false
	if target.material_override is ShaderMaterial:
		var shader_mat := target.material_override as ShaderMaterial
		if shader_mat.shader != _shader:
			return true
	return false
