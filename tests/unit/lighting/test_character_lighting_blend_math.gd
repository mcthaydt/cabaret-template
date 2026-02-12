extends GutTest

const BLEND_MATH_PATH := "res://scripts/utils/lighting/u_character_lighting_blend_math.gd"


func _blend_script() -> Script:
	var script_obj := load(BLEND_MATH_PATH) as Script
	assert_not_null(script_obj, "Blend math utility should load: %s" % BLEND_MATH_PATH)
	return script_obj

func test_blend_uses_default_profile_when_no_zones_match() -> void:
	var script_obj := _blend_script()
	if script_obj == null:
		return

	var default_profile := {
		"tint": Color(0.4, 0.5, 0.6, 1.0),
		"intensity": 1.25,
		"blend_smoothing": 0.35,
	}

	var result: Dictionary = script_obj.call("blend_zone_profiles", [], default_profile)
	assert_eq(result.get("tint"), Color(0.4, 0.5, 0.6, 1.0))
	assert_almost_eq(float(result.get("intensity", -1.0)), 1.25, 0.0001)
	assert_almost_eq(float(result.get("blend_smoothing", -1.0)), 0.35, 0.0001)

	var first_sources: Array = result.get("sources", [])
	first_sources.append({"zone_id": StringName("mutated")})

	var second: Dictionary = script_obj.call("blend_zone_profiles", [], default_profile)
	var second_sources: Array = second.get("sources", [])
	assert_eq(second_sources.size(), 0, "Returned sources should be deep-copied per call")

func test_blend_normalizes_weights_for_tint_and_intensity() -> void:
	var script_obj := _blend_script()
	if script_obj == null:
		return

	var zones := [
		{
			"zone_id": StringName("zone_a"),
			"priority": 1,
			"weight": 0.25,
			"profile": {"tint": Color(1.0, 0.0, 0.0, 1.0), "intensity": 2.0, "blend_smoothing": 0.4}
		},
		{
			"zone_id": StringName("zone_b"),
			"priority": 1,
			"weight": 0.75,
			"profile": {"tint": Color(0.0, 0.0, 1.0, 1.0), "intensity": 0.0, "blend_smoothing": 0.0}
		},
	]
	var fallback := {
		"tint": Color(1.0, 1.0, 1.0, 1.0),
		"intensity": 1.0,
		"blend_smoothing": 0.15,
	}

	var result: Dictionary = script_obj.call("blend_zone_profiles", zones, fallback)
	var tint: Color = result.get("tint", Color.WHITE)
	assert_almost_eq(tint.r, 0.25, 0.0001)
	assert_almost_eq(tint.g, 0.0, 0.0001)
	assert_almost_eq(tint.b, 0.75, 0.0001)
	assert_almost_eq(float(result.get("intensity", -1.0)), 0.5, 0.0001)
	assert_almost_eq(float(result.get("blend_smoothing", -1.0)), 0.1, 0.0001)

func test_blend_sources_are_sorted_deterministically() -> void:
	var script_obj := _blend_script()
	if script_obj == null:
		return

	var zones := [
		{
			"zone_id": StringName("zone_b"),
			"priority": 1,
			"weight": 0.5,
			"profile": {"tint": Color.WHITE, "intensity": 1.0, "blend_smoothing": 0.1}
		},
		{
			"zone_id": StringName("zone_a"),
			"priority": 1,
			"weight": 0.5,
			"profile": {"tint": Color.WHITE, "intensity": 1.0, "blend_smoothing": 0.1}
		},
		{
			"zone_id": StringName("zone_top"),
			"priority": 3,
			"weight": 0.1,
			"profile": {"tint": Color.WHITE, "intensity": 1.0, "blend_smoothing": 0.1}
		},
	]

	var result: Dictionary = script_obj.call("blend_zone_profiles", zones, {})
	var sources: Array = result.get("sources", [])
	assert_eq(sources.size(), 3)

	var first: Dictionary = sources[0]
	var second: Dictionary = sources[1]
	var third: Dictionary = sources[2]
	assert_eq(first.get("zone_id", StringName("")), StringName("zone_top"))
	assert_eq(second.get("zone_id", StringName("")), StringName("zone_a"))
	assert_eq(third.get("zone_id", StringName("")), StringName("zone_b"))

