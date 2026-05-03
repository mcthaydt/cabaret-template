extends GutTest

const U_LOCALIZATION_TAB_BUILDER := preload("res://scripts/core/ui/helpers/u_localization_tab_builder.gd")
const U_UI_SETTINGS_CATALOG := preload("res://scripts/core/ui/helpers/u_ui_settings_catalog.gd")

func test_localization_builder_creates_language_dropdown() -> void:
	var tab := VBoxContainer.new()
	add_child_autofree(tab)
	
	var builder = U_LOCALIZATION_TAB_BUILDER.new(tab)
	var built_tab = builder.build()
	
	assert_eq(built_tab, tab, "build should return the tab")
	assert_not_null(_find_first(tab, "LanguageOptionButton"), "LanguageOption should exist")

func test_localization_builder_creates_heading() -> void:
	var tab := VBoxContainer.new()
	add_child_autofree(tab)
	
	var builder = U_LOCALIZATION_TAB_BUILDER.new(tab)
	var built_tab = builder.build()
	
	assert_not_null(_find_first(tab, "HeadingLabel"), "HeadingLabel should exist")

func test_localization_builder_creates_section_header() -> void:
	var tab := VBoxContainer.new()
	add_child_autofree(tab)
	
	var builder = U_LOCALIZATION_TAB_BUILDER.new(tab)
	var built_tab = builder.build()
	
	assert_not_null(_find_first(tab, "SectionHeader"), "SectionHeader should exist")

func _find_first(node: Node, name: String) -> Node:
	if node.name == name:
		return node
	for child in node.get_children():
		var result := _find_first(child, name)
		if result != null:
			return result
	return null
