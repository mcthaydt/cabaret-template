extends GutTest


func test_set_active_runtime_action_structure() -> void:
	var action: Dictionary = U_VCamActions.set_active_runtime(&"vcam_alley", "orbit")
	var payload: Dictionary = action.get("payload", {})

	assert_eq(action.get("type"), U_VCamActions.ACTION_SET_ACTIVE_RUNTIME)
	assert_eq(payload.get("vcam_id"), StringName("vcam_alley"))
	assert_eq(payload.get("mode"), "orbit")
	assert_eq(action.get("immediate"), true)

func test_start_blend_action_structure() -> void:
	var action: Dictionary = U_VCamActions.start_blend(&"vcam_previous")
	var payload: Dictionary = action.get("payload", {})

	assert_eq(action.get("type"), U_VCamActions.ACTION_START_BLEND)
	assert_eq(payload.get("previous_vcam_id"), StringName("vcam_previous"))
	assert_eq(action.get("immediate"), true)

func test_update_blend_action_structure() -> void:
	var action: Dictionary = U_VCamActions.update_blend(0.42)
	var payload: Dictionary = action.get("payload", {})

	assert_eq(action.get("type"), U_VCamActions.ACTION_UPDATE_BLEND)
	assert_almost_eq(float(payload.get("progress", 0.0)), 0.42, 0.0001)
	assert_eq(action.get("immediate"), true)

func test_complete_blend_action_structure() -> void:
	var action: Dictionary = U_VCamActions.complete_blend()

	assert_eq(action.get("type"), U_VCamActions.ACTION_COMPLETE_BLEND)
	assert_true(action.has("payload"))
	assert_eq(action.get("immediate"), true)

func test_update_silhouette_count_action_structure() -> void:
	var action: Dictionary = U_VCamActions.update_silhouette_count(3)
	var payload: Dictionary = action.get("payload", {})

	assert_eq(action.get("type"), U_VCamActions.ACTION_UPDATE_SILHOUETTE_COUNT)
	assert_eq(payload.get("count"), 3)
	assert_eq(action.get("immediate"), true)

func test_update_target_validity_action_structure() -> void:
	var action: Dictionary = U_VCamActions.update_target_validity(false)
	var payload: Dictionary = action.get("payload", {})

	assert_eq(action.get("type"), U_VCamActions.ACTION_UPDATE_TARGET_VALIDITY)
	assert_eq(payload.get("valid"), false)
	assert_eq(action.get("immediate"), true)

func test_record_recovery_action_structure() -> void:
	var action: Dictionary = U_VCamActions.record_recovery("follow_target_invalid")
	var payload: Dictionary = action.get("payload", {})

	assert_eq(action.get("type"), U_VCamActions.ACTION_RECORD_RECOVERY)
	assert_eq(payload.get("reason"), "follow_target_invalid")
	assert_eq(action.get("immediate"), true)

func test_update_fov_zone_action_structure() -> void:
	var action: Dictionary = U_VCamActions.update_fov_zone(true)
	var payload: Dictionary = action.get("payload", {})

	assert_eq(action.get("type"), U_VCamActions.ACTION_UPDATE_FOV_ZONE)
	assert_eq(payload.get("in_zone"), true)
	assert_eq(action.get("immediate"), true)
