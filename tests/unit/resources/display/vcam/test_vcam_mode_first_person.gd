extends GutTest

const MODE_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_mode_first_person.gd")

func _new_mode() -> Resource:
	return MODE_SCRIPT.new()

func _resolved(mode: Resource) -> Dictionary:
	var resolved_variant: Variant = mode.call("get_resolved_values")
	if resolved_variant is Dictionary:
		return resolved_variant as Dictionary
	return {}

func test_head_offset_default_is_player_head_height() -> void:
	var mode: Resource = _new_mode()
	var offset: Vector3 = mode.get("head_offset") as Vector3
	assert_almost_eq(offset.x, 0.0, 0.0001)
	assert_almost_eq(offset.y, 1.7, 0.0001)
	assert_almost_eq(offset.z, 0.0, 0.0001)

func test_look_multiplier_default_is_one() -> void:
	var mode: Resource = _new_mode()
	assert_almost_eq(float(mode.get("look_multiplier")), 1.0, 0.0001)

func test_pitch_min_default_is_negative_eighty_nine() -> void:
	var mode: Resource = _new_mode()
	assert_almost_eq(float(mode.get("pitch_min")), -89.0, 0.0001)

func test_pitch_max_default_is_positive_eighty_nine() -> void:
	var mode: Resource = _new_mode()
	assert_almost_eq(float(mode.get("pitch_max")), 89.0, 0.0001)

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

func test_look_multiplier_resolves_to_positive_value() -> void:
	var mode: Resource = _new_mode()
	mode.set("look_multiplier", 0.0)
	var resolved_zero: Dictionary = _resolved(mode)
	assert_true(float(resolved_zero.get("look_multiplier", 0.0)) > 0.0)

	mode.set("look_multiplier", -1.0)
	var resolved_negative: Dictionary = _resolved(mode)
	assert_true(float(resolved_negative.get("look_multiplier", 0.0)) > 0.0)

func test_pitch_bounds_resolve_when_inverted() -> void:
	var mode: Resource = _new_mode()
	mode.set("pitch_min", 10.0)
	mode.set("pitch_max", -10.0)
	var resolved: Dictionary = _resolved(mode)
	assert_almost_eq(float(resolved.get("pitch_min", 0.0)), -10.0, 0.0001)
	assert_almost_eq(float(resolved.get("pitch_max", 0.0)), 10.0, 0.0001)
