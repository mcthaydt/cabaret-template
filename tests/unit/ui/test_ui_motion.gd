extends GutTest

const RS_UI_MOTION_PRESET := preload("res://scripts/core/resources/ui/rs_ui_motion_preset.gd")
const RS_UI_MOTION_SET := preload("res://scripts/core/resources/ui/rs_ui_motion_set.gd")
const U_UI_MOTION := preload("res://scripts/core/ui/utils/u_ui_motion.gd")

func test_play_returns_tween_for_valid_presets() -> void:
	var node := Control.new()
	add_child_autofree(node)
	var preset := _make_preset("modulate:a", 0.0, 1.0, 0.03)

	var tween: Tween = U_UI_MOTION.play(node, [preset])

	assert_not_null(tween, "play() should return a Tween for valid presets")

func test_play_applies_property_change() -> void:
	var node := Control.new()
	node.modulate.a = 0.0
	add_child_autofree(node)
	var preset := _make_preset("modulate:a", 0.0, 1.0, 0.03)

	var tween: Tween = U_UI_MOTION.play(node, [preset])
	assert_not_null(tween, "Tween should be created for property tween")
	await tween.finished

	assert_almost_eq(node.modulate.a, 1.0, 0.01,
		"Property tween should reach target value after completion")

func test_play_sequential_chain() -> void:
	var node := Control.new()
	node.modulate.a = 0.0
	add_child_autofree(node)

	var fade_in := _make_preset("modulate:a", 0.0, 1.0, 0.12)
	var hold := RS_UI_MOTION_PRESET.new()
	hold.interval_sec = 0.12
	var fade_out := _make_preset("modulate:a", 1.0, 0.0, 0.12)

	var tween: Tween = U_UI_MOTION.play(node, [fade_in, hold, fade_out])
	assert_not_null(tween, "Sequential tween chain should be created")

	await wait_seconds(0.15)
	assert_true(node.modulate.a > 0.8, "Fade-in should complete before hold starts")

	await wait_seconds(0.08)
	assert_true(node.modulate.a > 0.8, "Hold step should keep alpha high")

	await tween.finished
	assert_true(node.modulate.a < 0.2, "Final fade-out should reduce alpha near zero")

func test_play_parallel_presets() -> void:
	var node := Control.new()
	node.modulate.a = 0.0
	node.scale = Vector2.ONE
	add_child_autofree(node)

	var fade := _make_preset("modulate:a", 0.0, 1.0, 0.08)
	var scale_up := _make_preset("scale:x", 1.0, 1.5, 0.08)
	scale_up.parallel = true

	var tween: Tween = U_UI_MOTION.play(node, [fade, scale_up])
	assert_not_null(tween, "Parallel tween chain should be created")

	await wait_seconds(0.04)
	assert_true(node.modulate.a > 0.1, "Parallel alpha tween should be running")
	assert_true(node.scale.x > 1.05, "Parallel scale tween should be running")

	await tween.finished
	assert_almost_eq(node.modulate.a, 1.0, 0.01, "Alpha tween should finish at target")
	assert_almost_eq(node.scale.x, 1.5, 0.01, "Scale tween should finish at target")

func test_play_position_y_preserves_control_layout_offset() -> void:
	var node := Control.new()
	node.position.y = 24.0
	add_child_autofree(node)
	var preset := _make_preset("position:y", 18.0, 0.0, 0.03)

	var tween: Tween = U_UI_MOTION.play(node, [preset])
	assert_not_null(tween, "Tween should be created for position:y slide preset")
	await tween.finished

	assert_almost_eq(node.position.y, 24.0, 0.01,
		"position:y slide presets should finish at the Control's original layout offset")

func test_play_repeated_position_y_preserves_original_layout_offset() -> void:
	var node := Control.new()
	node.position.y = 24.0
	add_child_autofree(node)
	var preset := _make_preset("position:y", 18.0, 0.0, 0.1)

	var first_tween: Tween = U_UI_MOTION.play(node, [preset])
	assert_not_null(first_tween, "First tween should be created")
	await wait_seconds(0.02)

	var second_tween: Tween = U_UI_MOTION.play(node, [preset])
	assert_not_null(second_tween, "Second tween should be created while first is active")
	await second_tween.finished

	assert_almost_eq(node.position.y, 24.0, 0.01,
		"repeated position:y slide presets should not preserve the slide offset as final layout")

func test_play_interval_preset() -> void:
	var node := Control.new()
	add_child_autofree(node)
	var interval := RS_UI_MOTION_PRESET.new()
	interval.interval_sec = 0.08

	var start_ms: int = Time.get_ticks_msec()
	var tween: Tween = U_UI_MOTION.play(node, [interval])
	assert_not_null(tween, "Interval-only preset should still create a tween")
	await tween.finished
	var elapsed_ms: int = Time.get_ticks_msec() - start_ms

	assert_true(elapsed_ms >= 70, "Interval preset should hold for approximately the configured time")

func test_play_null_presets_returns_null() -> void:
	var node := Control.new()
	add_child_autofree(node)

	var tween: Tween = U_UI_MOTION.play(node, [])
	assert_null(tween, "Empty preset list should return null")

