# P4.5 Resources & Scenes Audit

**Phase 4 reference doc.** Enumerates every `.tres`, `.tscn`, and demo asset file requiring a move in P4.6–P4.8, with reference path impact analysis and commit sequence. Cross-references `template_vs_demo.md` and `target_structure.md`.

---

## Current State (as of P4.4 completion)

- `scripts/core/` and `scripts/demo/` — **complete** (P4.1–P4.4 done; all scripts moved and boundary enforcement green)
- `resources/demo/` — **complete** (107 demo `.tres` files correctly placed: AI brains, base_settings/ai_woods, audio/demo, display/color_gradings, interactions/demo, lighting, scene_registry/demo, spawn_metadata/demo, base_settings/gameplay/patrol_drone)
- `resources/core/` — **empty**; ~165 core `.tres` files remain in flat `resources/` subdirs
- `scenes/` — **entirely unsplit**; ~48 `.tscn` files need sorting into `scenes/core/` and `scenes/demo/`
- `assets/demo/` — **does not exist yet**; 4 demo music `.mp3` + 2 demo model `.glb` + 2 demo texture `.png` files (+ `.import` sidecars) need moving

---

## Godot UID Note

Godot 4.x tracks resources by UID (`uid://...`). Moving a file manually (not through the editor) leaves the engine able to find it by UID, but the human-readable `path=` strings in `.tres` and `.tscn` files become stale. The test suite and style enforcement parse paths. Every move commit must update all `path="res://..."` strings in `.gd`, `.tres`, and `.tscn` files that reference the moved resource, in the same commit as the file move.

---

## P4.6 — Resources Core Move

Move all remaining flat `resources/` subdirs into `resources/core/`. Every dir listed below is 100% core; demo content was already extracted in prior phases.

### Commit Sequence

#### Commit 1: `base_settings/`

Move 26 files:

| Source | Destination |
|--------|-------------|
| `resources/base_settings/audio/cfg_ambient_sound_default.tres` | `resources/core/base_settings/audio/` |
| `resources/base_settings/audio/cfg_checkpoint_sound_default.tres` | `resources/core/base_settings/audio/` |
| `resources/base_settings/audio/cfg_death_sound_default.tres` | `resources/core/base_settings/audio/` |
| `resources/base_settings/audio/cfg_footstep_sound_default.tres` | `resources/core/base_settings/audio/` |
| `resources/base_settings/audio/cfg_jump_sound_default.tres` | `resources/core/base_settings/audio/` |
| `resources/base_settings/audio/cfg_landing_sound_default.tres` | `resources/core/base_settings/audio/` |
| `resources/base_settings/audio/cfg_victory_sound_default.tres` | `resources/core/base_settings/audio/` |
| `resources/base_settings/display/cfg_character_lighting_config_default.tres` | `resources/core/base_settings/display/` |
| `resources/base_settings/display/cfg_display_config_default.tres` | `resources/core/base_settings/display/` |
| `resources/base_settings/gameplay/cfg_align_default.tres` | `resources/core/base_settings/gameplay/` |
| `resources/base_settings/gameplay/cfg_camera_state_config_default.tres` | `resources/core/base_settings/gameplay/` |
| `resources/base_settings/gameplay/cfg_floating_default.tres` | `resources/core/base_settings/gameplay/` |
| `resources/base_settings/gameplay/cfg_health_settings.tres` | `resources/core/base_settings/gameplay/` |
| `resources/base_settings/gameplay/cfg_jump_default.tres` | `resources/core/base_settings/gameplay/` |
| `resources/base_settings/gameplay/cfg_jump_particles_default.tres` | `resources/core/base_settings/gameplay/` |
| `resources/base_settings/gameplay/cfg_landing_indicator_default.tres` | `resources/core/base_settings/gameplay/` |
| `resources/base_settings/gameplay/cfg_landing_particles_default.tres` | `resources/core/base_settings/gameplay/` |
| `resources/base_settings/gameplay/cfg_movement_default.tres` | `resources/core/base_settings/gameplay/` |
| `resources/base_settings/gameplay/cfg_rotate_default.tres` | `resources/core/base_settings/gameplay/` |
| `resources/base_settings/gameplay/cfg_spawn_config_default.tres` | `resources/core/base_settings/gameplay/` |
| `resources/base_settings/gameplay/cfg_spawn_recovery_default.tres` | `resources/core/base_settings/gameplay/` |
| `resources/base_settings/gameplay/cfg_spawn_recovery_player_default.tres` | `resources/core/base_settings/gameplay/` |
| `resources/base_settings/gameplay/cfg_wall_visibility_config_default.tres` | `resources/core/base_settings/gameplay/` |
| `resources/base_settings/state/cfg_display_initial_state.tres` | `resources/core/base_settings/state/` |
| `resources/base_settings/state/cfg_localization_initial_state.tres` | `resources/core/base_settings/state/` |
| `resources/base_settings/state/cfg_time_initial_state.tres` | `resources/core/base_settings/state/` |

