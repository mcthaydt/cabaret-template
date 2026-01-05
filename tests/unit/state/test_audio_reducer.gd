extends GutTest

# Tests for U_AudioReducer (Phase 0 - Task 0.3)

const U_AudioReducer := preload("res://scripts/state/reducers/u_audio_reducer.gd")
const U_AudioActions := preload("res://scripts/state/actions/u_audio_actions.gd")

# Test 1: Default state structure
func test_default_state_has_all_fields() -> void:
	var default_state: Dictionary = U_AudioReducer.get_default_audio_state()

	assert_true(default_state.has("master_volume"), "Default state should have master_volume")
	assert_true(default_state.has("music_volume"), "Default state should have music_volume")
	assert_true(default_state.has("sfx_volume"), "Default state should have sfx_volume")
	assert_true(default_state.has("ambient_volume"), "Default state should have ambient_volume")
	assert_true(default_state.has("master_muted"), "Default state should have master_muted")
	assert_true(default_state.has("music_muted"), "Default state should have music_muted")
	assert_true(default_state.has("sfx_muted"), "Default state should have sfx_muted")
	assert_true(default_state.has("ambient_muted"), "Default state should have ambient_muted")
	assert_true(default_state.has("spatial_audio_enabled"), "Default state should have spatial_audio_enabled")

# Test 2: Default values are sensible
func test_default_state_has_expected_defaults() -> void:
	var default_state: Dictionary = U_AudioReducer.get_default_audio_state()

	assert_almost_eq(float(default_state.get("master_volume", 0.0)), 1.0, 0.0001)
	assert_almost_eq(float(default_state.get("music_volume", 0.0)), 1.0, 0.0001)
	assert_almost_eq(float(default_state.get("sfx_volume", 0.0)), 1.0, 0.0001)
	assert_almost_eq(float(default_state.get("ambient_volume", 0.0)), 1.0, 0.0001)
	assert_false(bool(default_state.get("master_muted", true)))
	assert_false(bool(default_state.get("music_muted", true)))
	assert_false(bool(default_state.get("sfx_muted", true)))
	assert_false(bool(default_state.get("ambient_muted", true)))
	assert_true(bool(default_state.get("spatial_audio_enabled", false)))

# Test 3: set_master_volume updates volume
func test_set_master_volume_updates_volume() -> void:
	var state := _make_audio_state(1.0, false)
	var action := U_AudioActions.set_master_volume(0.5)
	var reduced: Dictionary = U_AudioReducer.reduce(state, action)

	assert_almost_eq(float(reduced.get("master_volume", 0.0)), 0.5, 0.0001)
	assert_eq(reduced.get("master_muted"), false, "Mute should remain unchanged when volume changes")

# Test 4: set_master_volume clamps lower bound
func test_set_master_volume_clamps_lower_bound() -> void:
	var state := _make_audio_state(1.0, false)
	var action := U_AudioActions.set_master_volume(-0.5)
	var reduced: Dictionary = U_AudioReducer.reduce(state, action)

	assert_almost_eq(float(reduced.get("master_volume", -1.0)), 0.0, 0.0001)

# Test 5: set_master_volume clamps upper bound
func test_set_master_volume_clamps_upper_bound() -> void:
	var state := _make_audio_state(1.0, false)
	var action := U_AudioActions.set_master_volume(2.0)
	var reduced: Dictionary = U_AudioReducer.reduce(state, action)

	assert_almost_eq(float(reduced.get("master_volume", -1.0)), 1.0, 0.0001)

# Test 6: set_music_volume updates volume
func test_set_music_volume_updates_volume() -> void:
	var state := _make_audio_state(1.0, false)
	var action := U_AudioActions.set_music_volume(0.25)
	var reduced: Dictionary = U_AudioReducer.reduce(state, action)

	assert_almost_eq(float(reduced.get("music_volume", 0.0)), 0.25, 0.0001)

# Test 7: set_music_volume clamps lower bound
func test_set_music_volume_clamps_lower_bound() -> void:
	var state := _make_audio_state(1.0, false)
	var action := U_AudioActions.set_music_volume(-0.1)
	var reduced: Dictionary = U_AudioReducer.reduce(state, action)

	assert_almost_eq(float(reduced.get("music_volume", -1.0)), 0.0, 0.0001)

# Test 8: set_music_volume clamps upper bound
func test_set_music_volume_clamps_upper_bound() -> void:
	var state := _make_audio_state(1.0, false)
	var action := U_AudioActions.set_music_volume(1.1)
	var reduced: Dictionary = U_AudioReducer.reduce(state, action)

	assert_almost_eq(float(reduced.get("music_volume", -1.0)), 1.0, 0.0001)

# Test 9: set_sfx_volume updates volume
func test_set_sfx_volume_updates_volume() -> void:
	var state := _make_audio_state(1.0, false)
	var action := U_AudioActions.set_sfx_volume(0.75)
	var reduced: Dictionary = U_AudioReducer.reduce(state, action)

	assert_almost_eq(float(reduced.get("sfx_volume", 0.0)), 0.75, 0.0001)

# Test 10: set_sfx_volume clamps lower bound
func test_set_sfx_volume_clamps_lower_bound() -> void:
	var state := _make_audio_state(1.0, false)
	var action := U_AudioActions.set_sfx_volume(-1.0)
	var reduced: Dictionary = U_AudioReducer.reduce(state, action)

	assert_almost_eq(float(reduced.get("sfx_volume", -1.0)), 0.0, 0.0001)

# Test 11: set_sfx_volume clamps upper bound
func test_set_sfx_volume_clamps_upper_bound() -> void:
	var state := _make_audio_state(1.0, false)
	var action := U_AudioActions.set_sfx_volume(999.0)
	var reduced: Dictionary = U_AudioReducer.reduce(state, action)

	assert_almost_eq(float(reduced.get("sfx_volume", -1.0)), 1.0, 0.0001)

