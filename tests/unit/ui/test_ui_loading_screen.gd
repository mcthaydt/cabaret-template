extends GutTest

const UI_LoadingScreen := preload("res://scripts/core/ui/hud/ui_loading_screen.gd")

func test_loading_screen_background_image_skips_shader() -> void:
	var screen := UI_LoadingScreen.new()
	var bg_image := TextureRect.new()
	bg_image.name = "BackgroundImage"
	screen.add_child(bg_image)
	screen.background_shader_preset = "scanline_drift"
	screen._ready()
	assert_null(screen.get("_background_shader_material"), "Should skip shader when BackgroundImage present")
	screen.free()