**Reference impact:** These configs are used by systems via `preload()` in `.gd` files and via `[ext_resource]` in `.tscn` files (e.g., `gameplay_base.tscn` has `path="res://resources/base_settings/..."` entries). Search: `grep -r "resources/base_settings/" --include="*.gd" --include="*.tscn" --include="*.tres"`.

#### Commit 2: `audio/` (core tracks + UI)

Move 6 files:

| Source | Destination |
|--------|-------------|
| `resources/audio/tracks/music_main_menu.tres` | `resources/core/audio/tracks/` |
| `resources/audio/tracks/music_pause.tres` | `resources/core/audio/tracks/` |
| `resources/audio/ui/ui_cancel.tres` | `resources/core/audio/ui/` |
| `resources/audio/ui/ui_confirm.tres` | `resources/core/audio/ui/` |
| `resources/audio/ui/ui_focus.tres` | `resources/core/audio/ui/` |
| `resources/audio/ui/ui_tick.tres` | `resources/core/audio/ui/` |

**Reference impact:** Audio manager or scene mapping resources reference these. The `resources/audio/tracks/` dir becomes empty after this move (demo tracks already in `resources/demo/audio/tracks/`). Search: `grep -r "resources/audio/" --include="*.gd" --include="*.tres" --include="*.tscn"`.

#### Commit 3: `display/`

Move 19 files:

| Source | Destination |
|--------|-------------|
| `resources/display/cfg_post_processing_presets/cfg_post_processing_heavy.tres` | `resources/core/display/cfg_post_processing_presets/` |
| `resources/display/cfg_post_processing_presets/cfg_post_processing_light.tres` | `resources/core/display/cfg_post_processing_presets/` |
| `resources/display/cfg_post_processing_presets/cfg_post_processing_medium.tres` | `resources/core/display/cfg_post_processing_presets/` |
| `resources/display/cfg_quality_presets/cfg_quality_high.tres` | `resources/core/display/cfg_quality_presets/` |
| `resources/display/cfg_quality_presets/cfg_quality_low.tres` | `resources/core/display/cfg_quality_presets/` |
| `resources/display/cfg_quality_presets/cfg_quality_medium.tres` | `resources/core/display/cfg_quality_presets/` |
| `resources/display/cfg_quality_presets/cfg_quality_ultra.tres` | `resources/core/display/cfg_quality_presets/` |
| `resources/display/cfg_window_size_presets/cfg_window_size_1280x720.tres` | `resources/core/display/cfg_window_size_presets/` |
| `resources/display/cfg_window_size_presets/cfg_window_size_1600x900.tres` | `resources/core/display/cfg_window_size_presets/` |
| `resources/display/cfg_window_size_presets/cfg_window_size_1920x1080.tres` | `resources/core/display/cfg_window_size_presets/` |
| `resources/display/cfg_window_size_presets/cfg_window_size_2560x1440.tres` | `resources/core/display/cfg_window_size_presets/` |
| `resources/display/cfg_window_size_presets/cfg_window_size_3840x2160.tres` | `resources/core/display/cfg_window_size_presets/` |
| `resources/display/color_gradings/cfg_color_grading_gameplay_base.tres` | `resources/core/display/color_gradings/` |
| `resources/display/vcam/cfg_default_blend_hint.tres` | `resources/core/display/vcam/` |
| `resources/display/vcam/cfg_default_orbit.tres` | `resources/core/display/vcam/` |
| `resources/display/vcam/cfg_default_region_visibility.tres` | `resources/core/display/vcam/` |
| `resources/display/vcam/cfg_default_response.tres` | `resources/core/display/vcam/` |
| `resources/display/vcam/cfg_default_room_fade.tres` | `resources/core/display/vcam/` |
| `resources/display/vcam/cfg_default_soft_zone.tres` | `resources/core/display/vcam/` |

**Reference impact:** Display manager uses preset `const` preload arrays (mobile-safe pattern). Post-processing, quality, and window-size presets use `preload("res://resources/display/...")` in display manager scripts. Color grading base is referenced from display-manager or scene `.tscn` files. VCam configs are `preload()`'d in vcam component or manager. Search: `grep -r "resources/display/" --include="*.gd" --include="*.tscn" --include="*.tres"`.

#### Commit 4: `input/`

Move 10 files:

