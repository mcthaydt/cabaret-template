@icon("res://resources/editor_icons/utility.svg")
extends BaseMenuScreen
class_name UI_Credits

## Credits screen controller (Phase 9)
##
## Auto-scrolls credits content and returns to main menu after a timeout.
## Skip button allows players to exit immediately.

const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")

@onready var scroll_container: ScrollContainer = $MarginContainer/ScrollContainer
@onready var skip_button: Button = $SkipButton

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

func _on_panel_ready() -> void:
	if skip_button and not skip_button.pressed.is_connected(_on_skip_pressed):
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
	U_UISoundPlayer.play_confirm()
	_return_to_main_menu()

func _on_auto_return_timeout() -> void:
	_return_to_main_menu()

func _on_back_pressed() -> void:
	U_UISoundPlayer.play_cancel()
	_return_to_main_menu()

func _return_to_main_menu() -> void:
	if _is_returning:
		return
	_is_returning = true

	if _auto_return_timer != null:
		_auto_return_timer.stop()
	if _scroll_tween != null and _scroll_tween.is_running():
		_scroll_tween.kill()

	var store := get_store()
	if store == null:
		return
	store.dispatch(U_NavigationActions.skip_to_menu())
