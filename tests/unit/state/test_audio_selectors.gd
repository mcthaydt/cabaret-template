extends GutTest

# Tests for U_AudioSelectors (Phase 0 - Task 0.5)


# Test 1: get_master_volume with valid state
func test_get_master_volume_returns_value() -> void:
	var state := _make_state()
	state["audio"]["master_volume"] = 0.25
	assert_almost_eq(U_AudioSelectors.get_master_volume(state), 0.25, 0.0001)

# Test 2: get_music_volume with valid state
func test_get_music_volume_returns_value() -> void:
	var state := _make_state()
	state["audio"]["music_volume"] = 0.5
	assert_almost_eq(U_AudioSelectors.get_music_volume(state), 0.5, 0.0001)

# Test 3: get_sfx_volume with valid state
func test_get_sfx_volume_returns_value() -> void:
	var state := _make_state()
	state["audio"]["sfx_volume"] = 0.75
	assert_almost_eq(U_AudioSelectors.get_sfx_volume(state), 0.75, 0.0001)

# Test 4: get_ambient_volume with valid state
func test_get_ambient_volume_returns_value() -> void:
	var state := _make_state()
	state["audio"]["ambient_volume"] = 0.9
	assert_almost_eq(U_AudioSelectors.get_ambient_volume(state), 0.9, 0.0001)

# Test 5: is_master_muted with valid state
func test_is_master_muted_returns_value() -> void:
	var state := _make_state()
	state["audio"]["master_muted"] = true
	assert_true(U_AudioSelectors.is_master_muted(state))

# Test 6: is_music_muted with valid state
func test_is_music_muted_returns_value() -> void:
	var state := _make_state()
	state["audio"]["music_muted"] = true
	assert_true(U_AudioSelectors.is_music_muted(state))

# Test 7: is_sfx_muted with valid state
func test_is_sfx_muted_returns_value() -> void:
	var state := _make_state()
	state["audio"]["sfx_muted"] = true
	assert_true(U_AudioSelectors.is_sfx_muted(state))

# Test 8: is_ambient_muted with valid state
func test_is_ambient_muted_returns_value() -> void:
	var state := _make_state()
	state["audio"]["ambient_muted"] = true
	assert_true(U_AudioSelectors.is_ambient_muted(state))

# Test 9: is_spatial_audio_enabled with valid state
func test_is_spatial_audio_enabled_returns_value() -> void:
	var state := _make_state()
	state["audio"]["spatial_audio_enabled"] = false
	assert_false(U_AudioSelectors.is_spatial_audio_enabled(state))

# Test 10: Missing audio slice returns default volumes
func test_missing_audio_slice_returns_default_master_volume() -> void:
	assert_almost_eq(U_AudioSelectors.get_master_volume({}), 1.0, 0.0001)

# Test 11: Missing audio slice returns default mute
func test_missing_audio_slice_returns_default_master_muted() -> void:
	assert_false(U_AudioSelectors.is_master_muted({}))

# Test 12: Missing audio slice returns default spatial flag
func test_missing_audio_slice_returns_default_spatial_enabled() -> void:
	assert_true(U_AudioSelectors.is_spatial_audio_enabled({}))

# Test 13: Non-dictionary audio slice returns defaults
func test_audio_slice_wrong_type_returns_defaults() -> void:
	var state := {"audio": "not a dict"}
	assert_almost_eq(U_AudioSelectors.get_music_volume(state), 1.0, 0.0001)
	assert_false(U_AudioSelectors.is_master_muted(state))

# Test 14: Missing field returns default
func test_missing_field_returns_default() -> void:
	var state := {"audio": {"master_volume": 0.25}}
	assert_almost_eq(U_AudioSelectors.get_sfx_volume(state), 1.0, 0.0001)

# Test 15: Selectors do not mutate state
func test_selectors_do_not_mutate_state() -> void:
	var original_state := _make_state()
	original_state["audio"]["master_volume"] = 0.1
	var state_copy: Dictionary = original_state.duplicate(true)

	var _volume: float = U_AudioSelectors.get_master_volume(original_state)
	var _muted: bool = U_AudioSelectors.is_master_muted(original_state)
	var _spatial: bool = U_AudioSelectors.is_spatial_audio_enabled(original_state)

	assert_eq(original_state, state_copy, "Selectors should not mutate state")

func _make_state() -> Dictionary:
	return {
		"audio": {
			"master_volume": 1.0,
			"music_volume": 1.0,
			"sfx_volume": 1.0,
			"ambient_volume": 1.0,
			"master_muted": false,
			"music_muted": false,
			"sfx_muted": false,
			"ambient_muted": false,
			"spatial_audio_enabled": true
		}
	}