| Source | Destination |
|--------|-------------|
| `resources/input/gamepad_settings/cfg_default_gamepad_settings.tres` | `resources/core/input/gamepad_settings/` |
| `resources/input/profiles/cfg_accessibility_gamepad.tres` | `resources/core/input/profiles/` |
| `resources/input/profiles/cfg_accessibility_keyboard.tres` | `resources/core/input/profiles/` |
| `resources/input/profiles/cfg_alternate_keyboard.tres` | `resources/core/input/profiles/` |
| `resources/input/profiles/cfg_default_gamepad.tres` | `resources/core/input/profiles/` |
| `resources/input/profiles/cfg_default_keyboard.tres` | `resources/core/input/profiles/` |
| `resources/input/profiles/cfg_default_touchscreen.tres` | `resources/core/input/profiles/` |
| `resources/input/rebind_settings/cfg_default_rebind_settings.tres` | `resources/core/input/rebind_settings/` |
| `resources/input/touchscreen_settings/cfg_default_touchscreen_settings.tres` | `resources/core/input/touchscreen_settings/` |

**Reference impact:** Input manager bootstrapper and input settings manager use these via preload. Search: `grep -r "resources/input/" --include="*.gd" --include="*.tres"`.

#### Commit 5: `interactions/`

Move 6 files (only default configs remain; all demo variants already in `resources/demo/interactions/`):

| Source | Destination |
|--------|-------------|
| `resources/interactions/checkpoints/cfg_checkpoint_default.tres` | `resources/core/interactions/checkpoints/` |
| `resources/interactions/doors/cfg_door_default.tres` | `resources/core/interactions/doors/` |
| `resources/interactions/endgame/cfg_endgame_goal_default.tres` | `resources/core/interactions/endgame/` |
| `resources/interactions/hazards/cfg_hazard_default.tres` | `resources/core/interactions/hazards/` |
| `resources/interactions/signposts/cfg_signpost_default.tres` | `resources/core/interactions/signposts/` |
| `resources/interactions/victory/cfg_victory_default.tres` | `resources/core/interactions/victory/` |

**Reference impact:** Interactable `.tscn` prefabs (`prefab_checkpoint_safe_zone.tscn`, `prefab_goal_zone.tscn`, etc.) reference default configs via `[ext_resource]`. Search: `grep -r "resources/interactions/" --include="*.gd" --include="*.tscn" --include="*.tres"`.

#### Commit 6: `localization/` + `qb/` + `scene_director/`

Move 25 files:

**localization/ (10 files):**
- `resources/localization/cfg_locale_en_hud.tres` → `resources/core/localization/`
- `resources/localization/cfg_locale_en_ui.tres` → `resources/core/localization/`
- `resources/localization/cfg_locale_es_hud.tres` → `resources/core/localization/`
- `resources/localization/cfg_locale_es_ui.tres` → `resources/core/localization/`
- `resources/localization/cfg_locale_ja_hud.tres` → `resources/core/localization/`
- `resources/localization/cfg_locale_ja_ui.tres` → `resources/core/localization/`
- `resources/localization/cfg_locale_pt_hud.tres` → `resources/core/localization/`
- `resources/localization/cfg_locale_pt_ui.tres` → `resources/core/localization/`
- `resources/localization/cfg_locale_zh_CN_hud.tres` → `resources/core/localization/`
- `resources/localization/cfg_locale_zh_CN_ui.tres` → `resources/core/localization/`

**qb/ (11 files):**
- `resources/qb/camera/cfg_camera_landing_impact_rule.tres` → `resources/core/qb/camera/`
- `resources/qb/camera/cfg_camera_shake_rule.tres` → `resources/core/qb/camera/`
- `resources/qb/camera/cfg_camera_speed_fov_rule.tres` → `resources/core/qb/camera/`
- `resources/qb/camera/cfg_camera_zone_fov_rule.tres` → `resources/core/qb/camera/`
- `resources/qb/character/cfg_death_sync_rule.tres` → `resources/core/qb/character/`
- `resources/qb/character/cfg_pause_gate_paused.tres` → `resources/core/qb/character/`
- `resources/qb/character/cfg_pause_gate_shell.tres` → `resources/core/qb/character/`
- `resources/qb/character/cfg_pause_gate_transitioning.tres` → `resources/core/qb/character/`
- `resources/qb/character/cfg_spawn_freeze_rule.tres` → `resources/core/qb/character/`
- `resources/qb/game/cfg_checkpoint_rule.tres` → `resources/core/qb/game/`
- `resources/qb/game/cfg_victory_rule.tres` → `resources/core/qb/game/`

**scene_director/ (4 files):**
- `resources/scene_director/directives/cfg_directive_gameplay_base.tres` → `resources/core/scene_director/directives/`
- `resources/scene_director/objectives/cfg_obj_game_complete.tres` → `resources/core/scene_director/objectives/`
- `resources/scene_director/objectives/cfg_obj_level_complete.tres` → `resources/core/scene_director/objectives/`
- `resources/scene_director/sets/cfg_objset_default.tres` → `resources/core/scene_director/sets/`

