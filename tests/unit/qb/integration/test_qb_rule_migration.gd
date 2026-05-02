extends GutTest

const BUILDER_DIR := "res://scripts/core/qb/rules/br_"
const U_RULE_VALIDATOR_PATH := "res://scripts/core/utils/qb/u_rule_validator.gd"
const RS_RULE_PATH := "res://scripts/core/resources/qb/rs_rule.gd"

var _validator_script: Script = null

func _load_validator() -> void:
	if _validator_script != null:
		return
	_validator_script = load(U_RULE_VALIDATOR_PATH) as Script

func _validate_rules(rules: Array) -> Dictionary:
	_load_validator()
	if _validator_script == null:
		return {}
	return _validator_script.call("validate_rules", rules)

func _load_builder_script(path: String) -> Script:
	assert_true(FileAccess.file_exists(path), "Builder script must exist: %s" % path)
	if not FileAccess.file_exists(path):
		return null
	var s: Variant = load(path)
	assert_not_null(s, "Builder script must load: %s" % path)
	if s == null or not (s is Script):
		return null
	return s as Script

func _build_rule(script: Script) -> Resource:
	assert_not_null(script, "Script must not be null")
	var v: Variant = script.new()
	assert_not_null(v, "Builder must instantiate")
	if v == null or not (v is Object):
		return null
	assert_true(v.has_method("build"), "Builder must have build() method")
	if not v.has_method("build"):
		return null
	var rule: Variant = v.call("build")
	assert_not_null(rule, "build() must return a rule")
	if rule == null:
		return null
	assert_true(rule is Resource, "build() must return a Resource")
	var script_of_rule: Script = (rule as Resource).get_script()
	assert_not_null(script_of_rule, "Rule must have a script")
	if script_of_rule == null:
		return null
	assert_eq(script_of_rule.resource_path, RS_RULE_PATH, "build() must return RS_Rule")
	return rule as Resource


# ── Character Rules ─────────────────────────────────────────────────────────

func test_pause_gate_paused_builder() -> void:
	var s: Script = _load_builder_script(BUILDER_DIR + "pause_gate_paused_rule.gd")
	if s == null:
		return
	var rule: Resource = _build_rule(s)
	if rule == null:
		return
	assert_eq(rule.get("rule_id"), &"pause_gate_paused")
	assert_eq(rule.get("decision_group"), &"pause_gate")
	assert_eq(rule.get("trigger_mode"), "tick")
	var conditions: Array = rule.get("conditions")
	assert_eq(conditions.size(), 1, "must have 1 condition")
	assert_eq(rule.get("effects").size(), 1, "must have 1 effect")
	var report: Dictionary = _validate_rules([rule])
	assert_eq(report.get("valid_rules", []).size(), 1, "must pass validation")


func test_pause_gate_shell_builder() -> void:
	var s: Script = _load_builder_script(BUILDER_DIR + "pause_gate_shell_rule.gd")
	if s == null:
		return
	var rule: Resource = _build_rule(s)
	if rule == null:
		return
	assert_eq(rule.get("rule_id"), &"pause_gate_shell")
	assert_eq(rule.get("decision_group"), &"pause_gate")
	var conditions: Array = rule.get("conditions")
	assert_eq(conditions.size(), 1)
	var report: Dictionary = _validate_rules([rule])
	assert_eq(report.get("valid_rules", []).size(), 1)


func test_pause_gate_transitioning_builder() -> void:
	var s: Script = _load_builder_script(BUILDER_DIR + "pause_gate_transitioning_rule.gd")
	if s == null:
		return
	var rule: Resource = _build_rule(s)
	if rule == null:
		return
	assert_eq(rule.get("rule_id"), &"pause_gate_transitioning")
	assert_eq(rule.get("decision_group"), &"pause_gate")
	var conditions: Array = rule.get("conditions")
	assert_eq(conditions.size(), 1)
	var report: Dictionary = _validate_rules([rule])
	assert_eq(report.get("valid_rules", []).size(), 1)