func test_blend_accepts_blend_weight_key_from_zone_config_snapshots() -> void:
	var script_obj := _blend_script()
	if script_obj == null:
		return

	var zones := [
		{
			"zone_id": StringName("zone_a"),
			"priority": 0,
			"blend_weight": 1.0,
			"profile": {"tint": Color(0.2, 0.4, 0.6, 1.0), "intensity": 2.0, "blend_smoothing": 0.25}
		}
	]

	var result: Dictionary = script_obj.call("blend_zone_profiles", zones, {})
	assert_eq(result.get("tint"), Color(0.2, 0.4, 0.6, 1.0))
	assert_almost_eq(float(result.get("intensity", -1.0)), 2.0, 0.0001)
	assert_almost_eq(float(result.get("blend_smoothing", -1.0)), 0.25, 0.0001)

func test_blend_partially_mixes_default_profile_when_zone_weight_is_below_one() -> void:
	var script_obj := _blend_script()
	if script_obj == null:
		return

	var zones := [
		{
			"zone_id": StringName("zone_partial"),
			"priority": 0,
			"weight": 0.25,
			"profile": {
				"tint": Color(1.0, 0.0, 0.0, 1.0),
				"intensity": 2.0,
				"blend_smoothing": 0.4,
			}
		}
	]
	var default_profile := {
		"tint": Color(0.2, 0.4, 0.6, 1.0),
		"intensity": 1.0,
		"blend_smoothing": 0.2,
	}

	var result: Dictionary = script_obj.call("blend_zone_profiles", zones, default_profile)
	var tint: Color = result.get("tint", Color.WHITE)
	assert_almost_eq(tint.r, 0.4, 0.0001)
	assert_almost_eq(tint.g, 0.3, 0.0001)
	assert_almost_eq(tint.b, 0.45, 0.0001)
	assert_almost_eq(float(result.get("intensity", -1.0)), 1.25, 0.0001)
	assert_almost_eq(float(result.get("blend_smoothing", -1.0)), 0.25, 0.0001)

func test_blend_is_permutation_invariant_for_equal_priority_weights() -> void:
	var script_obj := _blend_script()
	if script_obj == null:
		return

	var zones_a := [
		{
			"zone_id": StringName("zone_a"),
			"priority": 2,
			"weight": 0.333333,
			"profile": {"tint": Color(1.0, 0.0, 0.0, 1.0), "intensity": 1.0, "blend_smoothing": 0.1}
		},
		{
			"zone_id": StringName("zone_b"),
			"priority": 2,
			"weight": 0.333333,
			"profile": {"tint": Color(0.0, 1.0, 0.0, 1.0), "intensity": 2.0, "blend_smoothing": 0.3}
		},
		{
			"zone_id": StringName("zone_c"),
			"priority": 2,
			"weight": 0.333333,
			"profile": {"tint": Color(0.0, 0.0, 1.0, 1.0), "intensity": 3.0, "blend_smoothing": 0.5}
		},
	]
	var zones_b := [
		zones_a[2],
		zones_a[0],
		zones_a[1],
	]

	var result_a: Dictionary = script_obj.call("blend_zone_profiles", zones_a, {})
	var result_b: Dictionary = script_obj.call("blend_zone_profiles", zones_b, {})

	var tint_a: Color = result_a.get("tint", Color.WHITE)
	var tint_b: Color = result_b.get("tint", Color.WHITE)
	assert_almost_eq(tint_a.r, tint_b.r, 0.0001)
	assert_almost_eq(tint_a.g, tint_b.g, 0.0001)
	assert_almost_eq(tint_a.b, tint_b.b, 0.0001)
	assert_almost_eq(float(result_a.get("intensity", -1.0)), float(result_b.get("intensity", -1.0)), 0.0001)
	assert_almost_eq(
		float(result_a.get("blend_smoothing", -1.0)),
		float(result_b.get("blend_smoothing", -1.0)),
		0.0001
	)

	var sources_a: Array = result_a.get("sources", [])
	var sources_b: Array = result_b.get("sources", [])
	assert_eq(sources_a.size(), 3)
	assert_eq(sources_b.size(), 3)
	assert_eq((sources_a[0] as Dictionary).get("zone_id", StringName("")), StringName("zone_a"))
	assert_eq((sources_a[1] as Dictionary).get("zone_id", StringName("")), StringName("zone_b"))
	assert_eq((sources_a[2] as Dictionary).get("zone_id", StringName("")), StringName("zone_c"))
	assert_eq((sources_b[0] as Dictionary).get("zone_id", StringName("")), StringName("zone_a"))
	assert_eq((sources_b[1] as Dictionary).get("zone_id", StringName("")), StringName("zone_b"))
	assert_eq((sources_b[2] as Dictionary).get("zone_id", StringName("")), StringName("zone_c"))
