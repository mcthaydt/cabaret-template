extends GutTest


func test_palette_id_is_string_name() -> void:
	var palette := RS_UIColorPalette.new()
	assert_eq(typeof(palette.palette_id), TYPE_STRING_NAME, "palette_id should be StringName")

func test_primary_color_is_color() -> void:
	var palette := RS_UIColorPalette.new()
	assert_eq(typeof(palette.primary), TYPE_COLOR, "primary should be Color")

func test_secondary_color_is_color() -> void:
	var palette := RS_UIColorPalette.new()
	assert_eq(typeof(palette.secondary), TYPE_COLOR, "secondary should be Color")

func test_status_colors_are_color() -> void:
	var palette := RS_UIColorPalette.new()
	assert_eq(typeof(palette.success), TYPE_COLOR, "success should be Color")
	assert_eq(typeof(palette.warning), TYPE_COLOR, "warning should be Color")
	assert_eq(typeof(palette.danger), TYPE_COLOR, "danger should be Color")
	assert_eq(typeof(palette.info), TYPE_COLOR, "info should be Color")

func test_background_and_text_colors_are_color() -> void:
	var palette := RS_UIColorPalette.new()
	assert_eq(typeof(palette.background), TYPE_COLOR, "background should be Color")
	assert_eq(typeof(palette.text), TYPE_COLOR, "text should be Color")
