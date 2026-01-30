extends GutTest

const U_AUDIO_BUS_CONSTANTS := preload("res://scripts/managers/helpers/u_audio_bus_constants.gd")

func before_each() -> void:
	_reset_audio_buses()

func after_each() -> void:
	_reset_audio_buses()

func _reset_audio_buses() -> void:
	while AudioServer.bus_count > 1:
		AudioServer.remove_bus(1)

func _create_required_bus_layout() -> void:
	# Master (0) already exists

	# Music (1)
	AudioServer.add_bus(1)
	AudioServer.set_bus_name(1, "Music")
	AudioServer.set_bus_send(1, "Master")

	# SFX (2)
	AudioServer.add_bus(2)
	AudioServer.set_bus_name(2, "SFX")
	AudioServer.set_bus_send(2, "Master")

	# UI (3) - child of SFX
	AudioServer.add_bus(3)
	AudioServer.set_bus_name(3, "UI")
	AudioServer.set_bus_send(3, "SFX")

	# Footsteps (4) - child of SFX
	AudioServer.add_bus(4)
	AudioServer.set_bus_name(4, "Footsteps")
	AudioServer.set_bus_send(4, "SFX")

	# Ambient (5)
	AudioServer.add_bus(5)
	AudioServer.set_bus_name(5, "Ambient")
	AudioServer.set_bus_send(5, "Master")

# Test 1: Constants are defined
func test_bus_constants_are_defined() -> void:
	assert_eq(U_AUDIO_BUS_CONSTANTS.BUS_MASTER, "Master")
	assert_eq(U_AUDIO_BUS_CONSTANTS.BUS_MUSIC, "Music")
	assert_eq(U_AUDIO_BUS_CONSTANTS.BUS_SFX, "SFX")
	assert_eq(U_AUDIO_BUS_CONSTANTS.BUS_UI, "UI")
	assert_eq(U_AUDIO_BUS_CONSTANTS.BUS_FOOTSTEPS, "Footsteps")
	assert_eq(U_AUDIO_BUS_CONSTANTS.BUS_AMBIENT, "Ambient")

# Test 2: Required buses array contains all buses
func test_required_buses_array_contains_all_buses() -> void:
	var required_buses: Array = U_AUDIO_BUS_CONSTANTS.REQUIRED_BUSES
	assert_eq(required_buses.size(), 6, "Should have 6 required buses")
	assert_has(required_buses, "Master")
	assert_has(required_buses, "Music")
	assert_has(required_buses, "SFX")
	assert_has(required_buses, "UI")
	assert_has(required_buses, "Footsteps")
	assert_has(required_buses, "Ambient")

# Test 3: validate_bus_layout returns true when all buses present
func test_validate_bus_layout_returns_true_when_all_buses_present() -> void:
	_create_required_bus_layout()
	var result := U_AUDIO_BUS_CONSTANTS.validate_bus_layout()
	assert_true(result, "Should validate successfully when all buses present")

# Test 4: validate_bus_layout returns false when bus missing
func test_validate_bus_layout_returns_false_when_bus_missing() -> void:
	# Only create Master and Music, missing others
	AudioServer.add_bus(1)
	AudioServer.set_bus_name(1, "Music")
	AudioServer.set_bus_send(1, "Master")

	var result := U_AUDIO_BUS_CONSTANTS.validate_bus_layout(false)  # Disable warnings for test
	assert_false(result, "Should fail validation when buses are missing")

# Test 5: validate_bus_layout returns false with only Master
func test_validate_bus_layout_returns_false_with_only_master() -> void:
	# Only Master bus (index 0) exists by default
	var result := U_AUDIO_BUS_CONSTANTS.validate_bus_layout(false)  # Disable warnings for test
	assert_false(result, "Should fail validation with only Master bus")

# Test 6: get_bus_index_safe returns correct index for valid bus
func test_get_bus_index_safe_returns_correct_index_for_valid_bus() -> void:
	_create_required_bus_layout()
	assert_eq(U_AUDIO_BUS_CONSTANTS.get_bus_index_safe("Master"), 0)
	assert_eq(U_AUDIO_BUS_CONSTANTS.get_bus_index_safe("Music"), 1)
	assert_eq(U_AUDIO_BUS_CONSTANTS.get_bus_index_safe("SFX"), 2)
	assert_eq(U_AUDIO_BUS_CONSTANTS.get_bus_index_safe("UI"), 3)
	assert_eq(U_AUDIO_BUS_CONSTANTS.get_bus_index_safe("Footsteps"), 4)
	assert_eq(U_AUDIO_BUS_CONSTANTS.get_bus_index_safe("Ambient"), 5)

# Test 7: get_bus_index_safe returns 0 (Master) for invalid bus
func test_get_bus_index_safe_returns_master_for_invalid_bus() -> void:
	_create_required_bus_layout()
	var index := U_AUDIO_BUS_CONSTANTS.get_bus_index_safe("NonExistentBus", false)  # Disable warning for test
	assert_eq(index, 0, "Should fallback to Master (0) for invalid bus")

# Test 8: get_bus_index_safe returns 0 when bus layout invalid
func test_get_bus_index_safe_returns_master_when_layout_invalid() -> void:
	# No buses except Master
	var index := U_AUDIO_BUS_CONSTANTS.get_bus_index_safe("Music", false)  # Disable warning for test
	assert_eq(index, 0, "Should fallback to Master (0) when bus missing")
