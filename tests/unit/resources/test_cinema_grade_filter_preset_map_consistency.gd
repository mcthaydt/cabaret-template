extends GutTest

# TDD: Test filter preset map consistency across codebase (M1)
# Bug: FILTER_PRESET_MAP is duplicated in 3 places - easy to get out of sync

const RS_SCENE_CINEMA_GRADE := preload("res://scripts/resources/display/rs_scene_cinema_grade.gd")
const U_DISPLAY_REDUCER := preload("res://scripts/state/reducers/u_display_reducer.gd")

# FAILING TEST: Reducer should use the same filter preset map as the resource
func test_reducer_uses_resource_filter_map() -> void:
	# The reducer has its own copy of FILTER_PRESET_MAP at line 264-276
	# It should delegate to RS_SceneCinemaGrade.FILTER_PRESET_MAP instead

	# Test a few key mappings
	var test_presets := ["none", "dramatic", "vivid", "black_and_white", "sepia"]

	for preset_name in test_presets:
		# Get the expected value from the resource (source of truth)
		var expected_mode: int = RS_SCENE_CINEMA_GRADE.FILTER_PRESET_MAP.get(preset_name, -1)
		assert_ne(expected_mode, -1, "Preset '%s' should exist in resource map" % preset_name)

		# Simulate the reducer's conversion
		var action := {
			"type": StringName("cinema_grade/set_parameter"),
			"payload": {
				"param_name": "filter_preset",
				"value": preset_name
			}
		}

		var current_state := {
			"cinema_grade_filter_mode": 0,
			"cinema_grade_filter_preset": "none"
		}

		var next_state: Variant = U_DISPLAY_REDUCER.reduce(current_state, action)
		assert_not_null(next_state, "Reducer should handle filter_preset change")

		if next_state is Dictionary:
			var actual_mode: int = int(next_state.get("cinema_grade_filter_mode", -1))
			assert_eq(
				actual_mode,
				expected_mode,
				"Reducer should map '%s' to mode %d (matching resource)" % [preset_name, expected_mode]
			)

# FAILING TEST: All presets in resource map should be handled by reducer
func test_all_resource_presets_handled_by_reducer() -> void:
	var resource_presets := RS_SCENE_CINEMA_GRADE.FILTER_PRESET_MAP.keys()

	for preset_name in resource_presets:
		var action := {
			"type": StringName("cinema_grade/set_parameter"),
			"payload": {
				"param_name": "filter_preset",
				"value": preset_name
			}
		}

		var current_state := {
			"cinema_grade_filter_mode": 0,
			"cinema_grade_filter_preset": "none"
		}

		var next_state: Variant = U_DISPLAY_REDUCER.reduce(current_state, action)
		assert_not_null(
			next_state,
			"Reducer should handle preset '%s' from resource map" % preset_name
		)

		if next_state is Dictionary:
			var mode: int = int(next_state.get("cinema_grade_filter_mode", -1))
			var expected_mode: int = RS_SCENE_CINEMA_GRADE.FILTER_PRESET_MAP[preset_name]
			assert_eq(
				mode,
				expected_mode,
				"Preset '%s' should map to mode %d" % [preset_name, expected_mode]
			)

# Edge case: Unknown preset should map to 0 (none)
func test_unknown_preset_maps_to_none() -> void:
	var action := {
		"type": StringName("cinema_grade/set_parameter"),
		"payload": {
			"param_name": "filter_preset",
			"value": "invalid_preset_name"
		}
	}

	var current_state := {
		"cinema_grade_filter_mode": 5,  # Start with something else
		"cinema_grade_filter_preset": "vivid"
	}

	var next_state: Variant = U_DISPLAY_REDUCER.reduce(current_state, action)

	if next_state is Dictionary:
		var mode: int = int(next_state.get("cinema_grade_filter_mode", -1))
		assert_eq(
			mode,
			0,
			"Unknown preset should map to mode 0 (none/default)"
		)
