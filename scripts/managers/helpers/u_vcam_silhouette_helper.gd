extends RefCounted
class_name U_VCamSilhouetteHelper

const DEFAULT_SILHOUETTE_TRANSPARENCY := 0.7

var _tracked_targets: Dictionary = {}

func apply_silhouette(target_variant: Variant) -> void:
	var target: GeometryInstance3D = _resolve_live_geometry(target_variant)
	if target == null:
		return
	_prune_invalid_targets()

	var target_id: int = target.get_instance_id()
	if _tracked_targets.has(target_id):
		return

	_tracked_targets[target_id] = {
		"target_ref": weakref(target),
		"original_transparency": target.transparency,
	}
	target.transparency = DEFAULT_SILHOUETTE_TRANSPARENCY

func remove_silhouette(target_variant: Variant) -> void:
	var target: GeometryInstance3D = _resolve_live_geometry(target_variant)
	if target == null:
		return
	var target_id: int = target.get_instance_id()
	var entry: Dictionary = _get_entry(target_id)
	if entry.is_empty():
		return

	if is_instance_valid(target):
		target.transparency = float(entry.get("original_transparency", 0.0))
	_tracked_targets.erase(target_id)

func remove_all_silhouettes() -> void:
	var target_ids: Array = _tracked_targets.keys()
	for target_id_variant in target_ids:
		var target_id: int = int(target_id_variant)
		var entry: Dictionary = _get_entry(target_id)
		if entry.is_empty():
			_tracked_targets.erase(target_id)
			continue
		var target: GeometryInstance3D = _resolve_target(entry)
		if target != null:
			target.transparency = float(entry.get("original_transparency", 0.0))
		_tracked_targets.erase(target_id)

func get_active_count() -> int:
	_prune_invalid_targets()
	return _tracked_targets.size()

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
