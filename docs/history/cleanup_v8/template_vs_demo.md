# Template vs Demo Classification

**Phase 4 reference doc.** Classifies every subtree under `scripts/`, `resources/`, `scenes/`, and `assets/` as **core** (template infrastructure — must survive `rm -rf demo/`) or **demo** (removable example content). Mixed directories are broken down to the file level.

## Classification Rules

1. **Core** = framework code usable by any project built on this template (ECS base classes, managers, state store, UI system, input/audio/display infra, BT framework, QB rule engine, debug overlays).
2. **Demo** = content specific to the forest/AI ecology demo (wolf/deer/rabbit/sentry/patrol_drone/guide_prism creatures, Woods scenario, alleyway/bar/interior levels, demo-specific prefabs and assets).
3. A file is demo if removing it leaves the template bootable (even if featureless). A file is core if removing it breaks template boot or a framework contract.
4. Default configs (`cfg_*_default.tres`) are core even when they live beside demo variants. Scene-specific variants are demo.

---

## scripts/

| Subtree | Class | Notes |
|---------|-------|-------|
| `core/` | **CORE** | `u_service_locator.gd` |
| `ecs/base_*` (3 files) | **CORE** | Base component/entity/system classes |
| `ecs/components/c_ai_brain_component.gd` | **DEMO** | Creature AI brain |
| `ecs/components/c_detection_component.gd` | **DEMO** | AI player detection |
| `ecs/components/c_move_target_component.gd` | **DEMO** | AI move-to-target |
| `ecs/components/c_needs_component.gd` | **DEMO** | Hunger/thirst for creatures |
| `ecs/components/c_inventory_component.gd` | **DEMO** | Item carrying for AI |
| `ecs/components/c_build_site_component.gd` | **DEMO** | Building construction |
| `ecs/components/c_resource_node_component.gd` | **DEMO** | Harvestable resource |
| `ecs/components/` (all other files) | **CORE** | Input, movement, jump, health, spawn, camera, checkpoints, triggers, victory, etc. |
| `ecs/systems/s_ai_behavior_system.gd` | **DEMO** | BT AI behavior tick |
| `ecs/systems/s_ai_detection_system.gd` | **DEMO** | AI detection processing |
| `ecs/systems/s_move_target_follower_system.gd` | **DEMO** | AI following move targets |
| `ecs/systems/s_needs_system.gd` | **DEMO** | Hunger/thirst decay |
| `ecs/systems/s_resource_regrow_system.gd` | **DEMO** | Resource regrowth |
| `ecs/systems/` (all other files) | **CORE** | Movement, jump, gravity, health, death, checkpoint, camera, spawn, input, game events, etc. |
| `events/` | **CORE** | All event bus infrastructure |
| `gameplay/base_*` (3 files) | **CORE** | Base interactable/volume controller |
| `gameplay/triggered_interactable_controller.gd` | **CORE** | Triggered interactable base |
| `gameplay/inter_checkpoint_zone.gd` | **CORE** | Checkpoint zone |
| `gameplay/inter_door_trigger.gd` | **CORE** | Door trigger |
| `gameplay/inter_victory_zone.gd` | **CORE** | Victory zone |
| `gameplay/inter_hazard_zone.gd` | **CORE** | Hazard zone |
| `gameplay/inter_signpost.gd` | **CORE** | Signpost |
| `gameplay/inter_character_light_zone.gd` | **CORE** | Character light zone |
| `gameplay/inter_endgame_goal_zone.gd` | **CORE** | Endgame goal (extends victory zone) |
| `gameplay/helpers/` (2 files) | **CORE** | Interaction config resolver/validator |
| `gameplay/inter_ai_demo_flag_zone.gd` | **DEMO** | AI flag zone |
| `gameplay/inter_ai_demo_guard_barrier.gd` | **DEMO** | Guard barrier |
| `gameplay/s_demo_alarm_relay_system.gd` | **DEMO** | Alarm relay system |
| `input/` | **CORE** | All input source infrastructure |
| `interfaces/` | **CORE** | All 30 manager interface contracts |
| `managers/` | **CORE** | All 21 managers + 29 helpers |
| `resources/bt/` | **CORE** | General BT node/composite/decorator framework |
| `resources/ai/bt/` | **CORE** | AI-specific BT wrappers (action, condition, planner, scorer) — framework, not creature behaviors |
| `resources/ai/brain/rs_ai_brain_settings.gd` | **CORE** | Brain config structure (generic) |
| `resources/ai/actions/` (generic) | **CORE** | `rs_ai_action_move_to`, `move_to_detected`, `wander`, `flee_from_detected`, `animate`, `wait`, `scan`, `publish_event`, `set_field`, `move_to_nearest` |
| `resources/ai/actions/` (demo) | **DEMO** | `rs_ai_action_drink`, `feed`, `harvest`, `haul_deposit`, `build_stage` |
| `resources/ai/world/` | **DEMO** | `rs_build_site_settings`, `rs_build_stage`, `rs_inventory_settings`, `rs_resource_node_settings` |
| `resources/` (all other subdirs) | **CORE** | display, ecs, input, interactions, lighting, localization, managers, qb, scene_director, scene_management, state, ui |
| `scene_management/` | **CORE** | Scene lifecycle infrastructure |
| `scene_structure/` | **CORE** | Scene tree markers |
| `state/` | **CORE** | Redux-like state management |
| `ui/` | **CORE** | All UI framework and menus |
| `utils/bt/` | **CORE** | `u_bt_runner.gd` |
| `utils/ai/` | **DEMO** | All 7 AI creature behavior utils (context assembler, action position resolver, task label resolver, task state keys, world state builder, planner runtime, planner search) |
| `utils/` (all other subdirs) | **CORE** | core, debug, display, ecs, input, lighting, localization, math, qb, scene_director, root-level |
| `debug/debug_ai_brain_panel.gd` | **DEMO** | Creature brain debug panel |
| `debug/debug_woods_agent_label.gd` | **DEMO** | Woods agent label |
| `debug/debug_woods_build_site_label.gd` | **DEMO** | Woods build site label |
| `debug/` (other files) | **CORE** | Color grading overlay, state overlay, touchscreen debug |
| `root.gd` | **CORE** | Root bootstrap |

