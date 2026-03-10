extends GutTest

const MODE_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_mode_fixed.gd")

func _new_mode() -> Resource:
	return MODE_SCRIPT.new()

func _resolved(mode: Resource) -> Dictionary:
	var resolved_variant: Variant = mode.call("get_resolved_values")
	if resolved_variant is Dictionary:
		return resolved_variant as Dictionary
	return {}

func test_use_world_anchor_default_is_true() -> void:
	var mode: Resource = _new_mode()
	assert_true(bool(mode.get("use_world_anchor")))

func test_track_target_default_is_false() -> void:
	var mode: Resource = _new_mode()
	assert_false(bool(mode.get("track_target")))

func test_fov_default_is_seventy_five() -> void:
	var mode: Resource = _new_mode()
	assert_almost_eq(float(mode.get("fov")), 75.0, 0.0001)

func test_fov_resolves_to_valid_range() -> void:
	var mode: Resource = _new_mode()
	mode.set("fov", 0.0)
	var resolved_low: Dictionary = _resolved(mode)
	assert_almost_eq(float(resolved_low.get("fov", 0.0)), 1.0, 0.0001)

	mode.set("fov", 180.0)
	var resolved_high: Dictionary = _resolved(mode)
	assert_almost_eq(float(resolved_high.get("fov", 0.0)), 179.0, 0.0001)

func test_tracking_damping_default_is_five() -> void:
	var mode: Resource = _new_mode()
	assert_almost_eq(float(mode.get("tracking_damping")), 5.0, 0.0001)

func test_tracking_damping_resolves_non_negative() -> void:
	var mode: Resource = _new_mode()
	mode.set("tracking_damping", -1.0)
	var resolved_negative: Dictionary = _resolved(mode)
	assert_almost_eq(float(resolved_negative.get("tracking_damping", 0.0)), 0.0, 0.0001)

	mode.set("tracking_damping", 0.0)
	var resolved_zero: Dictionary = _resolved(mode)
	assert_almost_eq(float(resolved_zero.get("tracking_damping", -1.0)), 0.0, 0.0001)

func test_follow_offset_default_is_three_and_five() -> void:
	var mode: Resource = _new_mode()
	var follow_offset: Vector3 = mode.get("follow_offset") as Vector3
	assert_almost_eq(follow_offset.x, 0.0, 0.0001)
	assert_almost_eq(follow_offset.y, 3.0, 0.0001)
	assert_almost_eq(follow_offset.z, 5.0, 0.0001)

func test_follow_offset_value_is_preserved_when_use_world_anchor_toggles() -> void:
	var mode: Resource = _new_mode()
	var authored_offset := Vector3(2.0, 4.0, 6.0)
	mode.set("follow_offset", authored_offset)
	mode.set("use_world_anchor", true)
	var resolved_world_anchor: Dictionary = _resolved(mode)
	assert_eq(resolved_world_anchor.get("follow_offset"), authored_offset)

	mode.set("use_world_anchor", false)
	var resolved_follow_offset: Dictionary = _resolved(mode)
	assert_eq(resolved_follow_offset.get("follow_offset"), authored_offset)

func test_use_path_default_is_false() -> void:
	var mode: Resource = _new_mode()
	assert_false(bool(mode.get("use_path")))

func test_path_max_speed_default_is_ten() -> void:
	var mode: Resource = _new_mode()
	assert_almost_eq(float(mode.get("path_max_speed")), 10.0, 0.0001)

func test_path_max_speed_resolves_non_negative() -> void:
	var mode: Resource = _new_mode()
	mode.set("path_max_speed", -1.0)
	var resolved_negative: Dictionary = _resolved(mode)
	assert_almost_eq(float(resolved_negative.get("path_max_speed", 0.0)), 0.0, 0.0001)

	mode.set("path_max_speed", 0.0)
	var resolved_zero: Dictionary = _resolved(mode)
	assert_almost_eq(float(resolved_zero.get("path_max_speed", -1.0)), 0.0, 0.0001)

func test_path_damping_default_is_five() -> void:
	var mode: Resource = _new_mode()
	assert_almost_eq(float(mode.get("path_damping")), 5.0, 0.0001)

func test_path_damping_resolves_non_negative() -> void:
	var mode: Resource = _new_mode()
	mode.set("path_damping", -1.0)
	var resolved_negative: Dictionary = _resolved(mode)
	assert_almost_eq(float(resolved_negative.get("path_damping", 0.0)), 0.0, 0.0001)

	mode.set("path_damping", 0.0)
	var resolved_zero: Dictionary = _resolved(mode)
	assert_almost_eq(float(resolved_zero.get("path_damping", -1.0)), 0.0, 0.0001)
