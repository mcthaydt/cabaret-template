extends GutTest

const BaseOverlay := preload("res://scripts/core/ui/base/base_overlay.gd")

func test_overlay_panel_size_is_860x620():
	assert_eq(BaseOverlay.OVERLAY_PANEL_SIZE, Vector2(860.0, 620.0), "OVERLAY_PANEL_SIZE should be 860x620")