**Reference impact:** QB rule manager manager preloads rule configs. Scene director manager references directive/objective/set configs. Localization manager preloads locale configs. Search: `grep -r "resources/localization/\|resources/qb/\|resources/scene_director/" --include="*.gd" --include="*.tres"`.

#### Commit 7: `scene_registry/` + `spawn_metadata/` + `state/`

Move 29 files:

**scene_registry/ (13 files — all remaining are core; demo entries already in resources/demo/):**
- `resources/scene_registry/cfg_gameplay_base_entry.tres` → `resources/core/scene_registry/`
- `resources/scene_registry/cfg_ui_audio_settings_entry.tres` → `resources/core/scene_registry/`
- `resources/scene_registry/cfg_ui_credits_entry.tres` → `resources/core/scene_registry/`
- `resources/scene_registry/cfg_ui_display_settings_entry.tres` → `resources/core/scene_registry/`
- `resources/scene_registry/cfg_ui_edit_touch_controls_entry.tres` → `resources/core/scene_registry/`
- `resources/scene_registry/cfg_ui_game_over_entry.tres` → `resources/core/scene_registry/`
- `resources/scene_registry/cfg_ui_gamepad_settings_entry.tres` → `resources/core/scene_registry/`
- `resources/scene_registry/cfg_ui_input_profile_selector_entry.tres` → `resources/core/scene_registry/`
- `resources/scene_registry/cfg_ui_input_rebinding_entry.tres` → `resources/core/scene_registry/`
- `resources/scene_registry/cfg_ui_keyboard_mouse_settings_entry.tres` → `resources/core/scene_registry/`
- `resources/scene_registry/cfg_ui_localization_settings_entry.tres` → `resources/core/scene_registry/`
- `resources/scene_registry/cfg_ui_touchscreen_settings_entry.tres` → `resources/core/scene_registry/`
- `resources/scene_registry/cfg_ui_victory_entry.tres` → `resources/core/scene_registry/`

**spawn_metadata/ (1 file):**
- `resources/spawn_metadata/cfg_sp_base.tres` → `resources/core/spawn_metadata/`

**state/ (14 files):**
- `resources/state/cfg_default_audio_initial_state.tres` → `resources/core/state/`
- `resources/state/cfg_default_boot_initial_state.tres` → `resources/core/state/`
- `resources/state/cfg_default_debug_initial_state.tres` → `resources/core/state/`
- `resources/state/cfg_default_gameplay_initial_state.tres` → `resources/core/state/`
- `resources/state/cfg_default_menu_initial_state.tres` → `resources/core/state/`
- `resources/state/cfg_default_objectives_initial_state.tres` → `resources/core/state/`
- `resources/state/cfg_default_scene_director_initial_state.tres` → `resources/core/state/`
- `resources/state/cfg_default_scene_initial_state.tres` → `resources/core/state/`
- `resources/state/cfg_default_settings_initial_state.tres` → `resources/core/state/`
- `resources/state/cfg_default_state_store_settings.tres` → `resources/core/state/`
- `resources/state/cfg_default_vcam_initial_state.tres` → `resources/core/state/`
- `resources/state/cfg_default_vfx_initial_state.tres` → `resources/core/state/`
- `resources/state/cfg_navigation_initial_state.tres` → `resources/core/state/`
- `resources/state/cfg_navigation_slice_config.tres` → `resources/core/state/`

**Reference impact:**
- Scene registry entries contain scene file paths (e.g., `path = "res://scenes/gameplay/gameplay_base.tscn"`). When scene files move in P4.7, these entries need a second update. For P4.6, only the registry `.tres` file path itself changes.
- Scene manager and spawn registry use `preload()` or `load()` of registry entries.
- State store manager preloads initial state configs.
- Search: `grep -r "resources/scene_registry/\|resources/spawn_metadata/\|resources/state/" --include="*.gd" --include="*.tres" --include="*.tscn"`.

#### Commit 8: `textures/` + `triggers/` + `ui/` + `ui_screens/` + `ui_themes/` + `vfx/` + `cfg_game_config.tres`

Move 40 files:

**textures/ (2 files — PNG + .import):**
- `resources/textures/tex_bayer_8x8.png` → `resources/core/textures/`
- `resources/textures/tex_bayer_8x8.png.import` → `resources/core/textures/`

