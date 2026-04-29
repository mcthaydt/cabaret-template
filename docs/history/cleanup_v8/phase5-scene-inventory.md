# Phase 5 Scene Inventory

Generated: 2026-04-29. Classifies every `.tscn` under `scenes/` plus relevant
script files as **keep** or **delete** for Phase 5.

## Keep — Core Base/Template (4)

| File | Purpose |
|---|---|
| `scenes/core/templates/tmpl_base_scene.tscn` | Canonical base scene for 2.5D gameplay |
| `scenes/core/templates/tmpl_camera.tscn` | Camera rig template |
| `scenes/core/templates/tmpl_character.tscn` | Character prefab template |
| `scenes/core/templates/tmpl_character_ragdoll.tscn` | Character ragdoll template |

## Keep — Core Gameplay (2)

| File | Purpose |
|---|---|
| `scenes/core/gameplay/gameplay_base.tscn` | Abstract gameplay base scene (not instantiated directly) |
| `scenes/core/gameplay/gameplay_interior_base.tscn` | Interior gameplay base (not instantiated directly) |

## Keep — Core Prefabs (9)

| File | Purpose |
|---|---|
| `scenes/core/prefabs/prefab_player.tscn` | Player character prefab |
| `scenes/core/prefabs/prefab_player_body.tscn` | Player body mesh prefab |
| `scenes/core/prefabs/prefab_player_ragdoll.tscn` | Player ragdoll prefab |
| `scenes/core/prefabs/prefab_character.tscn` | Generic character prefab |
| `scenes/core/prefabs/prefab_spike_trap.tscn` | Spike trap hazard prefab |
| `scenes/core/prefabs/prefab_goal_zone.tscn` | Goal/win zone prefab |
| `scenes/core/prefabs/prefab_door_trigger.tscn` | Door transition trigger prefab |
| `scenes/core/prefabs/prefab_death_zone.tscn` | Death/kill zone prefab |
| `scenes/core/prefabs/prefab_checkpoint_safe_zone.tscn` | Checkpoint safe zone prefab |

## Keep — Core Debug (2)

| File | Purpose |
|---|---|
| `scenes/core/debug/debug_state_overlay.tscn` | State debug overlay |
| `scenes/core/debug/debug_color_grading_overlay.tscn` | Color grading debug overlay |

## Keep — Core UI Menus (8)

| File | Purpose |
|---|---|
| `scenes/core/ui/menus/ui_splash_screen.tscn` | Boot splash screen |
| `scenes/core/ui/menus/ui_language_selector.tscn` | Language selection screen |
| `scenes/core/ui/menus/ui_main_menu.tscn` | Main menu |
| `scenes/core/ui/menus/ui_settings_menu.tscn` | Settings menu |
| `scenes/core/ui/menus/ui_pause_menu.tscn` | Pause menu |
| `scenes/core/ui/menus/ui_victory.tscn` | Victory/win screen |
| `scenes/core/ui/menus/ui_game_over.tscn` | Game over screen |
| `scenes/core/ui/menus/ui_credits.tscn` | Credits screen |

## Keep — Core UI HUD (4)

| File | Purpose |
|---|---|
| `scenes/core/ui/hud/ui_hud_overlay.tscn` | HUD overlay container |
| `scenes/core/ui/hud/ui_loading_screen.tscn` | Loading screen |
| `scenes/core/ui/hud/ui_mobile_controls.tscn` | Mobile touch controls |
| `scenes/core/ui/hud/ui_button_prompt.tscn` | Button prompt widget |

## Keep — Core UI Overlays (19)

