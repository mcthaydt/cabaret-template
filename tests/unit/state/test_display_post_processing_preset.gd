extends GutTest

## Tests for post-processing preset actions and reducer


func test_set_post_processing_preset_action_structure() -> void:
	# WHEN: Creating a set post-processing preset action
	var action := U_DisplayActions.set_post_processing_preset("medium")

	# THEN: Action should have correct structure
	assert_eq(action.get("type"), U_DisplayActions.ACTION_SET_POST_PROCESSING_PRESET, "Action type should be set_post_processing_preset")
	assert_eq(action.get("payload", {}).get("preset"), "medium", "Payload should contain preset value")

func test_reducer_sets_post_processing_preset() -> void:
	# GIVEN: Initial state with light preset
	var state := {"post_processing_preset": "light"}

	# WHEN: Setting post-processing preset to heavy
	var action := U_DisplayActions.set_post_processing_preset("heavy")
	var new_state: Variant = U_DisplayReducer.reduce(state, action)

	# THEN: Preset should be updated
	assert_not_null(new_state, "Reducer should return new state")
	if new_state is Dictionary:
		assert_eq(new_state.get("post_processing_preset"), "heavy", "Preset should be updated to heavy")

func test_reducer_rejects_invalid_post_processing_preset() -> void:
	# GIVEN: Initial state with medium preset
	var state := {"post_processing_preset": "medium"}

	# WHEN: Setting invalid preset
	var action := U_DisplayActions.set_post_processing_preset("invalid")
	var new_state: Variant = U_DisplayReducer.reduce(state, action)

	# THEN: State should not change
	assert_null(new_state, "Reducer should return null for invalid preset")

func test_selector_gets_post_processing_preset() -> void:
	# GIVEN: State with heavy preset
	var state := {"display": {"post_processing_preset": "heavy"}}

	# WHEN: Getting preset via selector
	var preset: String = U_DisplaySelectors.get_post_processing_preset(state)

	# THEN: Should return correct preset
	assert_eq(preset, "heavy", "Selector should return post_processing_preset from state")

func test_selector_returns_default_when_preset_missing() -> void:
	# GIVEN: State without post_processing_preset
	var state := {"display": {}}

	# WHEN: Getting preset via selector
	var preset: String = U_DisplaySelectors.get_post_processing_preset(state)

	# THEN: Should return default (medium)
	assert_eq(preset, "medium", "Selector should return 'medium' as default")

func test_default_state_has_medium_preset() -> void:
	# GIVEN: Default display state
	var default_state := U_DisplayReducer.get_default_display_state()

	# THEN: Should have medium as default
	assert_eq(default_state.get("post_processing_preset"), "medium", "Default preset should be medium")
