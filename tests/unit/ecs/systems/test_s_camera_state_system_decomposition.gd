extends BaseTest

# F8 Phase 1 Decomposition tests — test that S_CameraStateSystem has been decomposed
# and FOV/trauma/config/camera-state-apply logic extracted to U_CameraStateRuleApplier.

const S_CAMERA_STATE_SYSTEM_SCRIPT := "res://scripts/ecs/systems/s_camera_state_system.gd"
const RULE_APPLIER_SCRIPT := "res://scripts/ecs/systems/helpers/u_camera_state_rule_applier.gd"

# Methods that should move from system to rule applier
const MOVED_METHODS := [
	"_apply_camera_state",
	"_decay_non_primary_trauma",
	"_select_primary_camera_context",
	"_is_primary_camera_context",
	"_resolve_camera_state_config_values",
	"_clamp_fov",
	"_apply_fov_to_camera",
	"_resolve_target_fov",
	"_ensure_baseline_fov",
	"_is_fov_zone_active",
	"_write_target_fov",
	"_write_baseline_fov",
	"_resolve_speed_fov_bonus",
	"_write_speed_fov_bonus",
	"_apply_trauma_shake",
	"_decay_trauma",
	"_write_shake_trauma",
	"_get_camera_state_float",
]


func _load_script(path: String) -> Script:
	var script: Script = load(path)
	return script


func _count_source_lines(path: String) -> int:
	var script: Script = load(path)
	if script == null:
		return -1
	var source: String = script.source_code
	var lines: PackedStringArray = source.split("\n")
	return lines.size()


func _method_line_count(source: String, method_name: String) -> int:
	var lines: PackedStringArray = source.split("\n")
	var start_line: int = -1
	var end_line: int = -1
	var indent_level: int = -1
	var in_method: bool = false

	for i in range(lines.size()):
		var line: String = lines[i]
		if line.find("func %s(" % method_name) >= 0:
			start_line = i
			var stripped: String = line.lstrip("\t ")
			indent_level = line.length() - stripped.length()
			in_method = true
			continue
		if in_method:
			if line.strip_edges() == "":
				continue
			var stripped: String = line.lstrip("\t ")
			var current_indent: int = line.length() - stripped.length()
			if current_indent <= indent_level and (stripped.begins_with("func ") or stripped.begins_with("var ") or stripped.begins_with("signal ")):
				end_line = i - 1
				break

	if end_line == -1:
		end_line = lines.size() - 1

	if start_line == -1:
		return -1
	return end_line - start_line + 1


func _source_has_method(path: String, method_name: String) -> bool:
	var script: Script = load(path)
	if script == null:
		return false
	return script.source_code.find("func %s(" % method_name) >= 0


# --- Rule applier existence tests ---

func test_rule_applier_class_exists() -> void:
	var script: Script = _load_script(RULE_APPLIER_SCRIPT)
	assert_not_null(script, "U_CameraStateRuleApplier script should exist at %s" % RULE_APPLIER_SCRIPT)


func test_rule_applier_has_apply_camera_state() -> void:
	var script: Script = _load_script(RULE_APPLIER_SCRIPT)
	if script == null:
		assert_not_null(script, "U_CameraStateRuleApplier script should exist")
		return
	assert_true(script.source_code.find("func apply_camera_state(") >= 0,
		"U_CameraStateRuleApplier should have apply_camera_state method")


func test_rule_applier_has_apply_fov_to_camera() -> void:
	var script: Script = _load_script(RULE_APPLIER_SCRIPT)
	if script == null:
		assert_not_null(script, "U_CameraStateRuleApplier script should exist")
		return
	assert_true(script.source_code.find("func apply_fov_to_camera(") >= 0,
		"U_CameraStateRuleApplier should have apply_fov_to_camera method")


func test_rule_applier_has_apply_trauma_shake() -> void:
	var script: Script = _load_script(RULE_APPLIER_SCRIPT)
	if script == null:
		assert_not_null(script, "U_CameraStateRuleApplier script should exist")
		return
	assert_true(script.source_code.find("func apply_trauma_shake(") >= 0,
		"U_CameraStateRuleApplier should have apply_trauma_shake method")


func test_rule_applier_has_clamp_fov() -> void:
	var script: Script = _load_script(RULE_APPLIER_SCRIPT)
	if script == null:
		assert_not_null(script, "U_CameraStateRuleApplier script should exist")
		return
	assert_true(script.source_code.find("func clamp_fov(") >= 0,
		"U_CameraStateRuleApplier should have clamp_fov method")


