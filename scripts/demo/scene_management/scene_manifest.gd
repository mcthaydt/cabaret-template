extends RefCounted

## Demo Scene Manifest
##
## Replaces scene registry .tres entries with a builder script.
## Called by U_SceneRegistryLoader to produce a scene registration Dictionary.

const BUILDER_SCRIPT := preload("res://scripts/core/utils/scene/u_scene_registry_builder.gd")

func build() -> Dictionary:
	var builder := BUILDER_SCRIPT.new()

	# Core gameplay
	builder.register(&"gameplay_base", "res://scenes/core/gameplay/gameplay_base.tscn").with_type(1).with_transition("loading").with_preload(8)

	# Demo gameplay scenes
	builder.register(&"alleyway", "res://scenes/demo/gameplay/gameplay_alleyway.tscn").with_type(1).with_preload(6)
	builder.register(&"interior_house", "res://scenes/demo/gameplay/gameplay_interior_house.tscn").with_type(1).with_preload(6)
	builder.register(&"interior_a", "res://scenes/demo/gameplay/gameplay_interior_a.tscn").with_type(1).with_preload(6)
	builder.register(&"bar", "res://scenes/demo/gameplay/gameplay_bar.tscn").with_type(1).with_preload(6)
	builder.register(&"power_core", "res://scenes/demo/gameplay/gameplay_power_core.tscn").with_type(1).with_transition("loading").with_preload(7)
	builder.register(&"comms_array", "res://scenes/demo/gameplay/gameplay_comms_array.tscn").with_type(1).with_transition("loading").with_preload(6)
	builder.register(&"nav_nexus", "res://scenes/demo/gameplay/gameplay_nav_nexus.tscn").with_type(1).with_transition("loading").with_preload(6)
	builder.register(&"ai_showcase", "res://scenes/demo/gameplay/gameplay_ai_showcase.tscn").with_type(1).with_transition("loading").with_preload(8)
	builder.register(&"ai_woods", "res://scenes/demo/gameplay/gameplay_ai_woods.tscn").with_type(1).with_transition("loading").with_preload(8)

	# Core UI overlays
	builder.register(&"gamepad_settings", "res://scenes/core/ui/overlays/ui_gamepad_settings_overlay.tscn").with_type(2).with_transition("instant").with_preload(5)
	builder.register(&"touchscreen_settings", "res://scenes/core/ui/overlays/ui_touchscreen_settings_overlay.tscn").with_type(2).with_transition("instant").with_preload(5)
	builder.register(&"edit_touch_controls", "res://scenes/core/ui/overlays/ui_edit_touch_controls_overlay.tscn").with_type(2).with_transition("instant").with_preload(5)
	builder.register(&"input_profile_selector", "res://scenes/core/ui/overlays/ui_input_profile_selector.tscn").with_type(2).with_transition("instant").with_preload(5)
	builder.register(&"input_rebinding", "res://scenes/core/ui/overlays/ui_input_rebinding_overlay.tscn").with_type(2).with_transition("instant").with_preload(5)
	builder.register(&"keyboard_mouse_settings", "res://scenes/core/ui/overlays/ui_keyboard_mouse_settings_overlay.tscn").with_type(2).with_transition("instant").with_preload(5)
	builder.register(&"audio_settings", "res://scenes/core/ui/overlays/settings/ui_audio_settings_overlay.tscn").with_type(2).with_transition("instant").with_preload(5)
	builder.register(&"display_settings", "res://scenes/core/ui/overlays/settings/ui_display_settings_overlay.tscn").with_type(2).with_transition("instant").with_preload(5)
	builder.register(&"localization_settings", "res://scenes/core/ui/overlays/settings/ui_localization_settings_overlay.tscn").with_type(2).with_transition("instant").with_preload(5)
	builder.register(&"vfx_settings", "res://scenes/core/ui/overlays/settings/ui_vfx_settings_overlay.tscn").with_type(2).with_transition("instant").with_preload(5)

	# Core end-game menus
	builder.register(&"game_over", "res://scenes/core/ui/menus/ui_game_over.tscn").with_type(3).with_preload(8)
	builder.register(&"victory", "res://scenes/core/ui/menus/ui_victory.tscn").with_type(3).with_preload(5)
	builder.register(&"credits", "res://scenes/core/ui/menus/ui_credits.tscn").with_type(3)

	return builder.build()