| File | Purpose |
|---|---|
| `scenes/core/ui/overlays/ui_save_load_menu.tscn` | Save/load menu overlay |
| `scenes/core/ui/overlays/ui_input_rebinding_overlay.tscn` | Input rebinding overlay |
| `scenes/core/ui/overlays/ui_gamepad_settings_overlay.tscn` | Gamepad settings |
| `scenes/core/ui/overlays/ui_touchscreen_settings_overlay.tscn` | Touchscreen settings |
| `scenes/core/ui/overlays/ui_edit_touch_controls_overlay.tscn` | Touch control editor |
| `scenes/core/ui/overlays/ui_input_profile_selector.tscn` | Input profile selector |
| `scenes/core/ui/overlays/ui_keyboard_mouse_settings_overlay.tscn` | Keyboard/mouse settings |
| `scenes/core/ui/overlays/settings/ui_audio_settings_overlay.tscn` | Audio settings |
| `scenes/core/ui/overlays/settings/ui_display_settings_overlay.tscn` | Display settings |
| `scenes/core/ui/overlays/settings/ui_localization_settings_overlay.tscn` | Localization settings |
| `scenes/core/ui/overlays/settings/ui_vfx_settings_overlay.tscn` | VFX settings |
| `scenes/core/ui/overlays/settings/ui_accessibility_settings_overlay.tscn` | Accessibility settings |
| `scenes/core/ui/overlays/settings/ui_gameplay_settings_overlay.tscn` | Gameplay settings |
| `scenes/core/ui/overlays/settings/ui_screen_reader_settings_overlay.tscn` | Screen reader settings |
| `scenes/core/ui/overlays/settings/ui_shader_settings_overlay.tscn` | Shader settings |
| `scenes/core/ui/overlays/settings/ui_subtitle_settings_overlay.tscn` | Subtitle settings |
| `scenes/core/ui/overlays/settings/ui_ui_scale_settings_overlay.tscn` | UI scale settings |
| `scenes/core/ui/overlays/settings/ui_vibration_settings_overlay.tscn` | Vibration settings |
| `scenes/core/ui/overlays/settings/ui_volume_settings_overlay.tscn` | Volume settings |

## Keep — Core UI Widgets (3)

| File | Purpose |
|---|---|
| `scenes/core/ui/widgets/ui_virtual_joystick.tscn` | Virtual joystick widget |
| `scenes/core/ui/widgets/ui_virtual_button.tscn` | Virtual button widget |
| `scenes/core/ui/widgets/ui_gamepad_preview_prompt.tscn` | Gamepad preview widget |

## Keep — Core Root (1)

| File | Purpose |
|---|---|
| `scenes/core/root.tscn` | Project bootstrap root (project.godot main_scene) |

## Keep — Demo (New) (1)

| File | Purpose |
|---|---|
| `scenes/demo/gameplay/gameplay_demo_room.tscn` | Single-room 2.5D blockout demo entry (created in P5.3) |

## Delete — Demo Gameplay (10)

| File | Reason |
|---|---|
| `scenes/demo/gameplay/gameplay_alleyway.tscn` | Legacy demo scene, cut for clean slate |
| `scenes/demo/gameplay/gameplay_bar.tscn` | Legacy demo scene, cut for clean slate |
| `scenes/demo/gameplay/gameplay_interior_house.tscn` | Legacy demo scene, cut for clean slate |
| `scenes/demo/gameplay/gameplay_interior_a.tscn` | Legacy demo scene, cut for clean slate |
| `scenes/demo/gameplay/gameplay_exterior.tscn` | Legacy demo scene, cut for clean slate |
| `scenes/demo/gameplay/gameplay_power_core.tscn` | Legacy demo scene, cut for clean slate |
| `scenes/demo/gameplay/gameplay_comms_array.tscn` | Legacy demo scene, cut for clean slate |
| `scenes/demo/gameplay/gameplay_nav_nexus.tscn` | Legacy demo scene, cut for clean slate |
| `scenes/demo/gameplay/gameplay_ai_showcase.tscn` | Legacy demo AI scene, cut for clean slate |
| `scenes/demo/gameplay/gameplay_ai_woods.tscn` | Legacy demo AI scene, cut for clean slate |

## Delete — Demo Prefabs (11)

| File | Reason |
|---|---|
| `scenes/demo/prefabs/prefab_woods_builder.tscn` | Served deleted ai_woods scene |
| `scenes/demo/prefabs/prefab_demo_npc.tscn` | Served deleted demo scenes |
| `scenes/demo/prefabs/prefab_demo_npc_body.tscn` | Served deleted demo scenes |
| `scenes/demo/prefabs/prefab_woods_wolf.tscn` | Served deleted ai_woods scene |
| `scenes/demo/prefabs/prefab_woods_water.tscn` | Served deleted ai_woods scene |
| `scenes/demo/prefabs/prefab_woods_tree.tscn` | Served deleted ai_woods scene |
| `scenes/demo/prefabs/prefab_woods_stone.tscn` | Served deleted ai_woods scene |
| `scenes/demo/prefabs/prefab_woods_stockpile.tscn` | Served deleted ai_woods scene |
| `scenes/demo/prefabs/prefab_woods_rabbit.tscn` | Served deleted ai_woods scene |
| `scenes/demo/prefabs/prefab_woods_construction_site.tscn` | Served deleted ai_woods scene |
| `scenes/demo/prefabs/prefab_bar.tscn` | Served deleted bar scene |
| `scenes/demo/prefabs/prefab_alleyway.tscn` | Served deleted alleyway scene |

## Delete — Demo Debug (3)