### AI Framework Split Summary

The AI code has a clean framework/content boundary:

- **Core AI framework** (stays in `scripts/core/resources/ai/bt/`): BT node types, utility selector, scorers, planner framework, brain settings, generic action leaves (`move_to`, `wander`, `flee`, `animate`, `wait`, `scan`, `publish_event`, `set_field`, `move_to_nearest`, `move_to_detected`).
- **Demo AI content** (moves to `scripts/demo/`): Creature-specific actions (`drink`, `feed`, `harvest`, `haul_deposit`, `build_stage`), world resource types (`build_site_settings`, `build_stage`, `inventory_settings`, `resource_node_settings`), all 7 `utils/ai/` utilities, AI brain/detection/move-target/needs/inventory/build-site/resource-node components and systems, debug panels for AI/woods.

---

## resources/

| Subtree | Class | Notes |
|---------|-------|-------|
| `ai/` | **DEMO** | All creature brain configs (guide_prism/, patrol_drone/, sentry/, woods/builder/, woods/rabbit/, woods/wolf/) |
| `base_settings/ai_woods/` | **DEMO** | 12 Woods AI base settings |
| `base_settings/audio/` | **CORE** | 7 default sound configs |
| `base_settings/display/` | **CORE** | Display/character lighting defaults |
| `base_settings/gameplay/` | **CORE** | 14 default gameplay configs (except `cfg_floating_patrol_drone_default.tres` → **DEMO**) |
| `base_settings/state/` | **CORE** | Initial state defaults |
| `audio/ambient/` | **DEMO** | Scene-specific ambient configs |
| `audio/scene_mappings/` | **DEMO** | Scene-to-audio mappings |
| `audio/tracks/` | **MIXED** | `music_main_menu.tres` + `music_pause.tres` = **CORE**; `music_alleyway/bar/exterior/interior/credits.tres` = **DEMO** |
| `audio/ui/` | **CORE** | UI sound configs |
| `display/cfg_*_presets/` | **CORE** | Post-processing, quality, window size presets |
| `display/color_gradings/` | **MIXED** | `gameplay_base` = **CORE**; `alleyway/bar/exterior/interior_house` = **DEMO** |
| `display/vcam/` | **CORE** | 6 default virtual camera configs |
| `input/` | **CORE** | All input profiles and settings |
| `interactions/*/cfg_*_default.tres` | **CORE** | Default checkpoint, door, endgame, hazard, signpost, victory configs |
| `interactions/` (scene-specific variants) | **DEMO** | Non-default configs tied to demo scenes |
| `lighting/` | **DEMO** | All character lighting profiles/zones (demo scene-specific) |
| `localization/` | **CORE** | Locale configs |
| `qb/` | **CORE** | Rule engine configs (camera, character, game rules) |
| `scene_director/` | **CORE** | Directive/objective/set configs |
| `scene_registry/` | **MIXED** | `cfg_gameplay_base_entry.tres` + all 12 UI entries = **CORE**; 9 demo scene entries = **DEMO** |
| `spawn_metadata/` | **MIXED** | `cfg_sp_base.tres` = **CORE**; all scene-specific spawn points = **DEMO** |
| `state/` | **CORE** | Initial state configs |
| `textures/` | **CORE** | Bayer dithering texture |
| `triggers/` | **CORE** | Generic trigger volume presets |
| `ui/` | **CORE** | Theme + placeholder |
| `ui/motions/` | **CORE** | UI animation configs |
| `ui_screens/` | **CORE** | 16 UI screen configs |
| `ui_themes/` | **CORE** | 9 accessibility color palettes |
| `vfx/` | **CORE** | Screen shake configs |
| `cfg_game_config.tres` | **CORE** | Top-level game config |

