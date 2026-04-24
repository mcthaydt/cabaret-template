extends GutTest

const U_AI_TASK_STATE_KEYS_PATH := "res://scripts/core/utils/ai/u_ai_task_state_keys.gd"

func _load_keys_script() -> Script:
	var script_variant: Variant = load(U_AI_TASK_STATE_KEYS_PATH)
	assert_not_null(script_variant, "Expected script to exist: %s" % U_AI_TASK_STATE_KEYS_PATH)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func test_move_target_key_constant() -> void:
	var keys_script: Script = _load_keys_script()
	if keys_script == null:
		return
	assert_eq(keys_script.get("MOVE_TARGET"), StringName("ai_move_target"))

func test_arrival_threshold_key_constant() -> void:
	var keys_script: Script = _load_keys_script()
	if keys_script == null:
		return
	assert_eq(keys_script.get("ARRIVAL_THRESHOLD"), StringName("ai_arrival_threshold"))

func test_action_started_key_constant() -> void:
	var keys_script: Script = _load_keys_script()
	if keys_script == null:
		return
	assert_eq(keys_script.get("ACTION_STARTED"), StringName("action_started"))

func test_move_target_debug_key_constants() -> void:
	var keys_script: Script = _load_keys_script()
	if keys_script == null:
		return

	assert_eq(keys_script.get("MOVE_TARGET_RESOLVED"), StringName("move_target_resolved"))
	assert_eq(keys_script.get("MOVE_TARGET_SOURCE"), StringName("move_target_source"))
	assert_eq(keys_script.get("MOVE_TARGET_RESOLUTION_REASON"), StringName("move_target_resolution_reason"))
	assert_eq(keys_script.get("MOVE_TARGET_USED_FALLBACK"), StringName("move_target_used_fallback"))
	assert_eq(keys_script.get("MOVE_TARGET_REQUESTED_NODE_PATH"), StringName("move_target_requested_node_path"))
	assert_eq(keys_script.get("MOVE_TARGET_CONTEXT_ENTITY_PATH"), StringName("move_target_context_entity_path"))
	assert_eq(keys_script.get("MOVE_TARGET_CONTEXT_OWNER_PATH"), StringName("move_target_context_owner_path"))
	assert_eq(keys_script.get("MOVE_TARGET_WAYPOINT_INDEX"), StringName("move_target_waypoint_index"))

func test_action_state_key_constants() -> void:
	var keys_script: Script = _load_keys_script()
	if keys_script == null:
		return

	assert_eq(keys_script.get("ELAPSED"), StringName("elapsed"))
	assert_eq(keys_script.get("SCAN_ELAPSED"), StringName("scan_elapsed"))
	assert_eq(keys_script.get("SCAN_ACTIVE"), StringName("scan_active"))
	assert_eq(keys_script.get("SCAN_ROTATION_SPEED"), StringName("scan_rotation_speed"))
	assert_eq(keys_script.get("ANIMATION_STATE"), StringName("animation_state"))
	assert_eq(keys_script.get("ANIMATION_REQUESTED"), StringName("animation_requested"))
	assert_eq(keys_script.get("PUBLISHED"), StringName("published"))
	assert_eq(keys_script.get("COMPLETED"), StringName("completed"))