**triggers/ (9 files):**
- `resources/triggers/cfg_ai_nav_fall_zone_volume.tres` → `resources/core/triggers/`
- `resources/triggers/cfg_checkpoint_box_2x3x2.tres` → `resources/core/triggers/`
- `resources/triggers/cfg_cylinder_wide_door_trigger_settings.tres` → `resources/core/triggers/`
- `resources/triggers/cfg_death_zone_volume.tres` → `resources/core/triggers/`
- `resources/triggers/cfg_goal_cylinder.tres` → `resources/core/triggers/`
- `resources/triggers/cfg_scene_trigger_settings.tres` → `resources/core/triggers/`
- `resources/triggers/cfg_signpost_cylinder.tres` → `resources/core/triggers/`
- `resources/triggers/cfg_spike_trap_volume.tres` → `resources/core/triggers/`
- `resources/triggers/cfg_trigger_box_wide_door.tres` → `resources/core/triggers/`

**ui/ (9 files — theme, placeholder, motions):**
- `resources/ui/cfg_ui_theme_default.tres` → `resources/core/ui/`
- `resources/ui/tex_save_slot_placeholder.png` → `resources/core/ui/`
- `resources/ui/tex_save_slot_placeholder.png.import` → `resources/core/ui/`
- `resources/ui/motions/cfg_motion_button_default.tres` → `resources/core/ui/motions/`
- `resources/ui/motions/cfg_motion_fade_slide.tres` → `resources/core/ui/motions/`
- `resources/ui/motions/cfg_motion_hud_checkpoint_toast.tres` → `resources/core/ui/motions/`
- `resources/ui/motions/cfg_motion_hud_signpost_fade_in.tres` → `resources/core/ui/motions/`
- `resources/ui/motions/cfg_motion_hud_signpost_fade_out.tres` → `resources/core/ui/motions/`

**ui_screens/ (17 files):**
- `resources/ui_screens/cfg_audio_settings_overlay.tres` → `resources/core/ui_screens/`
- `resources/ui_screens/cfg_credits_screen.tres` → `resources/core/ui_screens/`
- `resources/ui_screens/cfg_display_settings_overlay.tres` → `resources/core/ui_screens/`
- `resources/ui_screens/cfg_edit_touch_controls_overlay.tres` → `resources/core/ui_screens/`
- `resources/ui_screens/cfg_game_over_screen.tres` → `resources/core/ui_screens/`
- `resources/ui_screens/cfg_gamepad_settings_overlay.tres` → `resources/core/ui_screens/`
- `resources/ui_screens/cfg_input_profile_selector_overlay.tres` → `resources/core/ui_screens/`
- `resources/ui_screens/cfg_input_rebinding_overlay.tres` → `resources/core/ui_screens/`
- `resources/ui_screens/cfg_keyboard_mouse_settings_overlay.tres` → `resources/core/ui_screens/`
- `resources/ui_screens/cfg_localization_settings_overlay.tres` → `resources/core/ui_screens/`
- `resources/ui_screens/cfg_main_menu_screen.tres` → `resources/core/ui_screens/`
- `resources/ui_screens/cfg_pause_menu_overlay.tres` → `resources/core/ui_screens/`
- `resources/ui_screens/cfg_save_load_menu_overlay.tres` → `resources/core/ui_screens/`
- `resources/ui_screens/cfg_settings_menu_overlay.tres` → `resources/core/ui_screens/`
- `resources/ui_screens/cfg_touchscreen_settings_overlay.tres` → `resources/core/ui_screens/`
- `resources/ui_screens/cfg_vfx_settings_overlay.tres` → `resources/core/ui_screens/`
- `resources/ui_screens/cfg_victory_screen.tres` → `resources/core/ui_screens/`

**ui_themes/ (9 files):**
- `resources/ui_themes/cfg_palette_deuteranopia.tres` → `resources/core/ui_themes/`
- `resources/ui_themes/cfg_palette_deuteranopia_high_contrast.tres` → `resources/core/ui_themes/`
- `resources/ui_themes/cfg_palette_high_contrast.tres` → `resources/core/ui_themes/`
- `resources/ui_themes/cfg_palette_normal.tres` → `resources/core/ui_themes/`
- `resources/ui_themes/cfg_palette_normal_high_contrast.tres` → `resources/core/ui_themes/`
- `resources/ui_themes/cfg_palette_protanopia.tres` → `resources/core/ui_themes/`
- `resources/ui_themes/cfg_palette_protanopia_high_contrast.tres` → `resources/core/ui_themes/`
- `resources/ui_themes/cfg_palette_tritanopia.tres` → `resources/core/ui_themes/`
- `resources/ui_themes/cfg_palette_tritanopia_high_contrast.tres` → `resources/core/ui_themes/`

**vfx/ (2 files):**
- `resources/vfx/cfg_screen_shake_config.tres` → `resources/core/vfx/`
- `resources/vfx/cfg_screen_shake_tuning.tres` → `resources/core/vfx/`

**top-level (1 file):**
- `resources/cfg_game_config.tres` → `resources/core/cfg_game_config.tres`

