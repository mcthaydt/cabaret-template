extends BaseTest


func test_fade_transition_restores_transition_overlay_mouse_filter() -> void:
	# Regression test:
	# After a fade transition completes, the transition overlay must NOT block mouse input.
	# The root scene sets TransitionColorRect.mouse_filter = IGNORE by default.
	var overlay := CanvasLayer.new()
	add_child_autofree(overlay)

	var rect := ColorRect.new()
	rect.name = "TransitionColorRect"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.modulate = Color(1, 1, 1, 0)
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	overlay.add_child(rect)

	var fade := Trans_Fade.new()
	fade.duration = 0.05
	fade.block_input = true

	# Typical orchestrator flow: fade out (blocks input) -> swap -> fade in (must restore ignore).
	await fade.execute_fade_out(overlay)
	await fade.execute_fade_in(overlay, func() -> void: pass)

	assert_eq(
		rect.mouse_filter,
		Control.MOUSE_FILTER_IGNORE,
		"TransitionColorRect.mouse_filter must restore to IGNORE after fade completes to avoid blocking UI clicks"
	)