---

## scenes/

| File / Subtree | Class | Notes |
|----------------|-------|-------|
| `root.tscn` | **CORE** | Application root (managers, state store, UI) |
| `templates/tmpl_base_scene.tscn` | **CORE** | Base gameplay scene template |
| `templates/tmpl_camera.tscn` | **CORE** | Virtual camera template |
| `templates/tmpl_character.tscn` | **CORE** | Character template |
| `templates/tmpl_character_ragdoll.tscn` | **CORE** | Ragdoll character template |
| `gameplay/gameplay_base.tscn` | **CORE** | Base gameplay scene |
| `gameplay/gameplay_interior_base.tscn` | **CORE** | Interior base template |
| `gameplay/` (other .tscn files) | **DEMO** | ai_showcase, ai_woods, alleyway, bar, comms_array, exterior, interior_a, interior_house, nav_nexus, power_core |
| `prefabs/prefab_character.tscn` | **CORE** | Generic character prefab |
| `prefabs/prefab_player.tscn` | **CORE** | Player prefab |
| `prefabs/prefab_player_body.tscn` | **CORE** | Player body |
| `prefabs/prefab_player_ragdoll.tscn` | **CORE** | Player ragdoll |
| `prefabs/prefab_checkpoint_safe_zone.tscn` | **CORE** | Checkpoint safe zone |
| `prefabs/prefab_death_zone.tscn` | **CORE** | Death zone |
| `prefabs/prefab_door_trigger.tscn` | **CORE** | Door trigger |
| `prefabs/prefab_goal_zone.tscn` | **CORE** | Goal zone |
| `prefabs/prefab_spike_trap.tscn` | **CORE** | Spike trap |
| `prefabs/` (demo prefabs) | **DEMO** | alleyway, bar, demo_npc, demo_npc_body, all woods_* prefabs |
| `debug/debug_ai_brain_panel.tscn` | **DEMO** | AI brain debug panel |
| `debug/debug_woods_agent_label.tscn` | **DEMO** | Woods agent label |
| `debug/debug_woods_build_site_label.tscn` | **DEMO** | Woods build site label |
| `debug/` (other .tscn) | **CORE** | Color grading overlay, state overlay |
| `ui/` | **CORE** | Full UI system (hud, menus, overlays, widgets) |

---

## assets/

