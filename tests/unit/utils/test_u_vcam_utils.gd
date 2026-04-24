extends GutTest

const UTILS := preload("res://scripts/utils/display/u_vcam_utils.gd")


# --- get_node_instance_id ---


func test_get_node_instance_id_returns_zero_for_null() -> void:
	assert_eq(UTILS.get_node_instance_id(null), 0,
		"get_node_instance_id should return 0 for null node")


func test_get_node_instance_id_returns_valid_id_for_live_node() -> void:
	var node := Node.new()
	add_child_autofree(node)
	var expected_id := node.get_instance_id()
	assert_eq(UTILS.get_node_instance_id(node), expected_id,
		"get_node_instance_id should return the node's instance ID for live nodes")


# --- call_apply_position_offset ---


func test_call_apply_position_offset_returns_result_when_invalid_callable() -> void:
	var result: Dictionary = {"position": Vector3.ZERO}
	var output := UTILS.call_apply_position_offset(Callable(), result, Vector3.ONE)
	assert_eq(output, result,
		"call_apply_position_offset should return result unchanged when callable is invalid")


func test_call_apply_position_offset_calls_and_duplicates_dict() -> void:
	var offset_callable := func(res: Dictionary, off: Vector3) -> Dictionary:
		var updated := res.duplicate(true)
		updated["position"] = off
		return updated
	var result: Dictionary = {"position": Vector3.ZERO}
	var output := UTILS.call_apply_position_offset(offset_callable, result, Vector3(1.0, 2.0, 3.0))
	assert_eq(output.get("position"), Vector3(1.0, 2.0, 3.0),
		"call_apply_position_offset should return callable result with offset applied")


# --- Grep-style: private methods removed from callers ---


func _source_contains(path: String, search: String) -> bool:
	var script: Script = load(path)
	if script == null:
		return false
	return script.source_code.find(search) >= 0


func test_rotation_continuity_no_private_get_node_instance_id() -> void:
	assert_false(_source_contains("res://scripts/core/ecs/systems/helpers/u_vcam_rotation_continuity.gd", "func _get_node_instance_id("),
		"U_VCamRotationContinuity should not have private _get_node_instance_id (use U_VCamUtils)")


func test_look_spring_no_private_get_node_instance_id() -> void:
	assert_false(_source_contains("res://scripts/core/ecs/systems/helpers/u_vcam_look_spring.gd", "func _get_node_instance_id("),
		"U_VCamLookSpring should not have private _get_node_instance_id (use U_VCamUtils)")


func test_debug_no_private_get_node_instance_id() -> void:
	assert_false(_source_contains("res://scripts/core/ecs/systems/helpers/u_vcam_debug.gd", "func _get_node_instance_id("),
		"U_VCamDebug should not have private _get_node_instance_id (use U_VCamUtils)")


func test_look_ahead_no_private_call_apply_position_offset() -> void:
	assert_false(_source_contains("res://scripts/core/ecs/systems/helpers/u_vcam_look_ahead.gd", "func _call_apply_position_offset("),
		"U_VCamLookAhead should not have private _call_apply_position_offset (use U_VCamUtils)")


func test_ground_anchor_no_private_call_apply_position_offset() -> void:
	assert_false(_source_contains("res://scripts/core/ecs/systems/helpers/u_vcam_ground_anchor.gd", "func _call_apply_position_offset("),
		"U_VCamGroundAnchor should not have private _call_apply_position_offset (use U_VCamUtils)")


func test_soft_zone_applier_no_private_call_apply_position_offset() -> void:
	assert_false(_source_contains("res://scripts/core/ecs/systems/helpers/u_vcam_soft_zone_applier.gd", "func _call_apply_position_offset("),
		"U_VCamSoftZoneApplier should not have private _call_apply_position_offset (use U_VCamUtils)")