# Test 12: set_ambient_volume updates volume
func test_set_ambient_volume_updates_volume() -> void:
	var state := _make_audio_state(1.0, false)
	var action := U_AudioActions.set_ambient_volume(0.9)
	var reduced: Dictionary = U_AudioReducer.reduce(state, action)

	assert_almost_eq(float(reduced.get("ambient_volume", 0.0)), 0.9, 0.0001)

# Test 13: set_ambient_volume clamps lower bound
func test_set_ambient_volume_clamps_lower_bound() -> void:
	var state := _make_audio_state(1.0, false)
	var action := U_AudioActions.set_ambient_volume(-2.0)
	var reduced: Dictionary = U_AudioReducer.reduce(state, action)

	assert_almost_eq(float(reduced.get("ambient_volume", -1.0)), 0.0, 0.0001)

# Test 14: set_ambient_volume clamps upper bound
func test_set_ambient_volume_clamps_upper_bound() -> void:
	var state := _make_audio_state(1.0, false)
	var action := U_AudioActions.set_ambient_volume(2.5)
	var reduced: Dictionary = U_AudioReducer.reduce(state, action)

	assert_almost_eq(float(reduced.get("ambient_volume", -1.0)), 1.0, 0.0001)

# Test 15: set_master_muted updates mute
func test_set_master_muted_updates_mute() -> void:
	var state := _make_audio_state(1.0, false)
	var action := U_AudioActions.set_master_muted(true)
	var reduced: Dictionary = U_AudioReducer.reduce(state, action)

	assert_true(bool(reduced.get("master_muted", false)))

# Test 16: set_music_muted updates mute
func test_set_music_muted_updates_mute() -> void:
	var state := _make_audio_state(1.0, false)
	var action := U_AudioActions.set_music_muted(true)
	var reduced: Dictionary = U_AudioReducer.reduce(state, action)

	assert_true(bool(reduced.get("music_muted", false)))

# Test 17: set_sfx_muted updates mute
func test_set_sfx_muted_updates_mute() -> void:
	var state := _make_audio_state(1.0, false)
	var action := U_AudioActions.set_sfx_muted(true)
	var reduced: Dictionary = U_AudioReducer.reduce(state, action)

	assert_true(bool(reduced.get("sfx_muted", false)))

# Test 18: set_ambient_muted updates mute
func test_set_ambient_muted_updates_mute() -> void:
	var state := _make_audio_state(1.0, false)
	var action := U_AudioActions.set_ambient_muted(true)
	var reduced: Dictionary = U_AudioReducer.reduce(state, action)

	assert_true(bool(reduced.get("ambient_muted", false)))

# Test 19: set_spatial_audio_enabled updates flag
func test_set_spatial_audio_enabled_updates_flag() -> void:
	var state := _make_audio_state(1.0, false)
	var action := U_AudioActions.set_spatial_audio_enabled(false)
	var reduced: Dictionary = U_AudioReducer.reduce(state, action)

	assert_false(bool(reduced.get("spatial_audio_enabled", true)))

# Test 20: toggle_master_mute flips from false to true
func test_toggle_master_mute_flips_on() -> void:
	var state := _make_audio_state(1.0, false)
	var action := U_AudioActions.toggle_master_mute()
	var reduced: Dictionary = U_AudioReducer.reduce(state, action)

	assert_true(bool(reduced.get("master_muted", false)))

# Test 21: toggle_master_mute flips from true to false
func test_toggle_master_mute_flips_off() -> void:
	var state := _make_audio_state(1.0, true)
	var action := U_AudioActions.toggle_master_mute()
	var reduced: Dictionary = U_AudioReducer.reduce(state, action)

	assert_false(bool(reduced.get("master_muted", true)))

# Test 22: toggle_music_mute flips music_muted
func test_toggle_music_mute_flips() -> void:
	var state := _make_audio_state(1.0, false)
	var action := U_AudioActions.toggle_music_mute()
	var reduced: Dictionary = U_AudioReducer.reduce(state, action)

	assert_true(bool(reduced.get("music_muted", false)))

# Test 23: toggle_sfx_mute flips sfx_muted
func test_toggle_sfx_mute_flips() -> void:
	var state := _make_audio_state(1.0, false)
	var action := U_AudioActions.toggle_sfx_mute()
	var reduced: Dictionary = U_AudioReducer.reduce(state, action)

	assert_true(bool(reduced.get("sfx_muted", false)))

# Test 24: Reducer is immutable
func test_reducer_immutability() -> void:
	var state := _make_audio_state(1.0, false)
	var original_copy: Dictionary = state.duplicate(true)
	var action := U_AudioActions.set_master_volume(0.1)
	var reduced: Dictionary = U_AudioReducer.reduce(state, action)

	assert_ne(state, reduced, "Reducer should return a new state object")
	assert_eq(state, original_copy, "Original state should remain unchanged")

# Test 25: Unknown action returns null (no change)
func test_unhandled_action_returns_null() -> void:
	var state := _make_audio_state(1.0, false)
	var action := {"type": StringName("audio/unknown_action")}
	var reduced: Variant = U_AudioReducer.reduce(state, action)

	assert_null(reduced, "Unknown action should return null (indicating no change)")

# Helper: Create Audio state for testing
func _make_audio_state(master_volume: float, master_muted: bool) -> Dictionary:
	return {
		"master_volume": master_volume,
		"music_volume": 1.0,
		"sfx_volume": 1.0,
		"ambient_volume": 1.0,
		"master_muted": master_muted,
		"music_muted": false,
		"sfx_muted": false,
		"ambient_muted": false,
		"spatial_audio_enabled": true,
	}