| Subtree | Class | Notes |
|---------|-------|-------|
| `fonts/` | **CORE** | CJK, dyslexia, default UI fonts |
| `shaders/` | **CORE** | 14 reusable shaders (color grading, daltonize, dither, film grain, room fade, wall visibility, etc.) |
| `materials/` | **CORE** | Fade materials for interaction system |
| `button_prompts/` | **CORE** | Input prompt icon set |
| `editor_icons/` | **CORE** | Custom node type icons |
| `textures/tex_checkpoint_icon.svg` | **CORE** | HUD icon |
| `textures/tex_icon.svg` | **CORE** | App icon |
| `textures/tex_interaction_v.svg` | **CORE** | Interaction icon |
| `textures/tex_shadow_blob.png` | **CORE** | Lighting system |
| `textures/tex_spinner_autosave.svg` | **CORE** | UI spinner |
| `textures/prototype_grids_png/` | **CORE** | Dev/prototyping texture set |
| `textures/tex_alleyway.png` | **DEMO** | Demo level lightmap |
| `textures/tex_bar.png` | **DEMO** | Demo level lightmap |
| `textures/tex_character.png` | **CORE** | Character texture |
| `textures/tex_character_albedo.png` | **CORE** | Character albedo |
| `textures/tex_new_character.png` | **CORE** | Character texture |
| `audio/music/` | **MIXED** | `mus_main_menu.mp3` + `mus_pause.mp3` + `mus_credits.mp3` = **CORE**; `mus_alleyway/bar/exterior/interior.mp3` = **DEMO** |
| `models/mdl_character.glb` | **CORE** | Character model |
| `models/mdl_new_character.glb` | **CORE** | Character model |
| `models/mdl_new_exterior.glb` | **DEMO** | Demo level geometry |
| `models/mdl_new_interior.glb` | **DEMO** | Demo level geometry |
| `video/` | **CORE** | UID placeholders for loading/menu videos |

---

## Other Top-Level Directories

| Directory | Class | Notes |
|-----------|-------|-------|
| `addons/` | **CORE** | GUT test framework, vertex color importer |
| `tests/` | **CORE** | Test infrastructure |
| `tools/` | **CORE** | Development tooling |
| `docs/` | **CORE** | Documentation |
| `android/` | **CORE** | Build configuration |
| `default_bus_layout.tres` | **CORE** | Audio bus layout |

---

## Mixed-Directory Decomposition

These directories contain both core and demo files and need selective migration:

### resources/interactions/
- **Keep** (core): all `cfg_*_default.tres` files
- **Move** (demo): scene-specific variants (alleyway doors, demo checkpoints, demo signposts, demo victory/endgame goals, spike trap nav nexus, demo hazards)

### resources/audio/tracks/
- **Keep** (core): `music_main_menu.tres`, `music_pause.tres`
- **Move** (demo): `music_alleyway.tres`, `music_bar.tres`, `music_credits.tres`, `music_exterior.tres`, `music_interior.tres`

### resources/display/color_gradings/
- **Keep** (core): `gameplay_base`
- **Move** (demo): `alleyway`, `bar`, `exterior`, `interior_house`

### resources/scene_registry/
- **Keep** (core): `cfg_gameplay_base_entry.tres`, all 12 UI screen entries
- **Move** (demo): 9 demo scene entries

### resources/spawn_metadata/
- **Keep** (core): `cfg_sp_base.tres`
- **Move** (demo): all scene-specific spawn metadata

### resources/base_settings/gameplay/
- **Keep** (core): all defaults except `cfg_floating_patrol_drone_default.tres`
- **Move** (demo): `cfg_floating_patrol_drone_default.tres`

### scripts/resources/ai/actions/
- **Keep** (core): 10 generic actions (move_to, move_to_detected, wander, flee_from_detected, animate, wait, scan, publish_event, set_field, move_to_nearest)
- **Move** (demo): 5 demo actions (drink, feed, harvest, haul_deposit, build_stage)

### scripts/gameplay/
- **Keep** (core): all base classes and interactable controllers
- **Move** (demo): `inter_ai_demo_flag_zone.gd`, `inter_ai_demo_guard_barrier.gd`, `s_demo_alarm_relay_system.gd`

### scripts/debug/
- **Keep** (core): color grading overlay, state overlay, touchscreen debug
- **Move** (demo): `debug_ai_brain_panel.gd`, `debug_woods_agent_label.gd`, `debug_woods_build_site_label.gd`

---

## Summary Counts

| Area | Core | Demo | Mixed |
|------|------|------|-------|
| `scripts/` | ~520 files | ~35 files | 3 dirs |
| `resources/` | ~140 files | ~50 files | 6 dirs |
| `scenes/` | ~30 files | ~20 files | 0 dirs |
| `assets/` | ~110 files | ~10 files | 1 dir |