| File | Reason |
|---|---|
| `scenes/demo/debug/debug_woods_build_site_label.tscn` | Served deleted ai_woods scene |
| `scenes/demo/debug/debug_woods_agent_label.tscn` | Served deleted ai_woods scene |
| `scenes/demo/debug/debug_ai_brain_panel.tscn` | Served deleted AI scenes |

## Delete — Demo Editor Builders (21)

All files under `scripts/demo/editors/build_*.gd` except `build_gameplay_demo_room.gd`:

| File | Reason |
|---|---|
| `scripts/demo/editors/build_prefab_alleyway.gd` | Builds deleted alleyway prefab |
| `scripts/demo/editors/build_prefab_bar.gd` | Builds deleted bar prefab |
| `scripts/demo/editors/build_prefab_character.gd` | Builds core prefab (redundant with core path) |
| `scripts/demo/editors/build_prefab_checkpoint_safe_zone.gd` | Builds core prefab (redundant) |
| `scripts/demo/editors/build_prefab_death_zone.gd` | Builds core prefab (redundant) |
| `scripts/demo/editors/build_prefab_demo_npc.gd` | Builds deleted NPC prefab |
| `scripts/demo/editors/build_prefab_demo_npc_body.gd` | Builds deleted NPC body prefab |
| `scripts/demo/editors/build_prefab_door_trigger.gd` | Builds core prefab (redundant) |
| `scripts/demo/editors/build_prefab_goal_zone.gd` | Builds core prefab (redundant) |
| `scripts/demo/editors/build_prefab_player.gd` | Builds core player prefab (redundant) |
| `scripts/demo/editors/build_prefab_player_body.gd` | Builds core player body (redundant) |
| `scripts/demo/editors/build_prefab_player_ragdoll.gd` | Builds core prefab (redundant) |
| `scripts/demo/editors/build_prefab_spike_trap.gd` | Builds core prefab (redundant) |
| `scripts/demo/editors/build_prefab_woods_builder.gd` | Builds deleted woods prefab |
| `scripts/demo/editors/build_prefab_woods_construction_site.gd` | Builds deleted woods prefab |
| `scripts/demo/editors/build_prefab_woods_rabbit.gd` | Builds deleted woods prefab |
| `scripts/demo/editors/build_prefab_woods_stockpile.gd` | Builds deleted woods prefab |
| `scripts/demo/editors/build_prefab_woods_stone.gd` | Builds deleted woods prefab |
| `scripts/demo/editors/build_prefab_woods_tree.gd` | Builds deleted woods prefab |
| `scripts/demo/editors/build_prefab_woods_water.gd` | Builds deleted woods prefab |
| `scripts/demo/editors/build_prefab_woods_wolf.gd` | Builds deleted woods prefab |

Also delete their `.uid` files.

## Delete — Demo ECS Systems (5)

| File | Reason |
|---|---|
| `scripts/demo/ecs/systems/s_ai_behavior_system.gd` | Demo AI system, no runtime consumers remain |
| `scripts/demo/ecs/systems/s_resource_regrow_system.gd` | Demo resource system, no consumers |
| `scripts/demo/ecs/systems/s_ai_detection_system.gd` | Demo AI detection, no consumers |
| `scripts/demo/ecs/systems/s_move_target_follower_system.gd` | Demo movement, no consumers |
| `scripts/demo/ecs/systems/s_needs_system.gd` | Demo needs system, no consumers |

## Delete — Demo Gameplay Scripts (2)

| File | Reason |
|---|---|
| `scripts/demo/gameplay/inter_ai_demo_flag_zone.gd` | Served deleted ai_showcase scene |
| `scripts/demo/gameplay/inter_ai_demo_guard_barrier.gd` | Served deleted ai_showcase scene |

## Delete — Demo-Specific Tests (2)

| File | Reason |
|---|---|
| `tests/unit/ai/resources/test_ai_showcase_scene.gd` | Tests only deleted `gameplay_ai_showcase.tscn` |
| `tests/unit/ai/integration/test_builder_brain_bt.gd` | Tests only deleted demo AI builder feature |

## Summary

| Classification | Count |
|---|---|
| Keep (core scenes) | ~52 `.tscn` |
| Keep (demo — new) | 1 `.tscn` + 1 builder `.gd` |
| Delete (demo scenes) | 24 `.tscn` |
| Delete (demo builder scripts) | 21 `.gd` + 21 `.uid` |
| Delete (demo ECS systems) | 5 `.gd` + 5 `.uid` |
| Delete (demo gameplay scripts) | 2 `.gd` + 2 `.uid` |
| Delete (demo-specific tests) | 2 `.gd` |