func test_spawn_freeze_builder() -> void:
	var s: Script = _load_builder_script(BUILDER_DIR + "spawn_freeze_rule.gd")
	if s == null:
		return
	var rule: Resource = _build_rule(s)
	if rule == null:
		return
	assert_eq(rule.get("rule_id"), &"spawn_freeze")
	assert_eq(rule.get("trigger_mode"), "tick")
	assert_eq(rule.get("conditions").size(), 1)
	assert_eq(rule.get("effects").size(), 1)
	var report: Dictionary = _validate_rules([rule])
	assert_eq(report.get("valid_rules", []).size(), 1)


func test_death_sync_builder() -> void:
	var s: Script = _load_builder_script(BUILDER_DIR + "death_sync_rule.gd")
	if s == null:
		return
	var rule: Resource = _build_rule(s)
	if rule == null:
		return
	assert_eq(rule.get("rule_id"), &"death_sync")
	assert_eq(rule.get("trigger_mode"), "tick")
	assert_eq(rule.get("conditions").size(), 1)
	assert_eq(rule.get("effects").size(), 1)
	var report: Dictionary = _validate_rules([rule])
	assert_eq(report.get("valid_rules", []).size(), 1)


# ── Camera Rules ────────────────────────────────────────────────────────────

func test_camera_shake_builder() -> void:
	var s: Script = _load_builder_script(BUILDER_DIR + "camera_shake_rule.gd")
	if s == null:
		return
	var rule: Resource = _build_rule(s)
	if rule == null:
		return
	assert_eq(rule.get("rule_id"), &"camera_shake")
	assert_eq(rule.get("trigger_mode"), "event")
	assert_eq(rule.get("conditions").size(), 1)
	assert_eq(rule.get("effects").size(), 1)
	var report: Dictionary = _validate_rules([rule])
	assert_eq(report.get("valid_rules", []).size(), 1)


func test_camera_zone_fov_builder() -> void:
	var s: Script = _load_builder_script(BUILDER_DIR + "camera_zone_fov_rule.gd")
	if s == null:
		return
	var rule: Resource = _build_rule(s)
	if rule == null:
		return
	assert_eq(rule.get("rule_id"), &"camera_zone_fov")
	assert_eq(rule.get("trigger_mode"), "tick")
	assert_eq(rule.get("conditions").size(), 1)
	assert_eq(rule.get("effects").size(), 1)
	var report: Dictionary = _validate_rules([rule])
	assert_eq(report.get("valid_rules", []).size(), 1)


func test_camera_speed_fov_builder() -> void:
	var s: Script = _load_builder_script(BUILDER_DIR + "camera_speed_fov_rule.gd")
	if s == null:
		return
	var rule: Resource = _build_rule(s)
	if rule == null:
		return
	assert_eq(rule.get("rule_id"), &"camera_speed_fov")
	assert_eq(rule.get("trigger_mode"), "tick")
	assert_eq(rule.get("conditions").size(), 1)
	assert_eq(rule.get("effects").size(), 1)
	var report: Dictionary = _validate_rules([rule])
	assert_eq(report.get("valid_rules", []).size(), 1)


func test_camera_landing_impact_builder() -> void:
	var s: Script = _load_builder_script(BUILDER_DIR + "camera_landing_impact_rule.gd")
	if s == null:
		return
	var rule: Resource = _build_rule(s)
	if rule == null:
		return
	assert_eq(rule.get("rule_id"), &"camera_landing_impact")
	assert_eq(rule.get("trigger_mode"), "event")
	assert_eq(rule.get("conditions").size(), 2)
	assert_eq(rule.get("effects").size(), 1)
	var report: Dictionary = _validate_rules([rule])
	assert_eq(report.get("valid_rules", []).size(), 1)


# ── Game Rules ──────────────────────────────────────────────────────────────

