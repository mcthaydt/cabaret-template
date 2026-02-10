extends GutTest

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_UI_SOUND_PLAYER := preload("res://scripts/ui/utils/u_ui_sound_player.gd")


var _mock_audio_manager: MockAudioManager


func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	_mock_audio_manager = MockAudioManager.new()
	add_child_autofree(_mock_audio_manager)
	U_SERVICE_LOCATOR.register(StringName("audio_manager"), _mock_audio_manager)
	U_UI_SOUND_PLAYER.reset_tick_throttle()


func after_each() -> void:
	U_SERVICE_LOCATOR.clear()
	_mock_audio_manager = null


func test_play_focus_calls_audio_manager_with_focus_id() -> void:
	U_UI_SOUND_PLAYER.play_focus()
	assert_eq(_mock_audio_manager.played, [StringName("ui_focus")])


func test_play_confirm_calls_audio_manager_with_confirm_id() -> void:
	U_UI_SOUND_PLAYER.play_confirm()
	assert_eq(_mock_audio_manager.played, [StringName("ui_confirm")])


func test_play_cancel_calls_audio_manager_with_cancel_id() -> void:
	U_UI_SOUND_PLAYER.play_cancel()
	assert_eq(_mock_audio_manager.played, [StringName("ui_cancel")])


func test_play_slider_tick_calls_audio_manager_with_tick_id() -> void:
	U_UI_SOUND_PLAYER.play_slider_tick()
	assert_eq(_mock_audio_manager.played, [StringName("ui_tick")])


func test_play_slider_tick_is_throttled_to_max_10_per_second() -> void:
	U_UI_SOUND_PLAYER.play_slider_tick()
	U_UI_SOUND_PLAYER.play_slider_tick()
	assert_eq(_mock_audio_manager.played, [StringName("ui_tick")])

	OS.delay_msec(110)
	U_UI_SOUND_PLAYER.play_slider_tick()
	assert_eq(_mock_audio_manager.played.size(), 2)
