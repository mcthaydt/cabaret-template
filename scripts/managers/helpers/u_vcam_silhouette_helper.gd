extends RefCounted
class_name U_VCamSilhouetteHelper

const DEFAULT_SILHOUETTE_TRANSPARENCY := 0.7
const APPLY_DEBOUNCE_FRAMES := 2
const REMOVE_GRACE_FRAMES := 1

var _tracked_targets: Dictionary = {}

func apply_silhouette(target_variant: Variant) -> void:
	var target: GeometryInstance3D = _resolve_live_geometry(target_variant)
	if target == null:
		return
	_prune_invalid_targets()

	var target_id: int = target.get_instance_id()
	var entry: Dictionary = _get_entry(target_id)
	if not entry.is_empty() and bool(entry.get("is_applied", false)):
		return

	if entry.is_empty():
		entry = _build_entry(target)
	else:
		entry["target_ref"] = weakref(target)
		if not entry.has("original_transparency"):
			entry["original_transparency"] = target.transparency

	entry["seen_frames"] = APPLY_DEBOUNCE_FRAMES
	entry["missing_frames"] = 0
	entry["is_applied"] = true
	_tracked_targets[target_id] = entry
	target.transparency = DEFAULT_SILHOUETTE_TRANSPARENCY

func remove_silhouette(target_variant: Variant) -> void:
	var target: GeometryInstance3D = _resolve_live_geometry(target_variant)
	if target == null:
		return
	var target_id: int = target.get_instance_id()
	var entry: Dictionary = _get_entry(target_id)
	if entry.is_empty():
		return

	if is_instance_valid(target) and bool(entry.get("is_applied", false)):
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
		if target != null and bool(entry.get("is_applied", false)):
			target.transparency = float(entry.get("original_transparency", 0.0))
		_tracked_targets.erase(target_id)

func update_silhouettes(occluders_variant: Variant, enabled: bool = true) -> void:
	if not enabled:
		remove_all_silhouettes()
		return

	_prune_invalid_targets()
	var active_targets: Dictionary = _collect_unique_live_targets(occluders_variant)
	var seen_ids: Dictionary = {}

	for target_id_variant in active_targets.keys():
		var target_id: int = int(target_id_variant)
		var target: GeometryInstance3D = active_targets.get(target_id_variant, null) as GeometryInstance3D
		if target == null or not is_instance_valid(target):
			continue
		seen_ids[target_id] = true

		var entry: Dictionary = _get_entry(target_id)
		if entry.is_empty():
			entry = _build_entry(target)
		else:
			entry["target_ref"] = weakref(target)

		var next_seen_frames: int = int(entry.get("seen_frames", 0)) + 1
		entry["seen_frames"] = next_seen_frames
		entry["missing_frames"] = 0

		var is_applied: bool = bool(entry.get("is_applied", false))
		if not is_applied and next_seen_frames >= APPLY_DEBOUNCE_FRAMES:
			entry["is_applied"] = true
			target.transparency = DEFAULT_SILHOUETTE_TRANSPARENCY

		_tracked_targets[target_id] = entry

	var stale_ids: Array[int] = []
	for target_id_variant in _tracked_targets.keys():
		var target_id: int = int(target_id_variant)
		if seen_ids.has(target_id):
			continue
		var entry: Dictionary = _get_entry(target_id)
		if entry.is_empty():
			stale_ids.append(target_id)
			continue
		entry["seen_frames"] = 0
		var next_missing_frames: int = int(entry.get("missing_frames", 0)) + 1
		entry["missing_frames"] = next_missing_frames
		var should_remove: bool = next_missing_frames > REMOVE_GRACE_FRAMES
		if should_remove:
			_restore_entry(entry)
			stale_ids.append(target_id)
			continue
		_tracked_targets[target_id] = entry

	for target_id in stale_ids:
		_tracked_targets.erase(target_id)

func get_active_count() -> int:
	_prune_invalid_targets()
	var active_count: int = 0
	for entry_variant in _tracked_targets.values():
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		if bool(entry.get("is_applied", false)):
			active_count += 1
	return active_count

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

func _collect_unique_live_targets(occluders_variant: Variant) -> Dictionary:
	var unique_targets: Dictionary = {}
	if not (occluders_variant is Array):
		return unique_targets

	for target_variant in occluders_variant as Array:
		var target: GeometryInstance3D = _resolve_live_geometry(target_variant)
		if target == null:
			continue
		var target_id: int = target.get_instance_id()
		if unique_targets.has(target_id):
			continue
		unique_targets[target_id] = target
	return unique_targets

func _build_entry(target: GeometryInstance3D) -> Dictionary:
	return {
		"target_ref": weakref(target),
		"original_transparency": target.transparency,
		"is_applied": false,
		"seen_frames": 0,
		"missing_frames": 0,
	}

func _restore_entry(entry: Dictionary) -> void:
	if not bool(entry.get("is_applied", false)):
		return
	var target: GeometryInstance3D = _resolve_target(entry)
	if target == null:
		return
	target.transparency = float(entry.get("original_transparency", 0.0))

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
