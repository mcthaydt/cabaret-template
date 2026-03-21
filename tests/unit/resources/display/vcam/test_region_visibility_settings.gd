extends GutTest

const RS_REGION_VISIBILITY_SETTINGS_SCRIPT := preload(
	"res://scripts/resources/display/vcam/rs_region_visibility_settings.gd"
)

func _new_settings() -> Resource:
	return RS_REGION_VISIBILITY_SETTINGS_SCRIPT.new()

func test_fade_speed_default_is_three() -> void:
	var settings := _new_settings()
	assert_almost_eq(float(settings.get("fade_speed")), 3.0, 0.0001)

func test_min_alpha_default_is_zero() -> void:
	var settings := _new_settings()
	assert_almost_eq(float(settings.get("min_alpha")), 0.0, 0.0001)

func test_aabb_grow_default_is_two() -> void:
	var settings := _new_settings()
	assert_almost_eq(float(settings.get("aabb_grow")), 2.0, 0.0001)

func test_aabb_vertical_shrink_default_is_point_five() -> void:
	var settings := _new_settings()
	assert_almost_eq(float(settings.get("aabb_vertical_shrink")), 0.5, 0.0001)

func test_fade_speed_is_clamped_non_negative() -> void:
	var settings := _new_settings()
	settings.set("fade_speed", -2.0)
	var resolved := settings.call("get_resolved_values") as Dictionary
	assert_almost_eq(float(resolved.get("fade_speed", -1.0)), 0.0, 0.0001)

func test_min_alpha_is_clamped_to_zero_to_one() -> void:
	var settings := _new_settings()
	settings.set("min_alpha", 2.0)
	var resolved_hi := settings.call("get_resolved_values") as Dictionary
	assert_almost_eq(float(resolved_hi.get("min_alpha", -1.0)), 1.0, 0.0001)
	settings.set("min_alpha", -2.0)
	var resolved_lo := settings.call("get_resolved_values") as Dictionary
	assert_almost_eq(float(resolved_lo.get("min_alpha", -1.0)), 0.0, 0.0001)

func test_aabb_grow_is_clamped_non_negative() -> void:
	var settings := _new_settings()
	settings.set("aabb_grow", -1.0)
	var resolved := settings.call("get_resolved_values") as Dictionary
	assert_almost_eq(float(resolved.get("aabb_grow", -1.0)), 0.0, 0.0001)

func test_aabb_vertical_shrink_is_clamped_non_negative() -> void:
	var settings := _new_settings()
	settings.set("aabb_vertical_shrink", -1.0)
	var resolved := settings.call("get_resolved_values") as Dictionary
	assert_almost_eq(float(resolved.get("aabb_vertical_shrink", -1.0)), 0.0, 0.0001)

func test_resolved_values_contains_expected_keys() -> void:
	var settings := _new_settings()
	var resolved := settings.call("get_resolved_values") as Dictionary
	assert_true(resolved.has("fade_speed"))
	assert_true(resolved.has("min_alpha"))
	assert_true(resolved.has("aabb_grow"))
	assert_true(resolved.has("aabb_vertical_shrink"))
