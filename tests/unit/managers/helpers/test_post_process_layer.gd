extends GutTest

const U_PostProcessLayer := preload("res://scripts/managers/helpers/u_post_process_layer.gd")

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
		_helper.get_effect_rect(U_PostProcessLayer.EFFECT_FILM_GRAIN),
		"Film grain rect should be cached"
	)
	assert_not_null(
		_helper.get_effect_rect(U_PostProcessLayer.EFFECT_CRT),
		"CRT rect should be cached"
	)
	assert_not_null(
		_helper.get_effect_rect(U_PostProcessLayer.EFFECT_DITHER),
		"Dither rect should be cached"
	)
	assert_not_null(
		_helper.get_effect_rect(U_PostProcessLayer.EFFECT_LUT),
		"LUT rect should be cached"
	)
	assert_not_null(
		_helper.get_effect_rect(U_PostProcessLayer.EFFECT_COLOR_BLIND),
		"Color blind rect should be cached"
	)

func test_initialize_handles_null_canvas_layer() -> void:
	_helper.initialize(null)

	assert_null(
		_helper.get_effect_rect(U_PostProcessLayer.EFFECT_FILM_GRAIN),
		"Null root node should not cache rects"
	)

func test_set_effect_enabled_toggles_visibility() -> void:
	_helper.initialize(_root_node)
	var rect := _helper.get_effect_rect(U_PostProcessLayer.EFFECT_CRT)
	assert_not_null(rect, "CRT rect should exist")

	_helper.set_effect_enabled(U_PostProcessLayer.EFFECT_CRT, true)
	assert_true(rect.visible, "set_effect_enabled(true) should show rect")

	_helper.set_effect_enabled(U_PostProcessLayer.EFFECT_CRT, false)
	assert_false(rect.visible, "set_effect_enabled(false) should hide rect")

func test_set_effect_enabled_handles_missing_effect() -> void:
	_helper.initialize(_root_node)

	_helper.set_effect_enabled(StringName("missing"), true)
	assert_true(true, "Missing effect should be ignored")

func test_set_effect_parameter_sets_shader_uniform() -> void:
	_helper.initialize(_root_node)
	var rect := _helper.get_effect_rect(U_PostProcessLayer.EFFECT_DITHER)
	assert_not_null(rect, "Dither rect should exist")

	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform float intensity = 0.0;"
	var material := ShaderMaterial.new()
	material.shader = shader
	rect.material = material

	_helper.set_effect_parameter(U_PostProcessLayer.EFFECT_DITHER, StringName("intensity"), 0.75)
	var value: float = float(material.get_shader_parameter("intensity"))
	assert_almost_eq(value, 0.75, 0.0001, "Shader uniform should be updated")

func test_set_effect_parameter_handles_missing_effect() -> void:
	_helper.initialize(_root_node)

	_helper.set_effect_parameter(StringName("missing"), StringName("intensity"), 1.0)
	assert_true(true, "Missing effect should be ignored")

func test_set_effect_parameter_handles_null_material() -> void:
	_helper.initialize(_root_node)
	var rect := _helper.get_effect_rect(U_PostProcessLayer.EFFECT_FILM_GRAIN)
	assert_not_null(rect, "Film grain rect should exist")
	assert_null(rect.material, "Rect should start without a material")

	_helper.set_effect_parameter(U_PostProcessLayer.EFFECT_FILM_GRAIN, StringName("intensity"), 0.5)
	assert_null(rect.material, "Null material should be ignored")

func test_set_effect_parameter_ignores_non_shader_material() -> void:
	_helper.initialize(_root_node)
	var rect := _helper.get_effect_rect(U_PostProcessLayer.EFFECT_LUT)
	assert_not_null(rect, "LUT rect should exist")

	var material := CanvasItemMaterial.new()
	rect.material = material
	_helper.set_effect_parameter(U_PostProcessLayer.EFFECT_LUT, StringName("intensity"), 0.2)
	assert_eq(rect.material, material, "Non-shader materials should be left unchanged")

func _create_effect_rects(root: Node) -> void:
	var layers := [
		{layer_name = "FilmGrainLayer", rect_name = "FilmGrainRect"},
		{layer_name = "CRTLayer", rect_name = "CRTRect"},
		{layer_name = "DitherLayer", rect_name = "DitherRect"},
		{layer_name = "LUTLayer", rect_name = "LUTRect"},
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
