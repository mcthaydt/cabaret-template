extends GutTest

# Tests for RS_AudioInitialState resource (Phase 0 - Task 0.1)

const RS_AudioInitialState := preload("res://scripts/resources/state/rs_audio_initial_state.gd")
const U_AudioReducer := preload("res://scripts/state/reducers/u_audio_reducer.gd")

var initial_state: RS_AudioInitialState

func before_each() -> void:
	initial_state = RS_AudioInitialState.new()

func after_each() -> void:
	initial_state = null

# Test 1: Has master_volume field
func test_has_master_volume_field() -> void:
	assert_true(
		"master_volume" in initial_state,
		"RS_AudioInitialState should have master_volume field"
	)

# Test 2: Has music_volume field
func test_has_music_volume_field() -> void:
	assert_true(
		"music_volume" in initial_state,
		"RS_AudioInitialState should have music_volume field"
	)

# Test 3: Has sfx_volume field
func test_has_sfx_volume_field() -> void:
	assert_true(
		"sfx_volume" in initial_state,
		"RS_AudioInitialState should have sfx_volume field"
	)

# Test 4: Has ambient_volume field
func test_has_ambient_volume_field() -> void:
	assert_true(
		"ambient_volume" in initial_state,
		"RS_AudioInitialState should have ambient_volume field"
	)

# Test 5: Has master_muted field
func test_has_master_muted_field() -> void:
	assert_true(
		"master_muted" in initial_state,
		"RS_AudioInitialState should have master_muted field"
	)

# Test 6: Has music_muted field
func test_has_music_muted_field() -> void:
	assert_true(
		"music_muted" in initial_state,
		"RS_AudioInitialState should have music_muted field"
	)

# Test 7: Has sfx_muted field
func test_has_sfx_muted_field() -> void:
	assert_true(
		"sfx_muted" in initial_state,
		"RS_AudioInitialState should have sfx_muted field"
	)

# Test 8: Has ambient_muted field
func test_has_ambient_muted_field() -> void:
	assert_true(
		"ambient_muted" in initial_state,
		"RS_AudioInitialState should have ambient_muted field"
	)

# Test 9: Has spatial_audio_enabled field
func test_has_spatial_audio_enabled_field() -> void:
	assert_true(
		"spatial_audio_enabled" in initial_state,
		"RS_AudioInitialState should have spatial_audio_enabled field"
	)

# Test 10: to_dictionary returns all fields
func test_to_dictionary_returns_all_fields() -> void:
	var dict: Dictionary = initial_state.to_dictionary()

	assert_true(dict.has("master_volume"), "to_dictionary should include master_volume")
	assert_true(dict.has("music_volume"), "to_dictionary should include music_volume")
	assert_true(dict.has("sfx_volume"), "to_dictionary should include sfx_volume")
	assert_true(dict.has("ambient_volume"), "to_dictionary should include ambient_volume")
	assert_true(dict.has("master_muted"), "to_dictionary should include master_muted")
	assert_true(dict.has("music_muted"), "to_dictionary should include music_muted")
	assert_true(dict.has("sfx_muted"), "to_dictionary should include sfx_muted")
	assert_true(dict.has("ambient_muted"), "to_dictionary should include ambient_muted")
	assert_true(dict.has("spatial_audio_enabled"), "to_dictionary should include spatial_audio_enabled")

# Test 11: Defaults match reducer defaults
func test_defaults_match_reducer_defaults() -> void:
	var defaults: Dictionary = U_AudioReducer.get_default_audio_state()
	var dict: Dictionary = initial_state.to_dictionary()

	assert_eq(dict.get("master_volume"), defaults.get("master_volume"))
	assert_eq(dict.get("music_volume"), defaults.get("music_volume"))
	assert_eq(dict.get("sfx_volume"), defaults.get("sfx_volume"))
	assert_eq(dict.get("ambient_volume"), defaults.get("ambient_volume"))
	assert_eq(dict.get("master_muted"), defaults.get("master_muted"))
	assert_eq(dict.get("music_muted"), defaults.get("music_muted"))
	assert_eq(dict.get("sfx_muted"), defaults.get("sfx_muted"))
	assert_eq(dict.get("ambient_muted"), defaults.get("ambient_muted"))
	assert_eq(dict.get("spatial_audio_enabled"), defaults.get("spatial_audio_enabled"))

