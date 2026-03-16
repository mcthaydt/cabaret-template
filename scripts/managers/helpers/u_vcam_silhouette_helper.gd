extends RefCounted
class_name U_VCamSilhouetteHelper

const SH_VCAM_SILHOUETTE := preload("res://assets/shaders/sh_vcam_silhouette_shader.gdshader")
const RENDER_PRIORITY := 10

var _tracked_entities: Dictionary = {}
var _shader: Shader = SH_VCAM_SILHOUETTE

func apply_silhouette(entity_root: Node) -> void:
	if entity_root == null or not is_instance_valid(entity_root):
		return

	var entity_id: int = entity_root.get_instance_id()
	if _tracked_entities.has(entity_id):
		return

	var mesh_targets: Array[MeshInstance3D] = _collect_mesh_targets(entity_root)
	if mesh_targets.is_empty():
		return

	var mesh_entries: Array[Dictionary] = []
	for mesh_instance in mesh_targets:
		var shader_material := ShaderMaterial.new()
		shader_material.shader = _shader
		shader_material.render_priority = RENDER_PRIORITY

		var entry: Dictionary = {
			"mesh_ref": weakref(mesh_instance),
			"shader_material": shader_material,
			"original_overlay": mesh_instance.material_overlay,
		}
		mesh_entries.append(entry)
		mesh_instance.material_overlay = shader_material

	_tracked_entities[entity_id] = {
		"entity_ref": weakref(entity_root),
		"mesh_entries": mesh_entries,
	}

func remove_silhouette(entity_root: Node) -> void:
	if entity_root == null or not is_instance_valid(entity_root):
		return

	var entity_id: int = entity_root.get_instance_id()
	var entity_data_variant: Variant = _tracked_entities.get(entity_id, null)
	if not (entity_data_variant is Dictionary):
		return
	var entity_data := entity_data_variant as Dictionary

	var mesh_entries_variant: Variant = entity_data.get("mesh_entries", [])
	if mesh_entries_variant is Array:
		var mesh_entries: Array = mesh_entries_variant as Array
		for entry_variant in mesh_entries:
			if not (entry_variant is Dictionary):
				continue
			var entry := entry_variant as Dictionary
			var mesh_ref_variant: Variant = entry.get("mesh_ref", null)
			if not (mesh_ref_variant is WeakRef):
				continue
			var mesh_variant: Variant = (mesh_ref_variant as WeakRef).get_ref()
			if mesh_variant is MeshInstance3D and is_instance_valid(mesh_variant):
				var mesh := mesh_variant as MeshInstance3D
				mesh.material_overlay = entry.get("original_overlay", null)

	_tracked_entities.erase(entity_id)

func remove_all_silhouettes() -> void:
	var entity_ids: Array = _tracked_entities.keys()
	for entity_id_variant in entity_ids:
		var entity_id: int = int(entity_id_variant)
		var entity_data_variant: Variant = _tracked_entities.get(entity_id, null)
		if not (entity_data_variant is Dictionary):
			_tracked_entities.erase(entity_id)
			continue
		var entity_data := entity_data_variant as Dictionary
		var mesh_entries_variant: Variant = entity_data.get("mesh_entries", [])
		if mesh_entries_variant is Array:
			var mesh_entries: Array = mesh_entries_variant as Array
			for entry_variant in mesh_entries:
				if not (entry_variant is Dictionary):
					continue
				var entry := entry_variant as Dictionary
				var mesh_ref_variant: Variant = entry.get("mesh_ref", null)
				if not (mesh_ref_variant is WeakRef):
					continue
				var mesh_variant: Variant = (mesh_ref_variant as WeakRef).get_ref()
				if mesh_variant is MeshInstance3D and is_instance_valid(mesh_variant):
					var mesh := mesh_variant as MeshInstance3D
					mesh.material_overlay = entry.get("original_overlay", null)
		_tracked_entities.erase(entity_id)

func get_active_count() -> int:
	_prune_invalid_entries()
	var count: int = 0
	for entity_id_variant in _tracked_entities.keys():
		var entity_data_variant: Variant = _tracked_entities.get(int(entity_id_variant), null)
		if not (entity_data_variant is Dictionary):
			continue
		var entity_data := entity_data_variant as Dictionary
		var mesh_entries_variant: Variant = entity_data.get("mesh_entries", [])
		if mesh_entries_variant is Array:
			count += (mesh_entries_variant as Array).size()
	return count

func _collect_mesh_targets(node: Node) -> Array[MeshInstance3D]:
	var targets: Array[MeshInstance3D] = []
	if node == null or not is_instance_valid(node):
		return targets
	_collect_mesh_targets_recursive(node, targets)
	return targets

func _collect_mesh_targets_recursive(node: Node, targets: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			targets.append(mesh_instance)

	var children: Array = node.get_children()
	for child_variant in children:
		if child_variant is Node:
			_collect_mesh_targets_recursive(child_variant as Node, targets)

func _prune_invalid_entries() -> void:
	var stale_ids: Array[int] = []
	for entity_id_variant in _tracked_entities.keys():
		var entity_id: int = int(entity_id_variant)
		var entity_data_variant: Variant = _tracked_entities.get(entity_id, null)
		if not (entity_data_variant is Dictionary):
			stale_ids.append(entity_id)
			continue
		var entity_data := entity_data_variant as Dictionary
		var entity_ref_variant: Variant = entity_data.get("entity_ref", null)
		if not (entity_ref_variant is WeakRef):
			stale_ids.append(entity_id)
			continue
		var entity_variant: Variant = (entity_ref_variant as WeakRef).get_ref()
		if entity_variant == null or not is_instance_valid(entity_variant):
			stale_ids.append(entity_id)
			continue

		var mesh_entries_variant: Variant = entity_data.get("mesh_entries", [])
		if not (mesh_entries_variant is Array):
			stale_ids.append(entity_id)
			continue
		var mesh_entries: Array = mesh_entries_variant as Array
		var valid_entries: Array[Dictionary] = []
		for entry_variant in mesh_entries:
			if not (entry_variant is Dictionary):
				continue
			var entry := entry_variant as Dictionary
			var mesh_ref_variant: Variant = entry.get("mesh_ref", null)
			if not (mesh_ref_variant is WeakRef):
				continue
			var mesh_variant: Variant = (mesh_ref_variant as WeakRef).get_ref()
			if mesh_variant is MeshInstance3D and is_instance_valid(mesh_variant):
				valid_entries.append(entry)
		if valid_entries.is_empty():
			stale_ids.append(entity_id)
		else:
			entity_data["mesh_entries"] = valid_entries

	for entity_id in stale_ids:
		_tracked_entities.erase(entity_id)
