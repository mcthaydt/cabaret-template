extends GutTest

const U_BEAT_GRAPH := preload("res://scripts/utils/scene_director/u_beat_graph.gd")
const RS_BEAT_DEFINITION := preload("res://scripts/core/resources/scene_director/rs_beat_definition.gd")

func test_linear_beats_validate_successfully() -> void:
	var report: Dictionary = U_BEAT_GRAPH.validate([
		_beat(StringName("beat_a")),
		_beat(StringName("beat_b")),
	])

	assert_true(bool(report.get("valid", false)))
	assert_true((report.get("errors", []) as Array).is_empty())

func test_duplicate_beat_ids_fail_validation() -> void:
	var report: Dictionary = U_BEAT_GRAPH.validate([
		_beat(StringName("beat_a")),
		_beat(StringName("beat_a")),
	])

	assert_false(bool(report.get("valid", true)))
	assert_true(_errors_contain(report, "duplicate beat_id"))

func test_empty_beat_id_fails_validation() -> void:
	var report: Dictionary = U_BEAT_GRAPH.validate([
		_beat(StringName("")),
	])

	assert_false(bool(report.get("valid", true)))
	assert_true(_errors_contain(report, "beat_id must be non-empty"))

func test_next_beat_id_reference_must_exist() -> void:
	var beat := _beat(StringName("beat_a"))
	beat.next_beat_id = StringName("missing")

	var report: Dictionary = U_BEAT_GRAPH.validate([beat, _beat(StringName("beat_b"))])
	assert_false(bool(report.get("valid", true)))
	assert_true(_errors_contain(report, "unknown next_beat_id"))

func test_failure_beat_id_reference_must_exist() -> void:
	var beat := _beat(StringName("beat_a"))
	beat.next_beat_id_on_failure = StringName("missing")

	var report: Dictionary = U_BEAT_GRAPH.validate([beat])
	assert_false(bool(report.get("valid", true)))
	assert_true(_errors_contain(report, "unknown next_beat_id_on_failure"))

func test_parallel_lane_and_join_references_must_exist() -> void:
	var beat := _beat(StringName("beat_fork"))
	var lane_ids: Array[StringName] = [StringName("lane_missing")]
	beat.parallel_beat_ids = lane_ids
	beat.parallel_join_beat_id = StringName("join_missing")

	var report: Dictionary = U_BEAT_GRAPH.validate([beat])
	assert_false(bool(report.get("valid", true)))
	assert_true(_errors_contain(report, "unknown parallel_beat_ids"))
	assert_true(_errors_contain(report, "unknown parallel_join_beat_id"))

func test_parallel_ids_require_join_id() -> void:
	var beat := _beat(StringName("beat_fork"))
	var lane_ids: Array[StringName] = [StringName("lane_a")]
	beat.parallel_beat_ids = lane_ids

	var report: Dictionary = U_BEAT_GRAPH.validate([
		beat,
		_beat(StringName("lane_a")),
	])
	assert_false(bool(report.get("valid", true)))
	assert_true(_errors_contain(report, "missing parallel_join_beat_id"))

func test_join_id_requires_parallel_ids() -> void:
	var beat := _beat(StringName("beat_fork"))
	beat.parallel_join_beat_id = StringName("join")

	var report: Dictionary = U_BEAT_GRAPH.validate([
		beat,
		_beat(StringName("join")),
	])
	assert_false(bool(report.get("valid", true)))
	assert_true(_errors_contain(report, "has no parallel_beat_ids"))

func test_lane_beats_cannot_define_nested_parallel_lanes() -> void:
	var fork := _beat(StringName("fork"))
	var fork_lanes: Array[StringName] = [StringName("lane_a")]
	fork.parallel_beat_ids = fork_lanes
	fork.parallel_join_beat_id = StringName("join")

	var lane := _beat(StringName("lane_a"))
	var nested_lanes: Array[StringName] = [StringName("lane_nested")]
	lane.parallel_beat_ids = nested_lanes
	lane.parallel_join_beat_id = StringName("join")

	var report: Dictionary = U_BEAT_GRAPH.validate([
		fork,
		lane,
		_beat(StringName("join")),
		_beat(StringName("lane_nested")),
	])
	assert_false(bool(report.get("valid", true)))
	assert_true(_errors_contain(report, "single-hop lanes only"))

func test_cycle_detection_fails_for_next_edges() -> void:
	var a := _beat(StringName("a"))
	a.next_beat_id = StringName("b")
	var b := _beat(StringName("b"))
	b.next_beat_id = StringName("a")

	var report: Dictionary = U_BEAT_GRAPH.validate([a, b])
	assert_false(bool(report.get("valid", true)))
	assert_true(_errors_contain(report, "cycle detected"))

func test_cycle_detection_fails_for_parallel_and_join_edges() -> void:
	var fork := _beat(StringName("fork"))
	var lane_ids: Array[StringName] = [StringName("lane")]
	fork.parallel_beat_ids = lane_ids
	fork.parallel_join_beat_id = StringName("join")

	var join := _beat(StringName("join"))
	join.next_beat_id = StringName("fork")

	var report: Dictionary = U_BEAT_GRAPH.validate([
		fork,
		_beat(StringName("lane")),
		join,
	])
	assert_false(bool(report.get("valid", true)))
	assert_true(_errors_contain(report, "cycle detected"))

func test_build_id_to_index_map_returns_expected_indices() -> void:
	var beats: Array[Resource] = [
		_beat(StringName("intro")),
		_beat(StringName("fork")),
		_beat(StringName("join")),
	]
	var map: Dictionary = U_BEAT_GRAPH.build_id_to_index_map(beats)

	assert_eq(int(map.get(StringName("intro"), -1)), 0)
	assert_eq(int(map.get(StringName("fork"), -1)), 1)
	assert_eq(int(map.get(StringName("join"), -1)), 2)

func test_new_flow_fields_default_to_empty_values() -> void:
	var beat := _beat(StringName("default"))

	assert_eq(beat.next_beat_id, StringName(""))
	assert_eq(beat.next_beat_id_on_failure, StringName(""))
	assert_true(beat.parallel_beat_ids.is_empty())
	assert_eq(beat.parallel_join_beat_id, StringName(""))

func _beat(beat_id: StringName) -> Resource:
	var beat: Resource = RS_BEAT_DEFINITION.new()
	beat.beat_id = beat_id
	return beat

func _errors_contain(report: Dictionary, token: String) -> bool:
	var errors_variant: Variant = report.get("errors", [])
	if not (errors_variant is Array):
		return false
	for message_variant in errors_variant as Array:
		var message: String = str(message_variant).to_lower()
		if message.find(token.to_lower()) != -1:
			return true
	return false
