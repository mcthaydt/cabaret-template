extends BaseTest

# F8 Phase 1 Decomposition tests — test that S_VCamSystem has been decomposed
# and pipeline logic extracted to U_VCamPipelineBuilder.

const S_VCAM_SYSTEM_SCRIPT := "res://scripts/ecs/systems/s_vcam_system.gd"
const PIPELINE_BUILDER_SCRIPT := "res://scripts/ecs/systems/helpers/u_vcam_pipeline_builder.gd"


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


func _source_contains(path: String, search: String) -> bool:
	var script: Script = load(path)
	if script == null:
		return false
	return script.source_code.find(search) >= 0


func _source_has_method(path: String, method_name: String) -> bool:
	return _source_contains(path, "func %s(" % method_name)


# --- Pipeline builder existence tests ---

func test_pipeline_builder_class_exists() -> void:
	var script: Script = _load_script(PIPELINE_BUILDER_SCRIPT)
	assert_not_null(script, "U_VCamPipelineBuilder script should exist at %s" % PIPELINE_BUILDER_SCRIPT)


func test_pipeline_builder_has_prepare_method() -> void:
	var script: Script = _load_script(PIPELINE_BUILDER_SCRIPT)
	if script == null:
		assert_not_null(script, "U_VCamPipelineBuilder script should exist")
		return
	assert_true(script.source_code.find("func prepare_vcam_pipeline_state(") >= 0,
		"U_VCamPipelineBuilder should have prepare_vcam_pipeline_state method")


func test_pipeline_builder_has_evaluate_method() -> void:
	var script: Script = _load_script(PIPELINE_BUILDER_SCRIPT)
	if script == null:
		assert_not_null(script, "U_VCamPipelineBuilder script should exist")
		return
	assert_true(script.source_code.find("func evaluate_vcam_mode_result(") >= 0,
		"U_VCamPipelineBuilder should have evaluate_vcam_mode_result method")


# --- System line count ceiling tests ---

func test_s_vcam_system_under_400_lines() -> void:
	var line_count: int = _count_source_lines(S_VCAM_SYSTEM_SCRIPT)
	assert_lt(line_count, 400,
		"S_VCamSystem should be under 400 lines after decomposition, got %d" % line_count)


func test_process_tick_under_80_lines() -> void:
	var script: Script = _load_script(S_VCAM_SYSTEM_SCRIPT)
	if script == null:
		assert_not_null(script, "S_VCamSystem script should load")
		return
	var method_lines: int = _method_line_count(script.source_code, "process_tick")
	assert_lt(method_lines, 80,
		"S_VCamSystem.process_tick should be under 80 lines, got %d" % method_lines)


# --- Dead code absence tests ---

func test_no_evaluate_and_submit_in_source() -> void:
	assert_false(_source_has_method(S_VCAM_SYSTEM_SCRIPT, "_evaluate_and_submit"),
		"S_VCamSystem should not have dead _evaluate_and_submit method")


func test_no_step_orbit_release_axis_wrapper() -> void:
	assert_false(_source_has_method(S_VCAM_SYSTEM_SCRIPT, "_step_orbit_release_axis"),
		"S_VCamSystem should not have dead _step_orbit_release_axis wrapper")


func test_no_resolve_orbit_center_target_yaw_wrapper() -> void:
	assert_false(_source_has_method(S_VCAM_SYSTEM_SCRIPT, "_resolve_orbit_center_target_yaw"),
		"S_VCamSystem should not have dead _resolve_orbit_center_target_yaw wrapper")


# --- Callable retention tests ---

func test_resolve_follow_target_callable_retained() -> void:
	assert_true(_source_has_method(S_VCAM_SYSTEM_SCRIPT, "_resolve_follow_target"),
		"S_VCamSystem should retain _resolve_follow_target (Callable target for rotation continuity)")


func test_resolve_mode_values_callable_retained() -> void:
	assert_true(_source_has_method(S_VCAM_SYSTEM_SCRIPT, "_resolve_mode_values"),
		"S_VCamSystem should retain _resolve_mode_values (Callable target for rotation helpers)")


func test_clear_smoothing_state_for_vcam_callable_retained() -> void:
	assert_true(_source_has_method(S_VCAM_SYSTEM_SCRIPT, "_clear_smoothing_state_for_vcam"),
		"S_VCamSystem should retain _clear_smoothing_state_for_vcam (Callable target for effect pipeline)")


# --- Pipeline builder line count ---

func test_pipeline_builder_under_400_lines() -> void:
	var line_count: int = _count_source_lines(PIPELINE_BUILDER_SCRIPT)
	if line_count < 0:
		assert_not_null(_load_script(PIPELINE_BUILDER_SCRIPT), "U_VCamPipelineBuilder should exist")
		return
	assert_lt(line_count, 400,
		"U_VCamPipelineBuilder should be under 400 lines, got %d" % line_count)


# --- Thin wrapper removal tests ---

func test_no_apply_vcam_effect_pipeline_wrapper() -> void:
	assert_false(_source_has_method(S_VCAM_SYSTEM_SCRIPT, "_apply_vcam_effect_pipeline"),
		"S_VCamSystem should not have _apply_vcam_effect_pipeline wrapper (call effect_pipeline_helper directly)")


func test_no_resolve_state_store_wrapper() -> void:
	assert_false(_source_has_method(S_VCAM_SYSTEM_SCRIPT, "_resolve_state_store"),
		"S_VCamSystem should not have _resolve_state_store wrapper (call runtime_services_helper directly)")


func test_no_update_runtime_rotation_wrapper() -> void:
	assert_false(_source_has_method(S_VCAM_SYSTEM_SCRIPT, "_update_runtime_rotation"),
		"S_VCamSystem should not have _update_runtime_rotation wrapper (pipeline builder calls rotation_helper directly)")


func test_no_resolve_runtime_rotation_for_evaluation_wrapper() -> void:
	assert_false(_source_has_method(S_VCAM_SYSTEM_SCRIPT, "_resolve_runtime_rotation_for_evaluation"),
		"S_VCamSystem should not have _resolve_runtime_rotation_for_evaluation wrapper (pipeline builder calls rotation_helper directly)")