func test_rule_applier_has_resolve_config_values() -> void:
	var script: Script = _load_script(RULE_APPLIER_SCRIPT)
	if script == null:
		assert_not_null(script, "U_CameraStateRuleApplier script should exist")
		return
	assert_true(script.source_code.find("func resolve_camera_state_config_values(") >= 0,
		"U_CameraStateRuleApplier should have resolve_camera_state_config_values method")


# --- System line count ceiling tests ---

func test_s_camera_state_system_under_400_lines() -> void:
	var line_count: int = _count_source_lines(S_CAMERA_STATE_SYSTEM_SCRIPT)
	assert_lt(line_count, 400,
		"S_CameraStateSystem should be under 400 lines after decomposition, got %d" % line_count)


func test_process_tick_under_80_lines() -> void:
	var script: Script = _load_script(S_CAMERA_STATE_SYSTEM_SCRIPT)
	if script == null:
		assert_not_null(script, "S_CameraStateSystem script should load")
		return
	var method_lines: int = _method_line_count(script.source_code, "process_tick")
	assert_lt(method_lines, 80,
		"S_CameraStateSystem.process_tick should be under 80 lines, got %d" % method_lines)


# --- Removed method tests ---

func test_fov_pipeline_methods_removed_from_system() -> void:
	var fov_methods := [
		"_apply_fov_to_camera",
		"_resolve_target_fov",
		"_ensure_baseline_fov",
		"_clamp_fov",
		"_is_fov_zone_active",
		"_write_target_fov",
		"_write_baseline_fov",
		"_resolve_speed_fov_bonus",
		"_write_speed_fov_bonus",
	]
	for method_name in fov_methods:
		assert_false(_source_has_method(S_CAMERA_STATE_SYSTEM_SCRIPT, method_name),
			"S_CameraStateSystem should not have %s (moved to U_CameraStateRuleApplier)" % method_name)


func test_trauma_methods_removed_from_system() -> void:
	var trauma_methods := [
		"_apply_trauma_shake",
		"_decay_trauma",
		"_write_shake_trauma",
		"_decay_non_primary_trauma",
	]
	for method_name in trauma_methods:
		assert_false(_source_has_method(S_CAMERA_STATE_SYSTEM_SCRIPT, method_name),
			"S_CameraStateSystem should not have %s (moved to U_CameraStateRuleApplier)" % method_name)


func test_config_and_utility_methods_removed_from_system() -> void:
	var utility_methods := [
		"_resolve_camera_state_config_values",
		"_get_camera_state_float",
		"_select_primary_camera_context",
		"_is_primary_camera_context",
		"_apply_camera_state",
	]
	for method_name in utility_methods:
		assert_false(_source_has_method(S_CAMERA_STATE_SYSTEM_SCRIPT, method_name),
			"S_CameraStateSystem should not have %s (moved to U_CameraStateRuleApplier)" % method_name)


# --- System structure tests ---

func test_system_has_rule_applier_member() -> void:
	var script: Script = _load_script(S_CAMERA_STATE_SYSTEM_SCRIPT)
	if script == null:
		assert_not_null(script, "S_CameraStateSystem script should load")
		return
	assert_true(script.source_code.find("_rule_applier") >= 0,
		"S_CameraStateSystem should have _rule_applier member")


func test_system_delegates_apply_camera_state_to_rule_applier() -> void:
	var script: Script = _load_script(S_CAMERA_STATE_SYSTEM_SCRIPT)
	if script == null:
		assert_not_null(script, "S_CameraStateSystem script should load")
		return
	assert_true(script.source_code.find("_rule_applier.apply_camera_state(") >= 0 or
		script.source_code.find("_rule_applier.apply_camera_state(") >= 0,
		"S_CameraStateSystem should delegate apply_camera_state to _rule_applier")


# --- Rule applier line count ---

func test_rule_applier_under_400_lines() -> void:
	var line_count: int = _count_source_lines(RULE_APPLIER_SCRIPT)
	if line_count < 0:
		assert_not_null(_load_script(RULE_APPLIER_SCRIPT), "U_CameraStateRuleApplier should exist")
		return
	assert_lt(line_count, 400,
		"U_CameraStateRuleApplier should be under 400 lines, got %d" % line_count)