func test_play_null_node_returns_null() -> void:
	var preset := _make_preset("modulate:a", 0.0, 1.0, 0.03)

	var tween: Tween = U_UI_MOTION.play(null, [preset])
	assert_null(tween, "Null node should return null")

func test_play_enter_delegates_to_motion_set() -> void:
	var node := Control.new()
	add_child_autofree(node)
	var motion_set := RS_UI_MOTION_SET.new()
	motion_set.enter = [_make_preset("modulate:a", 0.0, 1.0, 0.03)]

	var tween: Tween = U_UI_MOTION.play_enter(node, motion_set)
	assert_not_null(tween, "play_enter should delegate to motion_set.enter")

func test_play_exit_delegates_to_motion_set() -> void:
	var node := Control.new()
	add_child_autofree(node)
	var motion_set := RS_UI_MOTION_SET.new()
	motion_set.exit = [_make_preset("modulate:a", 1.0, 0.0, 0.03)]

	var tween: Tween = U_UI_MOTION.play_exit(node, motion_set)
	assert_not_null(tween, "play_exit should delegate to motion_set.exit")

func test_play_enter_null_motion_set_returns_null() -> void:
	var node := Control.new()
	add_child_autofree(node)

	var tween: Tween = U_UI_MOTION.play_enter(node, null)
	assert_null(tween, "Null motion set should be a no-op")

func test_bind_interactive_connects_signals() -> void:
	var button := Button.new()
	add_child_autofree(button)
	var motion_set := RS_UI_MOTION_SET.new()
	motion_set.hover_in = [_make_preset("modulate:a", 0.5, 1.0, 0.03)]
	motion_set.hover_out = [_make_preset("modulate:a", 1.0, 0.5, 0.03)]
	motion_set.focus_in = [_make_preset("scale:x", 1.0, 1.05, 0.03)]
	motion_set.focus_out = [_make_preset("scale:x", 1.05, 1.0, 0.03)]

	U_UI_MOTION.bind_interactive(button, motion_set)

	assert_gt(button.mouse_entered.get_connections().size(), 0,
		"mouse_entered should be connected when motion set is provided")
	assert_gt(button.mouse_exited.get_connections().size(), 0,
		"mouse_exited should be connected when motion set is provided")
	assert_gt(button.focus_entered.get_connections().size(), 0,
		"focus_entered should be connected when motion set is provided")
	assert_gt(button.focus_exited.get_connections().size(), 0,
		"focus_exited should be connected when motion set is provided")

func test_bind_interactive_null_motion_set_no_op() -> void:
	var button := Button.new()
	add_child_autofree(button)

	U_UI_MOTION.bind_interactive(button, null)

	assert_eq(button.mouse_entered.get_connections().size(), 0,
		"Null motion set should not connect mouse_entered")
	assert_eq(button.mouse_exited.get_connections().size(), 0,
		"Null motion set should not connect mouse_exited")
	assert_eq(button.focus_entered.get_connections().size(), 0,
		"Null motion set should not connect focus_entered")
	assert_eq(button.focus_exited.get_connections().size(), 0,
		"Null motion set should not connect focus_exited")

func test_play_pulse_delegates_to_motion_set() -> void:
	var node := Control.new()
	add_child_autofree(node)
	var motion_set := RS_UI_MOTION_SET.new()
	motion_set.pulse = [_make_preset("modulate:a", 1.0, 0.5, 0.03)]

	var tween: Tween = U_UI_MOTION.play_pulse(node, motion_set)
	assert_not_null(tween, "play_pulse should delegate to motion_set.pulse")

func test_play_pulse_null_motion_set_returns_null() -> void:
	var node := Control.new()
	add_child_autofree(node)

	var tween: Tween = U_UI_MOTION.play_pulse(node, null)
	assert_null(tween, "Null motion set should return null for pulse")

func test_append_step_adds_property_tween() -> void:
	var node := Control.new()
	node.modulate.a = 0.0
	add_child_autofree(node)
	var preset := _make_preset("modulate:a", 0.0, 1.0, 0.03)

	var tween := node.create_tween()
	var result: bool = U_UI_MOTION.append_step(tween, node, preset)
	assert_true(result, "append_step should return true for valid preset")

	await tween.finished
	assert_almost_eq(node.modulate.a, 1.0, 0.01,
		"append_step tween should reach target value")

func test_append_step_null_tween_returns_false() -> void:
	var node := Control.new()
	add_child_autofree(node)
	var preset := _make_preset("modulate:a", 0.0, 1.0, 0.03)

	var result: bool = U_UI_MOTION.append_step(null, node, preset)
	assert_false(result, "append_step with null tween should return false")

func _make_preset(path: String, from_value: Variant, to_value: Variant, duration_sec: float) -> Resource:
	var preset := RS_UI_MOTION_PRESET.new()
	preset.property_path = path
	preset.from_value = from_value
	preset.to_value = to_value
	preset.duration_sec = duration_sec
	return preset
