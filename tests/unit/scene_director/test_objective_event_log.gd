extends GutTest

const OBJECTIVE_EVENT_LOG := preload("res://scripts/utils/scene_director/u_objective_event_log.gd")

func test_create_entry_includes_timestamp_and_copies_details() -> void:
	var start_time: float = Time.get_ticks_msec() / 1000.0
	var details := {"reason": "auto_activate"}
	var entry: Dictionary = OBJECTIVE_EVENT_LOG.create_entry(
		StringName("obj_intro"),
		OBJECTIVE_EVENT_LOG.EVENT_ACTIVATED,
		details
	)

	assert_eq(entry.get("objective_id"), StringName("obj_intro"))
	assert_eq(entry.get("event_type"), OBJECTIVE_EVENT_LOG.EVENT_ACTIVATED)
	assert_true(entry.has("timestamp"))
	assert_true(float(entry.get("timestamp", 0.0)) >= start_time)
	assert_eq(entry.get("details", {}).get("reason"), "auto_activate")

	details["reason"] = "mutated_after_create"
	assert_eq(
		entry.get("details", {}).get("reason"),
		"auto_activate",
		"Entry details should be deep-copied"
	)

func test_format_log_renders_readable_lines() -> void:
	var entries: Array[Dictionary] = [
		OBJECTIVE_EVENT_LOG.create_entry(
			StringName("obj_intro"),
			OBJECTIVE_EVENT_LOG.EVENT_ACTIVATED,
			{"source": "load"}
		),
		OBJECTIVE_EVENT_LOG.create_entry(
			StringName("obj_intro"),
			OBJECTIVE_EVENT_LOG.EVENT_COMPLETED,
			{}
		),
	]
	var formatted: String = OBJECTIVE_EVENT_LOG.format_log(entries)

	assert_true(formatted.contains("obj_intro"))
	assert_true(formatted.contains("activated"))
	assert_true(formatted.contains("completed"))
	assert_true(formatted.contains("source"))

func test_format_log_includes_all_supported_event_types() -> void:
	var entries: Array[Dictionary] = [
		OBJECTIVE_EVENT_LOG.create_entry(
			StringName("obj_a"),
			OBJECTIVE_EVENT_LOG.EVENT_ACTIVATED,
			{}
		),
		OBJECTIVE_EVENT_LOG.create_entry(
			StringName("obj_a"),
			OBJECTIVE_EVENT_LOG.EVENT_COMPLETED,
			{}
		),
		OBJECTIVE_EVENT_LOG.create_entry(
			StringName("obj_b"),
			OBJECTIVE_EVENT_LOG.EVENT_FAILED,
			{}
		),
		OBJECTIVE_EVENT_LOG.create_entry(
			StringName("obj_c"),
			OBJECTIVE_EVENT_LOG.EVENT_DEPENDENCY_MET,
			{"dependency_id": StringName("obj_a")}
		),
		OBJECTIVE_EVENT_LOG.create_entry(
			StringName("obj_d"),
			OBJECTIVE_EVENT_LOG.EVENT_CONDITION_CHECKED,
			{"passed": true}
		),
	]
	var formatted: String = OBJECTIVE_EVENT_LOG.format_log(entries)

	assert_true(formatted.contains(OBJECTIVE_EVENT_LOG.EVENT_ACTIVATED))
	assert_true(formatted.contains(OBJECTIVE_EVENT_LOG.EVENT_COMPLETED))
	assert_true(formatted.contains(OBJECTIVE_EVENT_LOG.EVENT_FAILED))
	assert_true(formatted.contains(OBJECTIVE_EVENT_LOG.EVENT_DEPENDENCY_MET))
	assert_true(formatted.contains(OBJECTIVE_EVENT_LOG.EVENT_CONDITION_CHECKED))