**Reference impact:** UI theme used by all UI `.tscn` files. UI screens preloaded by the UI manager. VFX configs preloaded by VFX manager. `cfg_game_config.tres` likely preloaded by root.gd or a manager. Triggers used by prefab `.tscn` files. Bayer texture used by display/post-processing scripts. Search: `grep -r "resources/textures/\|resources/triggers/\|resources/ui/\|resources/ui_screens/\|resources/ui_themes/\|resources/vfx/\|cfg_game_config" --include="*.gd" --include="*.tscn" --include="*.tres"`.

---

## P4.7 — Scenes Split

Split `scenes/` into `scenes/core/` and `scenes/demo/`.

### Core scenes (move to `scenes/core/`)

| File | Classification reason |
|------|-----------------------|
| `scenes/root.tscn` | Application root — managers, state store, UI |
| `scenes/templates/tmpl_base_scene.tscn` | Base gameplay scene template |
| `scenes/templates/tmpl_camera.tscn` | Virtual camera template |
| `scenes/templates/tmpl_character.tscn` | Character template |
| `scenes/templates/tmpl_character_ragdoll.tscn` | Ragdoll character template |
| `scenes/gameplay/gameplay_base.tscn` | Base gameplay scene (inherited by all levels) |
| `scenes/gameplay/gameplay_interior_base.tscn` | Interior base template |
| `scenes/prefabs/prefab_character.tscn` | Generic character prefab |
| `scenes/prefabs/prefab_player.tscn` | Player prefab |
| `scenes/prefabs/prefab_player_body.tscn` | Player body |
| `scenes/prefabs/prefab_player_ragdoll.tscn` | Player ragdoll |
| `scenes/prefabs/prefab_checkpoint_safe_zone.tscn` | Checkpoint safe zone |
| `scenes/prefabs/prefab_death_zone.tscn` | Death zone |
| `scenes/prefabs/prefab_door_trigger.tscn` | Door trigger |
| `scenes/prefabs/prefab_goal_zone.tscn` | Goal zone |
| `scenes/prefabs/prefab_spike_trap.tscn` | Spike trap |
| `scenes/debug/debug_color_grading_overlay.tscn` | Core debug overlay |
| `scenes/debug/debug_state_overlay.tscn` | Core debug overlay |
| `scenes/ui/hud/ui_button_prompt.tscn` | Core UI |
| `scenes/ui/hud/ui_hud_overlay.tscn` | Core UI |
| `scenes/ui/hud/ui_loading_screen.tscn` | Core UI |
| `scenes/ui/hud/ui_mobile_controls.tscn` | Core UI |
| `scenes/ui/menus/ui_credits.tscn` | Core UI |
| `scenes/ui/menus/ui_game_over.tscn` | Core UI |
| `scenes/ui/menus/ui_language_selector.tscn` | Core UI |
| `scenes/ui/menus/ui_main_menu.tscn` | Core UI |
| `scenes/ui/menus/ui_pause_menu.tscn` | Core UI |
| `scenes/ui/menus/ui_settings_menu.tscn` | Core UI |
| `scenes/ui/menus/ui_splash_screen.tscn` | Core UI |
| `scenes/ui/menus/ui_victory.tscn` | Core UI |
| `scenes/ui/overlays/settings/ui_audio_settings_overlay.tscn` | Core UI |
| `scenes/ui/overlays/settings/ui_audio_settings_tab.tscn` | Core UI |
| `scenes/ui/overlays/settings/ui_display_settings_overlay.tscn` | Core UI |
| `scenes/ui/overlays/settings/ui_display_settings_tab.tscn` | Core UI |
| `scenes/ui/overlays/settings/ui_localization_settings_overlay.tscn` | Core UI |
| `scenes/ui/overlays/settings/ui_localization_settings_tab.tscn` | Core UI |
| `scenes/ui/overlays/settings/ui_vfx_settings_overlay.tscn` | Core UI |
| `scenes/ui/overlays/ui_damage_flash_overlay.tscn` | Core UI |
| `scenes/ui/overlays/ui_edit_touch_controls_overlay.tscn` | Core UI |
| `scenes/ui/overlays/ui_gamepad_settings_overlay.tscn` | Core UI |
| `scenes/ui/overlays/ui_input_profile_selector.tscn` | Core UI |
| `scenes/ui/overlays/ui_input_rebinding_overlay.tscn` | Core UI |
| `scenes/ui/overlays/ui_keyboard_mouse_settings_overlay.tscn` | Core UI |
| `scenes/ui/overlays/ui_post_process_overlay.tscn` | Core UI |
| `scenes/ui/overlays/ui_save_load_menu.tscn` | Core UI |
| `scenes/ui/overlays/ui_touchscreen_settings_overlay.tscn` | Core UI |
| `scenes/ui/widgets/ui_gamepad_preview_prompt.tscn` | Core UI |
| `scenes/ui/widgets/ui_virtual_button.tscn` | Core UI |
| `scenes/ui/widgets/ui_virtual_joystick.tscn` | Core UI |

