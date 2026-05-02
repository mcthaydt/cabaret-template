extends GutTest

func test_display_builder_creates_all_controls() -> void:
	var U_DISPLAY_TAB_BUILDER := load("res://scripts/core/ui/helpers/u_display_tab_builder.gd")
	
	var tab := VBoxContainer.new()
	add_child_autofree(tab)
	
	var builder = U_DISPLAY_TAB_BUILDER.new(tab)
	var built_tab = builder.build()
	
	assert_eq(built_tab, tab, "build should return the tab")
	
	assert_not_null(_find_first(tab, "HeadingLabel"), "Heading should exist")
	assert_not_null(_find_first(tab, "GraphicsHeader"), "Graphics header should exist")
	assert_not_null(_find_first(tab, "WindowSizeOption"), "WindowSizeOption should exist")
	assert_not_null(_find_first(tab, "WindowModeOption"), "WindowModeOption should exist")
	assert_not_null(_find_first(tab, "VSyncToggle"), "VSyncToggle should exist")
	assert_not_null(_find_first(tab, "QualityPresetOption"), "QualityPresetOption should exist")
	assert_not_null(_find_first(tab, "PostProcessingToggle"), "PostProcessingToggle should exist")
	assert_not_null(_find_first(tab, "PostProcessPresetOption"), "PostProcessPresetOption should exist")
	assert_not_null(_find_first(tab, "UIScaleSlider"), "UIScaleSlider should exist")
	assert_not_null(_find_first(tab, "ColorBlindModeOption"), "ColorBlindModeOption should exist")
	assert_not_null(_find_first(tab, "HighContrastToggle"), "HighContrastToggle should exist")
	assert_not_null(_find_first(tab, "ApplyButton"), "ApplyButton should exist")
	assert_not_null(_find_first(tab, "CancelButton"), "CancelButton should exist")
	assert_not_null(_find_first(tab, "ResetButton"), "ResetButton should exist")

func _find_first(node: Node, name: String) -> Node:
	if node.name == name:
		return node
	for child in node.get_children():
		var result := _find_first(child, name)
		if result != null:
			return result
	return null
