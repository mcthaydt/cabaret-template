extends GutTest

## Tests for RS_InputProfile schema validation (F15).
##
## Validates that required fields and structure push_error when set to
## invalid values, and that valid values produce no errors.

const RS_INPUT_PROFILE_PATH := "res://scripts/resources/input/rs_input_profile.gd"
const TEST_RESOURCE_PATH := "res://tests/unit/resources/test_cfg_input_profile_invalid.tres"


func test_empty_profile_name_pushes_error() -> void:
	var profile := RS_InputProfile.new()
	autofree(profile)
	profile.profile_name = ""
	assert_push_error("profile_name must not be empty")


func test_empty_action_mappings_pushes_error_when_loaded() -> void:
	var profile := RS_InputProfile.new()
	autofree(profile)
	# Simulate a loaded .tres resource — only loaded profiles require non-empty mappings.
	profile.resource_path = TEST_RESOURCE_PATH
	profile.action_mappings = {}
	assert_push_error("action_mappings must not be empty")


func test_empty_action_mappings_allowed_for_new_profile() -> void:
	var profile := RS_InputProfile.new()
	autofree(profile)
	# Programmatic creation (no resource_path) should allow empty mappings.
	profile.action_mappings = {}
	assert_push_error(0, "empty mappings should not push errors for new profiles")


func test_virtual_buttons_missing_action_key_pushes_error() -> void:
	var profile := RS_InputProfile.new()
	autofree(profile)
	profile.virtual_buttons = [
		{"position": Vector2(100, 200)},
	]
	assert_push_error("missing 'action' key")


func test_virtual_buttons_missing_position_key_pushes_error() -> void:
	var profile := RS_InputProfile.new()
	autofree(profile)
	profile.virtual_buttons = [
		{"action": StringName("jump")},
	]
	assert_push_error("missing 'position' key")


func test_virtual_buttons_empty_dictionary_pushes_error() -> void:
	var profile := RS_InputProfile.new()
	autofree(profile)
	profile.virtual_buttons = [
		{},
	]
	assert_push_error("missing 'action' key")
	assert_push_error("missing 'position' key")


func test_valid_virtual_buttons_no_error() -> void:
	var profile := RS_InputProfile.new()
	autofree(profile)
	profile.virtual_buttons = [
		{"action": StringName("jump"), "position": Vector2(100, 200)},
		{"action": StringName("sprint"), "position": Vector2(200, 300)},
	]
	assert_push_error(0, "valid virtual buttons should not push errors")


func test_valid_profile_produces_no_errors() -> void:
	var profile := RS_InputProfile.new()
	autofree(profile)
	profile.profile_name = "Test Profile"
	profile.action_mappings = {StringName("jump"): []}
	profile.virtual_buttons = [
		{"action": StringName("jump"), "position": Vector2(100, 200)},
	]
	assert_push_error(0, "valid profile should produce no errors")


func test_error_includes_resource_path() -> void:
	var profile := RS_InputProfile.new()
	autofree(profile)
	profile.resource_path = TEST_RESOURCE_PATH
	profile.profile_name = ""
	assert_push_error(TEST_RESOURCE_PATH)


func test_virtual_joystick_position_negative_coordinates_pushes_error() -> void:
	var profile := RS_InputProfile.new()
	autofree(profile)
	profile.virtual_joystick_position = Vector2(-50, 100)
	assert_push_error("virtual_joystick_position must have non-negative coordinates")


func test_virtual_joystick_position_not_set_sentinel_is_valid() -> void:
	var profile := RS_InputProfile.new()
	autofree(profile)
	profile.virtual_joystick_position = Vector2(-1, -1)
	assert_push_error(0, "sentinel (-1, -1) should not push errors")