(49 files total, including `.gitkeep` placeholders that can be dropped or kept)

### Demo scenes (move to `scenes/demo/`)

| File | Classification reason |
|------|-----------------------|
| `scenes/gameplay/gameplay_ai_showcase.tscn` | Demo AI showcase level |
| `scenes/gameplay/gameplay_ai_woods.tscn` | Demo woods forest level |
| `scenes/gameplay/gameplay_alleyway.tscn` | Demo alleyway level |
| `scenes/gameplay/gameplay_bar.tscn` | Demo bar level |
| `scenes/gameplay/gameplay_comms_array.tscn` | Demo comms array level |
| `scenes/gameplay/gameplay_exterior.tscn` | Demo exterior level |
| `scenes/gameplay/gameplay_interior_a.tscn` | Demo interior level |
| `scenes/gameplay/gameplay_interior_house.tscn` | Demo interior house level |
| `scenes/gameplay/gameplay_nav_nexus.tscn` | Demo nav nexus level |
| `scenes/gameplay/gameplay_power_core.tscn` | Demo power core level |
| `scenes/prefabs/prefab_alleyway.tscn` | Demo alleyway geometry |
| `scenes/prefabs/prefab_bar.tscn` | Demo bar geometry |
| `scenes/prefabs/prefab_demo_npc.tscn` | Demo NPC prefab |
| `scenes/prefabs/prefab_demo_npc_body.tscn` | Demo NPC body |
| `scenes/prefabs/prefab_woods_builder.tscn` | Woods builder creature |
| `scenes/prefabs/prefab_woods_construction_site.tscn` | Woods construction site |
| `scenes/prefabs/prefab_woods_rabbit.tscn` | Woods rabbit creature |
| `scenes/prefabs/prefab_woods_stockpile.tscn` | Woods stockpile |
| `scenes/prefabs/prefab_woods_stone.tscn` | Woods stone resource |
| `scenes/prefabs/prefab_woods_tree.tscn` | Woods tree resource |
| `scenes/prefabs/prefab_woods_water.tscn` | Woods water resource |
| `scenes/prefabs/prefab_woods_wolf.tscn` | Woods wolf creature |
| `scenes/debug/debug_ai_brain_panel.tscn` | Demo AI debug panel |
| `scenes/debug/debug_woods_agent_label.tscn` | Demo woods debug |
| `scenes/debug/debug_woods_build_site_label.tscn` | Demo woods debug |

(25 files total)

### P4.7 Commit sequence

