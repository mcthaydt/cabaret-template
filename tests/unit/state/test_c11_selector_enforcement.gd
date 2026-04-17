extends GutTest

## C11: Selector Enforcement Tests — New Selectors
##
## Tests for new selectors added during C11 to support migration of ECS systems,
## helpers, interactables, and UI files from direct state.get() access to selectors.
## Covers: U_GameplaySelectors (completed_areas, game_completed, death_count),
##         U_InputSelectors (get_input_state_snapshot).


# ── U_GameplaySelectors: get_completed_areas ─────────────────────────────────

func test_gameplay_get_completed_areas_returns_array() -> void:
	var state := {"gameplay": {"completed_areas": ["area_a", "area_b"]}}
	var result: Array = U_GameplaySelectors.get_completed_areas(state)
	assert_eq(result.size(), 2, "Should return completed_areas array")
	assert_has(result, "area_a")
	assert_has(result, "area_b")

func test_gameplay_get_completed_areas_defaults_empty() -> void:
	var state := {"gameplay": {"paused": false}}
	var result: Array = U_GameplaySelectors.get_completed_areas(state)
	assert_eq(result.size(), 0, "Should default to empty array when missing")

func test_gameplay_get_completed_areas_handles_missing_slice() -> void:
	var state := {}
	var result: Array = U_GameplaySelectors.get_completed_areas(state)
	assert_eq(result.size(), 0, "Should default to empty array when slice missing")

func test_gameplay_get_completed_areas_returns_duplicate() -> void:
	var areas := ["zone_1", "zone_2"]
	var state := {"gameplay": {"completed_areas": areas}}
	var result: Array = U_GameplaySelectors.get_completed_areas(state)
	result.append("zone_3")
	var re_read: Array = U_GameplaySelectors.get_completed_areas(state)
	assert_eq(re_read.size(), 2, "Mutation of result should not affect state")


# ── U_GameplaySelectors: get_game_completed ───────────────────────────────────

func test_gameplay_get_game_completed_returns_true() -> void:
	var state := {"gameplay": {"game_completed": true}}
	assert_true(U_GameplaySelectors.get_game_completed(state), "Should return true when game_completed")

func test_gameplay_get_game_completed_returns_false() -> void:
	var state := {"gameplay": {"game_completed": false}}
	assert_false(U_GameplaySelectors.get_game_completed(state), "Should return false when game_completed is false")

func test_gameplay_get_game_completed_defaults_false() -> void:
	var state := {"gameplay": {"paused": false}}
	assert_false(U_GameplaySelectors.get_game_completed(state), "Should default to false when missing")

func test_gameplay_get_game_completed_handles_missing_slice() -> void:
	var state := {}
	assert_false(U_GameplaySelectors.get_game_completed(state), "Should default to false when slice missing")


# ── U_GameplaySelectors: get_death_count ─────────────────────────────────────

func test_gameplay_get_death_count_returns_value() -> void:
	var state := {"gameplay": {"death_count": 5}}
	assert_eq(U_GameplaySelectors.get_death_count(state), 5, "Should return death_count")

func test_gameplay_get_death_count_defaults_zero() -> void:
	var state := {"gameplay": {"paused": false}}
	assert_eq(U_GameplaySelectors.get_death_count(state), 0, "Should default to 0 when missing")

func test_gameplay_get_death_count_handles_missing_slice() -> void:
	var state := {}
	assert_eq(U_GameplaySelectors.get_death_count(state), 0, "Should default to 0 when slice missing")

func test_gameplay_get_death_count_handles_large_value() -> void:
	var state := {"gameplay": {"death_count": 99}}
	assert_eq(U_GameplaySelectors.get_death_count(state), 99, "Should return large death count")


# ── U_InputSelectors: get_input_state_snapshot ───────────────────────────────

func test_input_get_input_state_snapshot_from_gameplay_input() -> void:
	var state := {
		"gameplay": {
			"input": {"gamepad_connected": true, "gamepad_device_id": 0, "active_device": 1}
		}
	}
	var result: Dictionary = U_InputSelectors.get_input_state_snapshot(state)
	assert_true(bool(result.get("gamepad_connected", false)), "Should return gamepad_connected from gameplay.input")
	assert_eq(int(result.get("active_device", -1)), 1, "Should return active_device from gameplay.input")

func test_input_get_input_state_snapshot_empty_when_no_input() -> void:
	var state := {"gameplay": {"paused": false}}
	var result: Dictionary = U_InputSelectors.get_input_state_snapshot(state)
	assert_eq(result.size(), 0, "Should return empty dict when no input sub-state")

func test_input_get_input_state_snapshot_handles_missing_slice() -> void:
	var state := {}
	var result: Dictionary = U_InputSelectors.get_input_state_snapshot(state)
	assert_eq(result.size(), 0, "Should return empty dict when state is empty")

func test_input_get_input_state_snapshot_returns_duplicate() -> void:
	var state := {"gameplay": {"input": {"active_device": 1}}}
	var result: Dictionary = U_InputSelectors.get_input_state_snapshot(state)
	result["injected"] = true
	var re_read: Dictionary = U_InputSelectors.get_input_state_snapshot(state)
	assert_false(re_read.has("injected"), "Mutation of result should not affect internal state")
