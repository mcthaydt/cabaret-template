extends GutTest


var _owner: Node
var _pipeline: U_PostProcessPipeline

func before_each() -> void:
	_owner = Node.new()
	add_child_autofree(_owner)
	_pipeline = U_PostProcessPipeline.new()

func after_each() -> void:
	_pipeline.clear()

# --- Pass registration ---

func test_register_pass_stores_pass_by_id() -> void:
	var pass_id := StringName(&"color_grading")
	var rect := ColorRect.new()
	add_child_autofree(rect)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment() {}"
	_pipeline.register_pass(pass_id, rect, shader)
	var pass_data := _pipeline.get_pass(pass_id)
	assert_not_null(pass_data, "Registered pass should be retrievable")

func test_register_pass_overwrites_existing() -> void:
	var pass_id := StringName(&"grain_dither")
	var rect1 := ColorRect.new()
	var rect2 := ColorRect.new()
	add_child_autofree(rect1)
	add_child_autofree(rect2)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment() {}"
	_pipeline.register_pass(pass_id, rect1, shader)
	_pipeline.register_pass(pass_id, rect2, shader)
	var pass_data := _pipeline.get_pass(pass_id)
	assert_not_null(pass_data, "Re-registered pass should exist")
	assert_eq(pass_data["rect"], rect2, "Re-registered pass should use the newer rect")

func test_get_pass_returns_null_for_unknown() -> void:
	var result := _pipeline.get_pass(StringName(&"nonexistent"))
	assert_null(result, "Unregistered pass should return null")

# --- Deterministic ordered evaluation ---

func test_passes_are_evaluated_in_registration_order() -> void:
	var color_grading_rect := ColorRect.new()
	var grain_dither_rect := ColorRect.new()
	add_child_autofree(color_grading_rect)
	add_child_autofree(grain_dither_rect)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment() {}"
	_pipeline.register_pass(StringName(&"color_grading"), color_grading_rect, shader)
	_pipeline.register_pass(StringName(&"grain_dither"), grain_dither_rect, shader)
	var pass_order := _pipeline.get_pass_order()
	assert_eq(pass_order.size(), 2, "Should have 2 passes")
	assert_eq(pass_order[0], StringName(&"color_grading"), "Color grading should be first")
	assert_eq(pass_order[1], StringName(&"grain_dither"), "Grain+dither should be second")

func test_register_pass_preserves_order_on_reregister() -> void:
	var color_grading_rect := ColorRect.new()
	var grain_dither_rect := ColorRect.new()
	var updated_rect := ColorRect.new()
	add_child_autofree(color_grading_rect)
	add_child_autofree(grain_dither_rect)
	add_child_autofree(updated_rect)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment() {}"
	_pipeline.register_pass(StringName(&"color_grading"), color_grading_rect, shader)
	_pipeline.register_pass(StringName(&"grain_dither"), grain_dither_rect, shader)
	# Re-register grain_dither — order should not change
	_pipeline.register_pass(StringName(&"grain_dither"), updated_rect, shader)
	var pass_order := _pipeline.get_pass_order()
	assert_eq(pass_order.size(), 2, "Should still have 2 passes")
	assert_eq(pass_order[0], StringName(&"color_grading"), "Color grading should remain first")
	assert_eq(pass_order[1], StringName(&"grain_dither"), "Grain+dither should remain second")

# --- Per-pass enable/disable ---

func test_apply_settings_enables_visible_passes() -> void:
	var rect := ColorRect.new()
	add_child_autofree(rect)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment() {}"
	var pass_id := StringName(&"color_grading")
	_pipeline.register_pass(pass_id, rect, shader)
	var state := {"display": {"color_grading_enabled": true}}
	_pipeline.apply_settings(state)
	assert_true(rect.visible, "Enabled pass rect should be visible")

func test_apply_settings_disables_disabled_passes() -> void:
	var rect := ColorRect.new()
	rect.visible = true
	add_child_autofree(rect)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment() {}"
	var pass_id := StringName(&"grain_dither")
	_pipeline.register_pass(pass_id, rect, shader)
	var state := {"display": {"grain_dither_enabled": false}}
	_pipeline.apply_settings(state)
	assert_false(rect.visible, "Disabled pass rect should be hidden")

# --- Frame-counter uniform updates (fg_time) ---

func test_update_per_frame_advances_fg_time_uniform() -> void:
	var rect := ColorRect.new()
	add_child_autofree(rect)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform float fg_time = 0.0;"
	var material := ShaderMaterial.new()
	material.shader = shader
	rect.material = material
	var pass_id := StringName(&"grain_dither")
	_pipeline.register_pass(pass_id, rect, shader)
	_pipeline.update_per_frame()
	var fg_time: float = float(material.get_shader_parameter("fg_time"))
	assert_gt(fg_time, 0.0, "fg_time should advance after update_per_frame")

func test_update_per_frame_increments_consistently() -> void:
	var rect := ColorRect.new()
	add_child_autofree(rect)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform float fg_time = 0.0;"
	var material := ShaderMaterial.new()
	material.shader = shader
	rect.material = material
	var pass_id := StringName(&"grain_dither")
	_pipeline.register_pass(pass_id, rect, shader)
	_pipeline.update_per_frame()
	var time1: float = float(material.get_shader_parameter("fg_time"))
	_pipeline.update_per_frame()
	var time2: float = float(material.get_shader_parameter("fg_time"))
	assert_gt(time2, time1, "fg_time should monotonically increase")

# --- Pipeline teardown (unregister/clear) ---

func test_unregister_pass_removes_pass() -> void:
	var rect := ColorRect.new()
	add_child_autofree(rect)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment() {}"
	var pass_id := StringName(&"color_grading")
	_pipeline.register_pass(pass_id, rect, shader)
	_pipeline.unregister_pass(pass_id)
	var pass_data := _pipeline.get_pass(pass_id)
	assert_null(pass_data, "Unregistered pass should return null")

func test_clear_removes_all_passes() -> void:
	var rect1 := ColorRect.new()
	var rect2 := ColorRect.new()
	add_child_autofree(rect1)
	add_child_autofree(rect2)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment() {}"
	_pipeline.register_pass(StringName(&"color_grading"), rect1, shader)
	_pipeline.register_pass(StringName(&"grain_dither"), rect2, shader)
	_pipeline.clear()
	assert_null(_pipeline.get_pass(StringName(&"color_grading")), "color_grading should be cleared")
	assert_null(_pipeline.get_pass(StringName(&"grain_dither")), "grain_dither should be cleared")
	assert_eq(_pipeline.get_pass_order().size(), 0, "Pass order should be empty after clear")

func test_unregister_preserves_remaining_passes() -> void:
	var rect1 := ColorRect.new()
	var rect2 := ColorRect.new()
	add_child_autofree(rect1)
	add_child_autofree(rect2)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment() {}"
	_pipeline.register_pass(StringName(&"color_grading"), rect1, shader)
	_pipeline.register_pass(StringName(&"grain_dither"), rect2, shader)
	_pipeline.unregister_pass(StringName(&"color_grading"))
	assert_not_null(_pipeline.get_pass(StringName(&"grain_dither")), "grain_dither should remain")
	var pass_order := _pipeline.get_pass_order()
	assert_eq(pass_order.size(), 1, "Should have 1 remaining pass")
	assert_eq(pass_order[0], StringName(&"grain_dither"), "Remaining pass should be grain_dither")