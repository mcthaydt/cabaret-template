extends Control

## Credits screen controller (Phase 9)
##
## Auto-scrolls credits content and returns to main menu after a timeout.
## Skip button allows players to exit immediately.

const M_SceneManager := preload("res://scripts/managers/m_scene_manager.gd")

@onready var scroll_container: ScrollContainer = $MarginContainer/ScrollContainer
@onready var skip_button: Button = $SkipButton

var _scene_manager: M_SceneManager = null
var _scroll_tween: Tween = null
var _auto_return_timer: Timer = null
var _scroll_duration: float = 55.0
var _auto_return_duration: float = 60.0
var _is_returning: bool = false

func set_test_durations(scroll_duration: float, auto_return_duration: float) -> void:
	_scroll_duration = max(scroll_duration, 0.01)
	_auto_return_duration = max(auto_return_duration, 0.01)

	if _auto_return_timer != null:
		_auto_return_timer.stop()
		_auto_return_timer.wait_time = _auto_return_duration
		_auto_return_timer.start()

	_restart_scroll_tween()

func _ready() -> void:
	await get_tree().process_frame

	_scene_manager = _find_scene_manager()
	if skip_button:
		skip_button.pressed.connect(_on_skip_pressed)

	_start_auto_return_timer()
	_start_scroll_tween()

func _exit_tree() -> void:
	if _auto_return_timer != null:
		_auto_return_timer.stop()
	if _scroll_tween != null and _scroll_tween.is_running():
		_scroll_tween.kill()
	_scroll_tween = null
	_auto_return_timer = null

func _find_scene_manager() -> M_SceneManager:
	var managers := get_tree().get_nodes_in_group("scene_manager")
	if managers.size() > 0:
		return managers[0] as M_SceneManager
	return null

func _start_auto_return_timer() -> void:
	if _auto_return_timer == null:
		_auto_return_timer = Timer.new()
		_auto_return_timer.one_shot = true
		add_child(_auto_return_timer)
		_auto_return_timer.timeout.connect(_on_auto_return_timeout)

	_auto_return_timer.wait_time = _auto_return_duration
	_auto_return_timer.start()

func _start_scroll_tween() -> void:
	if scroll_container == null:
		return

	var vbar := scroll_container.get_v_scroll_bar()
	if vbar == null:
		return

	scroll_container.scroll_vertical = 0

	if _scroll_tween != null and _scroll_tween.is_running():
		_scroll_tween.kill()

	_scroll_tween = create_tween()
	_scroll_tween.tween_property(
		scroll_container,
		"scroll_vertical",
		vbar.max_value,
		_scroll_duration
	).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)

func _restart_scroll_tween() -> void:
	if not is_inside_tree():
		return
	_start_scroll_tween()

func _on_skip_pressed() -> void:
	_return_to_main_menu()

func _on_auto_return_timeout() -> void:
	_return_to_main_menu()

func _return_to_main_menu() -> void:
	if _is_returning:
		return
	_is_returning = true

	if _auto_return_timer != null:
		_auto_return_timer.stop()
	if _scroll_tween != null and _scroll_tween.is_running():
		_scroll_tween.kill()

	if _scene_manager != null:
		_scene_manager.transition_to_scene(StringName("main_menu"), "fade", M_SceneManager.Priority.HIGH)
