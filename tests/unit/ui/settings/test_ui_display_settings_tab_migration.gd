extends GutTest

func test_display_tab_has_no_onready_variables() -> void:
	var tab_script: GDScript = load("res://scripts/core/ui/settings/ui_display_settings_tab.gd")
	var source_code := tab_script.get_source_code()
	
	var onready_count := 0
	for line in source_code.split("\n"):
		if line.strip_edges().begins_with("@onready"):
			onready_count += 1
	
	assert_eq(onready_count, 0, "Display settings tab should have zero @onready variables after migration")

func test_display_tab_setup_builder_uses_factory() -> void:
	var tab_script: GDScript = load("res://scripts/core/ui/settings/ui_display_settings_tab.gd")
	var source_code := tab_script.get_source_code()
	
	assert_true(
		source_code.contains("U_UI_SETTINGS_CATALOG.create_display_builder"),
		"_setup_builder should use U_UI_SETTINGS_CATALOG.create_display_builder factory method"
	)