**Commit P4.7-A: Demo scenes**
- Move all 25 demo scenes to `scenes/demo/`
- Update scene registry `.tres` entries in `resources/demo/scene_registry/` — each entry's `path` field references the scene file. After P4.6 these entries are at `resources/core/scene_registry/`, and the scene paths they contain must update to `res://scenes/demo/gameplay/...`
- Update any `preload()` / `load()` in demo scripts that reference demo scene paths
- Verify `project.godot` does NOT reference demo scenes (they're loaded via registry at runtime, not boot)

**Commit P4.7-B: Core scenes**
- Move all 49 core scenes to `scenes/core/`
- Update `project.godot` `application/run/main_scene` — currently points to `root.tscn` by UID; the UID stays valid but the path hint must update to `res://scenes/core/root.tscn`
- Update all `preload()` / `load()` in core scripts that load scenes by path (e.g., UI manager loading scene paths from registry entries, scene manager transition targets)
- Update core scene registry entries (gameplay_base and all UI entries) — their `path` fields reference scene paths and must update to `res://scenes/core/...`
- Update `[ext_resource]` entries within core `.tscn` files that reference other core scenes (e.g., `gameplay_base.tscn` referencing `prefab_player.tscn`)

**Note:** Scene registry entries for core scenes will need updating in TWO places:
1. After P4.6 Commit 7, registry entries move from `resources/scene_registry/` to `resources/core/scene_registry/`
2. After P4.7-B, the `path =` fields inside those entries change from `res://scenes/...` to `res://scenes/core/...`

---

## P4.8 — Assets Demo Move

Move 4 demo MP3s + 2 demo models + 2 demo textures (+ their `.import` sidecars) to `assets/demo/`.

### Files to move

| Source | Destination |
|--------|-------------|
| `assets/audio/music/mus_alleyway.mp3` | `assets/demo/audio/music/` |
| `assets/audio/music/mus_alleyway.mp3.import` | `assets/demo/audio/music/` |
| `assets/audio/music/mus_bar.mp3` | `assets/demo/audio/music/` |
| `assets/audio/music/mus_bar.mp3.import` | `assets/demo/audio/music/` |
| `assets/audio/music/mus_exterior.mp3` | `assets/demo/audio/music/` |
| `assets/audio/music/mus_exterior.mp3.import` | `assets/demo/audio/music/` |
| `assets/audio/music/mus_interior.mp3` | `assets/demo/audio/music/` |
| `assets/audio/music/mus_interior.mp3.import` | `assets/demo/audio/music/` |
| `assets/models/mdl_new_exterior.glb` | `assets/demo/models/` |
| `assets/models/mdl_new_exterior.glb.import` | `assets/demo/models/` |
| `assets/models/mdl_new_interior.glb` | `assets/demo/models/` |
| `assets/models/mdl_new_interior.glb.import` | `assets/demo/models/` |
| `assets/textures/tex_alleyway.png` | `assets/demo/textures/` |
| `assets/textures/tex_alleyway.png.import` | `assets/demo/textures/` |
| `assets/textures/tex_bar.png` | `assets/demo/textures/` |
| `assets/textures/tex_bar.png.import` | `assets/demo/textures/` |

(16 files total)

### Files that stay in place (CORE assets)

- `assets/audio/music/mus_main_menu.mp3` + `.import` — core template music
- `assets/audio/music/mus_pause.mp3` + `.import` — core template music
- `assets/audio/music/mus_credits.mp3` + `.import` — core credits screen music
- `assets/models/mdl_character.glb` + `.import` — core character model
- `assets/models/mdl_new_character.glb` + `.import` — core character model
- All `assets/fonts/`, `assets/shaders/`, `assets/materials/`, `assets/button_prompts/`, `assets/editor_icons/`, `assets/video/` — unchanged
- All `assets/textures/tex_*.svg/.png` except alleyway/bar — unchanged

### Reference impact

- `resources/demo/audio/tracks/music_alleyway.tres` (and bar, exterior, interior) contain `stream = ExtResource(...)` pointing to the MP3 by UID + path. Path string must update to `res://assets/demo/audio/music/mus_alleyway.mp3`
- Demo gameplay scenes (`gameplay_alleyway.tscn`, `gameplay_bar.tscn`, `gameplay_exterior.tscn`, `gameplay_interior_house.tscn`) contain `[ext_resource]` entries for models and textures — paths must update to `res://assets/demo/...`
- Search: `grep -r "mus_alleyway\|mus_bar\|mus_exterior\|mus_interior\|mdl_new_exterior\|mdl_new_interior\|tex_alleyway\|tex_bar" --include="*.tres" --include="*.tscn"`

---

## Reference Impact Summary

### Highest-volume path changes

| Change | Files affected | grep pattern |
|--------|---------------|--------------|
| `resources/base_settings/` → `resources/core/base_settings/` | `.gd` systems + `.tscn` scenes | `resources/base_settings/` |
| `resources/display/` → `resources/core/display/` | display manager `.gd` + presets | `resources/display/` |
| `resources/ui_screens/` → `resources/core/ui_screens/` | UI manager `.gd` | `resources/ui_screens/` |
| `resources/state/` → `resources/core/state/` | state store `.gd` | `resources/state/` |
| `resources/scene_registry/` → `resources/core/scene_registry/` | scene manager `.gd` | `resources/scene_registry/` |
| `scenes/prefabs/` → `scenes/core/prefabs/` + `scenes/demo/prefabs/` | gameplay `.tscn` + `.tres` | `scenes/prefabs/` |
| `scenes/gameplay/` → `scenes/core/gameplay/` + `scenes/demo/gameplay/` | scene registry entries | `scenes/gameplay/` |
| `scenes/ui/` → `scenes/core/ui/` | UI manager + root.tscn | `scenes/ui/` |

### project.godot changes

- `application/run/main_scene` — UID-based reference; path hint must update to `res://scenes/core/root.tscn`
- No autoload paths change (autoloads live in `scripts/core/` which already moved in P4.1–P4.4)

### .tres internal references

Some `.tres` files reference other `.tres` files (e.g., a scene registry entry `.tres` references a scene `.tscn` path; an audio track `.tres` references an `.mp3` asset path). Every such cross-reference must be updated in the same commit as the referenced file's move.

---

## Style Enforcement After Each Commit

Run after every P4.6/P4.7/P4.8 commit:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd
```

P4.9 will add new enforcement tests (`test_core_resources_never_reference_demo`, `test_core_scenes_never_reference_demo`). Until those tests exist, rely on the style suite for naming/LOC checks and manual grep verification for boundary compliance.

---

## Totals

| Phase | Files to move | Commits |
|-------|--------------|---------|
| P4.6 resources core | ~165 `.tres` files | 8 commits |
| P4.7 scenes split | ~74 `.tscn` files (core + demo) | 2 commits |
| P4.8 assets demo | 16 files (8 + .imports) | 1 commit |
| **Total** | **~255 files** | **11 commits** |
