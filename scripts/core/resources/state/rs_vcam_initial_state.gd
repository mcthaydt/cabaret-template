@icon("res://assets/core/editor_icons/icn_resource.svg")
extends Resource
class_name RS_VCamInitialState

## vCam runtime observability initial state (Phase 0C).
##
## This slice is transient runtime state and is not player-save data.

@export var active_vcam_id: StringName = StringName("")
@export var active_mode: String = ""
@export var previous_vcam_id: StringName = StringName("")
@export_range(0.0, 1.0, 0.01) var blend_progress: float = 1.0
@export var is_blending: bool = false
@export var silhouette_active_count: int = 0
@export var blend_from_vcam_id: StringName = StringName("")
@export var blend_to_vcam_id: StringName = StringName("")
@export var active_target_valid: bool = true
@export var last_recovery_reason: String = ""
@export var in_fov_zone: bool = false

func to_dictionary() -> Dictionary:
	return {
		"active_vcam_id": active_vcam_id,
		"active_mode": active_mode,
		"previous_vcam_id": previous_vcam_id,
		"blend_progress": blend_progress,
		"is_blending": is_blending,
		"silhouette_active_count": silhouette_active_count,
		"blend_from_vcam_id": blend_from_vcam_id,
		"blend_to_vcam_id": blend_to_vcam_id,
		"active_target_valid": active_target_valid,
		"last_recovery_reason": last_recovery_reason,
		"in_fov_zone": in_fov_zone,
	}
