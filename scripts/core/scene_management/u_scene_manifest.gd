extends RefCounted

## Scene Manifest
##
## Replaces scene registry .tres entries with a builder script.
## Called by U_SceneRegistryLoader to produce a scene registration Dictionary.

const BUILDER_SCRIPT := preload("res://scripts/core/utils/scene/u_scene_registry_builder.gd")

const GAMEPLAY := U_SceneRegistry.SceneType.GAMEPLAY
const UI := U_SceneRegistry.SceneType.UI
const END_GAME := U_SceneRegistry.SceneType.END_GAME

func build() -> Dictionary:
	var builder := BUILDER_SCRIPT.new()

	# Demo gameplay scene (single gameplay entry for tests)
	builder.register(&"demo_room", "res://scenes/demo/gameplay/gameplay_demo_room.tscn").with_type(GAMEPLAY).with_transition("loading").with_preload(8)

	# Core UI overlays
	builder.register(&"gamepad_settings", "res://scenes/core/ui/overlays/ui_gamepad_settings_overlay.tscn").with_type(UI).with_transition("instant").with_preload(5)
	builder.register(&"touchscreen_settings", "res://scenes/core/ui/overlays/ui_touchscreen_settings_overlay.tscn").with_type(UI).with_transition("instant").with_preload(5)
	builder.register(&"edit_touch_controls", "res://scenes/core/ui/overlays/ui_edit_touch_controls_overlay.tscn").with_type(UI).with_transition("instant").with_preload(5)
	builder.register(&"input_profile_selector", "res://scenes/core/ui/overlays/ui_input_profile_selector.tscn").with_type(UI).with_transition("instant").with_preload(5)
	builder.register(&"input_rebinding", "res://scenes/core/ui/overlays/ui_input_rebinding_overlay.tscn").with_type(UI).with_transition("instant").with_preload(5)
	builder.register(&"keyboard_mouse_settings", "res://scenes/core/ui/overlays/ui_keyboard_mouse_settings_overlay.tscn").with_type(UI).with_transition("instant").with_preload(5)
	builder.register(&"audio_settings", "res://scenes/core/ui/overlays/settings/ui_audio_settings_overlay.tscn").with_type(UI).with_transition("instant").with_preload(5)
	builder.register(&"display_settings", "res://scenes/core/ui/overlays/settings/ui_display_settings_overlay.tscn").with_type(UI).with_transition("instant").with_preload(5)
	builder.register(&"localization_settings", "res://scenes/core/ui/overlays/settings/ui_localization_settings_overlay.tscn").with_type(UI).with_transition("instant").with_preload(5)
	builder.register(&"vfx_settings", "res://scenes/core/ui/overlays/settings/ui_vfx_settings_overlay.tscn").with_type(UI).with_transition("instant").with_preload(5)

	# Core end-game menus
	builder.register(&"game_over", "res://scenes/core/ui/menus/ui_game_over.tscn").with_type(END_GAME).with_preload(8)
	builder.register(&"victory", "res://scenes/core/ui/menus/ui_victory.tscn").with_type(END_GAME).with_preload(5)
	builder.register(&"credits", "res://scenes/core/ui/menus/ui_credits.tscn").with_type(END_GAME)

	return builder.build()
