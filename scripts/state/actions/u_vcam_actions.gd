extends RefCounted
class_name U_VCamActions

## vCam action creators for runtime observability state.

const ACTION_SET_ACTIVE_RUNTIME := StringName("vcam/set_active_runtime")
const ACTION_START_BLEND := StringName("vcam/start_blend")
const ACTION_UPDATE_BLEND := StringName("vcam/update_blend")
const ACTION_COMPLETE_BLEND := StringName("vcam/complete_blend")
const ACTION_UPDATE_SILHOUETTE_COUNT := StringName("vcam/update_silhouette_count")
const ACTION_UPDATE_TARGET_VALIDITY := StringName("vcam/update_target_validity")
const ACTION_RECORD_RECOVERY := StringName("vcam/record_recovery")
const ACTION_UPDATE_FOV_ZONE := StringName("vcam/update_fov_zone")

static func _static_init() -> void:
	U_ActionRegistry.register_action(ACTION_SET_ACTIVE_RUNTIME)
	U_ActionRegistry.register_action(ACTION_START_BLEND)
	U_ActionRegistry.register_action(ACTION_UPDATE_BLEND)
	U_ActionRegistry.register_action(ACTION_COMPLETE_BLEND)
	U_ActionRegistry.register_action(ACTION_UPDATE_SILHOUETTE_COUNT)
	U_ActionRegistry.register_action(ACTION_UPDATE_TARGET_VALIDITY)
	U_ActionRegistry.register_action(ACTION_RECORD_RECOVERY)
	U_ActionRegistry.register_action(ACTION_UPDATE_FOV_ZONE)

static func set_active_runtime(vcam_id: StringName, mode: String) -> Dictionary:
	return {
		"type": ACTION_SET_ACTIVE_RUNTIME,
		"payload": {
			"vcam_id": vcam_id,
			"mode": mode
		},
		"immediate": true
	}

static func start_blend(previous_vcam_id: StringName) -> Dictionary:
	return {
		"type": ACTION_START_BLEND,
		"payload": {
			"previous_vcam_id": previous_vcam_id
		},
		"immediate": true
	}

static func update_blend(progress: float) -> Dictionary:
	return {
		"type": ACTION_UPDATE_BLEND,
		"payload": {
			"progress": progress
		},
		"immediate": true
	}

static func complete_blend() -> Dictionary:
	return {
		"type": ACTION_COMPLETE_BLEND,
		"payload": null,
		"immediate": true
	}

static func update_silhouette_count(count: int) -> Dictionary:
	return {
		"type": ACTION_UPDATE_SILHOUETTE_COUNT,
		"payload": {
			"count": count
		},
		"immediate": true
	}

static func update_target_validity(valid: bool) -> Dictionary:
	return {
		"type": ACTION_UPDATE_TARGET_VALIDITY,
		"payload": {
			"valid": valid
		},
		"immediate": true
	}

static func record_recovery(reason: String) -> Dictionary:
	return {
		"type": ACTION_RECORD_RECOVERY,
		"payload": {
			"reason": reason
		},
		"immediate": true
	}

static func update_fov_zone(in_zone: bool) -> Dictionary:
	return {
		"type": ACTION_UPDATE_FOV_ZONE,
		"payload": {
			"in_zone": in_zone
		},
		"immediate": true
	}
