extends GutTest

const U_ShakeResult := preload("res://scripts/managers/helpers/u_shake_result.gd")


func test_constructor_with_defaults() -> void:
	var result = U_ShakeResult.new()

	assert_eq(result.offset, Vector2.ZERO, "Default offset should be Vector2.ZERO")
	assert_eq(result.rotation, 0.0, "Default rotation should be 0.0")


func test_constructor_with_custom_values() -> void:
	var offset := Vector2(3.5, -2.0)
	var rotation := 0.25
	var result = U_ShakeResult.new(offset, rotation)

	assert_eq(result.offset, offset, "Custom offset should be stored")
	assert_eq(result.rotation, rotation, "Custom rotation should be stored")


func test_offset_field_accessible() -> void:
	var result = U_ShakeResult.new(Vector2(1.0, 2.0), 0.1)

	assert_true(result.offset is Vector2, "Offset should be a Vector2")


func test_rotation_field_accessible() -> void:
	var result = U_ShakeResult.new(Vector2.ZERO, 0.2)

	assert_true(result.rotation is float, "Rotation should be a float")
