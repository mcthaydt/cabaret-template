extends GutTest


var _root_node: Node
var _helper: U_PostProcessLayer

func before_each() -> void:
	_root_node = Node.new()
	add_child_autofree(_root_node)
	_helper = U_PostProcessLayer.new()
	_create_effect_rects(_root_node)

func test_initialize_caches_effect_rects() -> void:
	_helper.initialize(_root_node)

	assert_not_null(
		_helper.get_effect_rect(U_PostProcessLayer.EFFECT_COMBINED),
		"Combined rect should be cached"
	)
	assert_not_null(
		_helper.get_effect_rect(U_PostProcessLayer.EFFECT_COLOR_BLIND),
		"Color blind rect should be cached"
	)

func test_initialize_handles_null_canvas_layer() -> void:
	_helper.initialize(null)

	assert_null(
		_helper.get_effect_rect(U_PostProcessLayer.EFFECT_COMBINED),
		"Null root node should not cache rects"
	)

func test_set_effect_enabled_toggles_visibility() -> void:
	_helper.initialize(_root_node)
	var rect := _helper.get_effect_rect(U_PostProcessLayer.EFFECT_COMBINED)
	assert_not_null(rect, "Combined rect should exist")

	_helper.set_effect_enabled(U_PostProcessLayer.EFFECT_COMBINED, true)
	assert_true(rect.visible, "set_effect_enabled(true) should show rect")

	_helper.set_effect_enabled(U_PostProcessLayer.EFFECT_COMBINED, false)
	assert_false(rect.visible, "set_effect_enabled(false) should hide rect")

func test_set_effect_enabled_handles_missing_effect() -> void:
	_helper.initialize(_root_node)

	_helper.set_effect_enabled(StringName("missing"), true)
	assert_true(true, "Missing effect should be ignored")

func test_set_effect_parameter_sets_shader_uniform() -> void:
	_helper.initialize(_root_node)
	var rect := _helper.get_effect_rect(U_PostProcessLayer.EFFECT_COMBINED)
	assert_not_null(rect, "Combined rect should exist")

	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform float fg_intensity = 0.0;"
	var material := ShaderMaterial.new()
	material.shader = shader
	rect.material = material

	_helper.set_effect_parameter(U_PostProcessLayer.EFFECT_COMBINED, StringName("fg_intensity"), 0.75)
	var value: float = float(material.get_shader_parameter("fg_intensity"))
	assert_almost_eq(value, 0.75, 0.0001, "Shader uniform should be updated")

func test_set_effect_parameter_handles_missing_effect() -> void:
	_helper.initialize(_root_node)

	_helper.set_effect_parameter(StringName("missing"), StringName("fg_intensity"), 1.0)
	assert_true(true, "Missing effect should be ignored")

func test_set_effect_parameter_handles_null_material() -> void:
	_helper.initialize(_root_node)
	var rect := _helper.get_effect_rect(U_PostProcessLayer.EFFECT_COMBINED)
	assert_not_null(rect, "Combined rect should exist")
	assert_null(rect.material, "Rect should start without a material")

	_helper.set_effect_parameter(U_PostProcessLayer.EFFECT_COMBINED, StringName("fg_intensity"), 0.5)
	assert_null(rect.material, "Null material should be ignored")

func test_set_effect_parameter_ignores_non_shader_material() -> void:
	_helper.initialize(_root_node)
	var rect := _helper.get_effect_rect(U_PostProcessLayer.EFFECT_COMBINED)
	assert_not_null(rect, "Combined rect should exist")

	var material := CanvasItemMaterial.new()
	rect.material = material
	_helper.set_effect_parameter(U_PostProcessLayer.EFFECT_COMBINED, StringName("fg_intensity"), 0.2)
	assert_eq(rect.material, material, "Non-shader materials should be left unchanged")

func test_set_combined_parameter_delegates_to_effect_parameter() -> void:
	_helper.initialize(_root_node)
	var rect := _helper.get_effect_rect(U_PostProcessLayer.EFFECT_COMBINED)
	assert_not_null(rect, "Combined rect should exist")

	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform float dither_intensity = 0.0;"
	var material := ShaderMaterial.new()
	material.shader = shader
	rect.material = material

	_helper.set_combined_parameter(StringName("dither_intensity"), 0.9)
	var value: float = float(material.get_shader_parameter("dither_intensity"))
	assert_almost_eq(value, 0.9, 0.0001, "set_combined_parameter should update combined shader uniform")

func test_get_combined_rect_returns_combined_effect_rect() -> void:
	_helper.initialize(_root_node)
	var rect := _helper.get_combined_rect()
	assert_not_null(rect, "get_combined_rect should return the combined ColorRect")
	assert_eq(rect, _helper.get_effect_rect(U_PostProcessLayer.EFFECT_COMBINED),
		"get_combined_rect should match get_effect_rect(EFFECT_COMBINED)")

func test_legacy_constants_still_defined() -> void:
	# Ensure legacy constants are still accessible for external code
	assert_eq(U_PostProcessLayer.EFFECT_FILM_GRAIN, StringName("film_grain"))
	assert_eq(U_PostProcessLayer.EFFECT_DITHER, StringName("dither"))

func _create_effect_rects(root: Node) -> void:
	var layers := [
		{layer_name = "CombinedLayer", rect_name = "CombinedRect"},
		{layer_name = "ColorBlindLayer", rect_name = "ColorBlindRect"}
	]
	for layer_data in layers:
		var canvas_layer := CanvasLayer.new()
		canvas_layer.name = layer_data.layer_name
		root.add_child(canvas_layer)

		var rect := ColorRect.new()
		rect.name = layer_data.rect_name
		rect.visible = false
		canvas_layer.add_child(rect)
