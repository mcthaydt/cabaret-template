extends GutTest

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_AudioUtils := preload("res://scripts/utils/u_audio_utils.gd")
const I_AUDIO_MANAGER := preload("res://scripts/interfaces/i_audio_manager.gd")
const MockAudioManager := preload("res://tests/mocks/mock_audio_manager.gd")

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()

func after_each() -> void:
	U_SERVICE_LOCATOR.clear()

func test_get_audio_manager_returns_manager_when_registered() -> void:
	var mock_manager := MockAudioManager.new()
	U_SERVICE_LOCATOR.register(StringName("audio_manager"), mock_manager)

	var result := U_AudioUtils.get_audio_manager()

	assert_not_null(result, "Should return manager when service registered")
	assert_is(result, I_AUDIO_MANAGER, "Should return I_AudioManager type")
	assert_same(result, mock_manager, "Should return the registered manager instance")

	mock_manager.free()

func test_get_audio_manager_returns_null_when_not_registered() -> void:
	# ServiceLocator is empty (cleared in before_each)

	var result := U_AudioUtils.get_audio_manager()

	assert_null(result, "Should return null when service not registered")

func test_get_audio_manager_uses_service_locator_only() -> void:
	# If a manager exists in the tree but is not registered, should return null
	var mock_manager := MockAudioManager.new()
	add_child_autofree(mock_manager)

	var result := U_AudioUtils.get_audio_manager()

	assert_null(result, "Should return null when not registered in ServiceLocator")