func test_checkpoint_forward_builder() -> void:
	var s: Script = _load_builder_script(BUILDER_DIR + "checkpoint_forward_rule.gd")
	if s == null:
		return
	var rule: Resource = _build_rule(s)
	if rule == null:
		return
	assert_eq(rule.get("rule_id"), &"checkpoint_forward")
	assert_eq(rule.get("trigger_mode"), "event")
	assert_eq(rule.get("conditions").size(), 1)
	assert_eq(rule.get("effects").size(), 1)
	var report: Dictionary = _validate_rules([rule])
	assert_eq(report.get("valid_rules", []).size(), 1)


func test_victory_forward_builder() -> void:
	var s: Script = _load_builder_script(BUILDER_DIR + "victory_forward_rule.gd")
	if s == null:
		return
	var rule: Resource = _build_rule(s)
	if rule == null:
		return
	assert_eq(rule.get("rule_id"), &"victory_forward")
	assert_eq(rule.get("trigger_mode"), "event")
	assert_eq(rule.get("conditions").size(), 1)
	assert_eq(rule.get("effects").size(), 1)
	var report: Dictionary = _validate_rules([rule])
	assert_eq(report.get("valid_rules", []).size(), 1)


func test_all_character_rule_builders_pass_validation() -> void:
	var ids: Array[String] = [
		"pause_gate_paused",
		"pause_gate_shell",
		"pause_gate_transitioning",
		"spawn_freeze",
		"death_sync",
	]
	var all_rules: Array = []
	for id in ids:
		var path: String = BUILDER_DIR + id + "_rule.gd"
		if not FileAccess.file_exists(path):
			continue
		var s: Variant = load(path)
		if s == null or not (s is Script):
			continue
		var builder: Variant = (s as Script).new()
		if builder == null or not builder.has_method("build"):
			continue
		var rule: Variant = builder.call("build")
		if rule != null and rule is Resource:
			all_rules.append(rule)
	assert_eq(all_rules.size(), 5, "All 5 character rule builders must be loadable")
	var report: Dictionary = _validate_rules(all_rules)
	assert_eq(report.get("valid_rules", []).size(), 5, "All 5 character rules must pass validation")


func test_all_camera_rule_builders_pass_validation() -> void:
	var ids: Array[String] = [
		"camera_shake",
		"camera_zone_fov",
		"camera_speed_fov",
		"camera_landing_impact",
	]
	var all_rules: Array = []
	for id in ids:
		var path: String = BUILDER_DIR + id + "_rule.gd"
		if not FileAccess.file_exists(path):
			continue
		var s: Variant = load(path)
		if s == null or not (s is Script):
			continue
		var builder: Variant = (s as Script).new()
		if builder == null or not builder.has_method("build"):
			continue
		var rule: Variant = builder.call("build")
		if rule != null and rule is Resource:
			all_rules.append(rule)
	assert_eq(all_rules.size(), 4, "All 4 camera rule builders must be loadable")
	var report: Dictionary = _validate_rules(all_rules)
	assert_eq(report.get("valid_rules", []).size(), 4, "All 4 camera rules must pass validation")


func test_all_game_rule_builders_pass_validation() -> void:
	var ids: Array[String] = [
		"checkpoint_forward",
		"victory_forward",
	]
	var all_rules: Array = []
	for id in ids:
		var path: String = BUILDER_DIR + id + "_rule.gd"
		if not FileAccess.file_exists(path):
			continue
		var s: Variant = load(path)
		if s == null or not (s is Script):
			continue
		var builder: Variant = (s as Script).new()
		if builder == null or not builder.has_method("build"):
			continue
		var rule: Variant = builder.call("build")
		if rule != null and rule is Resource:
			all_rules.append(rule)
	assert_eq(all_rules.size(), 2, "All 2 game rule builders must be loadable")
	var report: Dictionary = _validate_rules(all_rules)
	assert_eq(report.get("valid_rules", []).size(), 2, "All 2 game rules must pass validation")
