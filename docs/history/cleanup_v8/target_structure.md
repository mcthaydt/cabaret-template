# Target Structure — Core/Demo Split

**Phase 4 reference doc.** Defines the target directory layout after the template-vs-demo separation. Source of truth for P4.3 move commits.

Companion to `template_vs_demo.md` (P4.1 classification). That doc classifies every file; this doc defines where each classification lands.

---

## Principles

1. **`scripts/core/` is the template.** Everything under it must work after `rm -rf scripts/demo/ resources/demo/ scenes/demo/ assets/demo/`.
2. **Demo can import from core.** Core must never import from demo (enforced by P4.4).
3. **`scripts/core/u_service_locator.gd` already exists** (landed in cleanup-v1). P4 extends it in place.
4. **Move only what must move.** Whole-directory moves where a dir is 100% core or 100% demo. Selective file moves for mixed dirs.
5. **Each move commit is atomic:** file moves + all import/`.tres`/scene path updates + `project.godot` autoload entries in one commit.

---

## Classification Corrections

The P4.1 classification doc labels all 7 `scripts/utils/ai/` files as demo. Dependency analysis reveals 5 are actually core (consumed by the BT framework):

| File | P4.1 Class | Corrected Class | Reason |
|------|------------|-----------------|--------|
| `u_ai_task_state_keys.gd` | DEMO | **CORE** | Used by `rs_bt_action.gd` (core BT leaf) |
| `u_ai_action_position_resolver.gd` | DEMO | **CORE** | Used by 4 core actions (wander, flee, move_to_nearest, move_to_detected) |
| `u_ai_world_state_builder.gd` | DEMO | **CORE** | Used by `rs_bt_planner.gd` (core BT planner) |
| `u_bt_planner_runtime.gd` | DEMO | **CORE** | Used by `rs_bt_planner.gd` (core BT planner) |
| `u_bt_planner_search.gd` | DEMO | **CORE** | Used by `rs_bt_planner.gd` (core BT planner) |
| `u_ai_bt_task_label_resolver.gd` | DEMO | DEMO | Only used by `s_ai_behavior_system.gd` (demo) |
| `u_ai_context_assembler.gd` | DEMO | DEMO | Only used by `s_ai_behavior_system.gd` (demo) |

Also:

| File | P4.1 Class | Corrected Class | Reason |
|------|------------|-----------------|--------|
| `scripts/demo/debug/utils/u_ai_render_probe.gd` | CORE (default) | **DEMO** | Only used by demo systems (`s_ai_behavior_system`, `s_move_target_follower_system`) |
| `scripts/resources/ai/actions/rs_ai_action_reserve.gd` | (unclassified) | **DEMO** | References `c_resource_node_component`; only used by builder brain |

---

## scripts/

### scripts/core/

```text
scripts/core/
├── u_service_locator.gd              # already present — unchanged
├── root.gd                            # root bootstrap
├── ecs/
│   ├── base_ecs_component.gd
│   ├── base_ecs_entity.gd
│   ├── base_ecs_system.gd
│   ├── base_event_sfx_system.gd
│   ├── base_event_vfx_system.gd
│   ├── u_entity_query.gd
│   ├── components/                    # core components only
│   │   ├── c_align_with_surface_component.gd
│   │   ├── c_camera_state_component.gd
│   │   ├── c_character_state_component.gd
│   │   ├── c_checkpoint_component.gd
│   │   ├── c_damage_zone_component.gd
│   │   ├── c_floating_component.gd
│   │   ├── c_gamepad_component.gd
│   │   ├── c_health_component.gd
│   │   ├── c_input_component.gd
│   │   ├── c_jump_component.gd
│   │   ├── c_landing_indicator_component.gd
│   │   ├── c_movement_component.gd
│   │   ├── c_player_tag_component.gd
│   │   ├── c_region_visibility_component.gd
│   │   ├── c_room_fade_group_component.gd
│   │   ├── c_rotate_to_input_component.gd
│   │   ├── c_scene_trigger_component.gd
│   │   ├── c_spawn_recovery_component.gd
│   │   ├── c_spawn_state_component.gd
│   │   ├── c_surface_detector_component.gd
│   │   ├── c_surface_type_component.gd
│   │   ├── c_vcam_component.gd
│   │   └── c_victory_trigger_component.gd
│   ├── resources/                     # all ECS resource types
│   │   └── (all rs_* files — rs_needs_settings.gd included; generic type)
│   └── systems/                      # core systems only
│       ├── s_align_with_surface_system.gd
│       ├── s_camera_state_system.gd
│       ├── s_character_state_system.gd
│       ├── s_checkpoint_handler_system.gd
│       ├── s_checkpoint_sound_system.gd
│       ├── s_damage_flash_publisher_system.gd
│       ├── s_damage_system.gd
│       ├── s_death_handler_system.gd
│       ├── s_death_sound_system.gd
│       ├── s_floating_system.gd
│       ├── s_footstep_sound_system.gd
│       ├── s_game_event_system.gd
│       ├── s_gamepad_vibration_system.gd
│       ├── s_gravity_system.gd
│       ├── s_health_system.gd
│       ├── s_input_system.gd
│       ├── s_jump_particles_system.gd
│       ├── s_jump_sound_system.gd
│       ├── s_jump_system.gd
│       ├── s_landing_indicator_system.gd
│       ├── s_landing_particles_system.gd
│       ├── s_landing_sound_system.gd
│       ├── s_movement_system.gd
│       ├── s_playtime_system.gd
│       ├── s_region_visibility_system.gd
│       ├── s_rotate_to_input_system.gd
│       ├── s_scene_trigger_system.gd
│       ├── s_screen_shake_publisher_system.gd
│       ├── s_spawn_particles_system.gd
│       ├── s_spawn_recovery_system.gd
│       ├── s_touchscreen_system.gd
│       ├── s_vcam_system.gd
│       ├── s_victory_handler_system.gd
│       ├── s_victory_sound_system.gd
│       ├── s_wall_visibility_system.gd
│       └── helpers/                  # vcam helpers — all core
│           └── (all u_vcam_* files)
├── events/                            # all event bus infrastructure
│   ├── base_event_bus.gd
│   ├── ecs/                          # all ECS event types + bus
│   └── state/                        # state event bus
├── gameplay/                          # core interactables only
│   ├── base_interactable_controller.gd
│   ├── base_volume_controller.gd
│   ├── triggered_interactable_controller.gd
│   ├── inter_checkpoint_zone.gd
│   ├── inter_door_trigger.gd
│   ├── inter_endgame_goal_zone.gd
│   ├── inter_hazard_zone.gd
│   ├── inter_signpost.gd
│   ├── inter_victory_zone.gd
│   ├── inter_character_light_zone.gd
│   └── helpers/
│       ├── u_interaction_config_resolver.gd
│       └── u_interaction_config_validator.gd
├── input/                             # all input source infrastructure
│   ├── sources/
│   │   ├── gamepad_source.gd
│   │   ├── keyboard_mouse_source.gd
│   │   └── touchscreen_source.gd
│   ├── u_device_type_constants.gd
│   └── u_input_map_bootstrapper.gd
├── interfaces/                        # all 30 manager interface contracts
├── managers/                          # all 21 managers + 29 helpers
├── resources/                         # core script resources
│   ├── bt/                           # general BT framework
│   │   ├── rs_bt_node.gd
│   │   ├── rs_bt_composite.gd
│   │   ├── rs_bt_decorator.gd
│   │   ├── rs_bt_sequence.gd
│   │   ├── rs_bt_selector.gd
│   │   ├── rs_bt_utility_selector.gd
│   │   ├── rs_bt_cooldown.gd
│   │   ├── rs_bt_once.gd
│   │   ├── rs_bt_rising_edge.gd
│   │   └── rs_bt_inverter.gd
│   ├── ai/
│   │   ├── bt/                       # AI-specific BT wrappers (framework)
│   │   │   ├── rs_bt_action.gd
│   │   │   ├── rs_bt_condition.gd
│   │   │   ├── rs_bt_planner.gd
│   │   │   ├── rs_bt_planner_action.gd
│   │   │   ├── rs_world_state_effect.gd
│   │   │   └── scorers/
│   │   │       ├── rs_ai_scorer.gd
│   │   │       ├── rs_ai_scorer_constant.gd
│   │   │       ├── rs_ai_scorer_condition.gd
│   │   │       └── rs_ai_scorer_context_field.gd
│   │   ├── brain/
│   │   │   └── rs_ai_brain_settings.gd  # generic brain config structure
│   │   └── actions/                  # core actions only (10 generic)
│   │       ├── rs_ai_action_animate.gd
│   │       ├── rs_ai_action_flee_from_detected.gd
│   │       ├── rs_ai_action_move_to.gd
│   │       ├── rs_ai_action_move_to_detected.gd
│   │       ├── rs_ai_action_move_to_nearest.gd
│   │       ├── rs_ai_action_publish_event.gd
│   │       ├── rs_ai_action_scan.gd
│   │       ├── rs_ai_action_set_field.gd
│   │       ├── rs_ai_action_wait.gd
│   │       └── rs_ai_action_wander.gd
│   ├── display/                      # all display resources
│   ├── ecs/                          # all ECS resources (including rs_needs_settings)
│   ├── input/                        # all input resources
│   ├── interactions/                 # default configs only
│   ├── lighting/                     # character light zone config + lighting profile types
│   ├── localization/                 # locale resources
│   ├── managers/                     # manager config types
│   ├── qb/                           # rule engine resources
│   ├── scene_director/               # directive/objective/set resources
│   ├── scene_management/             # scene registry entry type + spawn metadata type
│   ├── state/                        # all state resources
│   ├── ui/                           # UI theme + motion types
│   └── rs_game_config.gd
├── scene_management/                  # all scene lifecycle infrastructure
│   ├── handlers/
│   ├── helpers/
│   ├── transitions/
│   ├── sp_spawn_point.gd
│   ├── u_scene_registry.gd
│   ├── u_spawn_registry.gd
│   ├── u_transition_factory.gd
│   ├── u_transition_orchestrator.gd
│   └── u_tween_manager.gd
├── scene_structure/                    # all scene tree markers
├── state/                             # all state management
│   ├── m_state_store.gd
│   ├── actions/
│   ├── reducers/
│   ├── selectors/
│   ├── utils/
│   └── u_state_action_types.gd
├── ui/                                # all UI framework and menus
│   ├── base/
│   ├── helpers/
│   ├── hud/
│   ├── menus/
│   ├── overlays/
│   ├── settings/
│   ├── utils/
│   └── u_canvas_layers.gd
├── utils/                             # core utils
│   ├── bt/
│   │   └── u_bt_runner.gd
│   ├── ai/                           # core AI utils (used by BT framework)
│   │   ├── u_ai_task_state_keys.gd
│   │   ├── u_ai_action_position_resolver.gd
│   │   ├── u_ai_world_state_builder.gd
│   │   ├── u_bt_planner_runtime.gd
│   │   └── u_bt_planner_search.gd
│   ├── core/
│   ├── debug/                        # core debug utils (minus u_ai_render_probe)
│   │   ├── u_debug_log_throttle.gd
│   │   ├── u_perf_fade_bypass.gd
│   │   ├── u_perf_monitor.gd
│   │   ├── u_perf_probe.gd
│   │   └── u_perf_shader_bypass.gd
│   ├── display/
│   ├── ecs/
│   ├── input/
│   ├── lighting/
│   ├── localization/
│   ├── math/
│   ├── qb/
│   ├── scene_director/
│   └── (root-level utils: u_audio_serialization.gd, u_audio_utils.gd, etc.)
└── debug/                             # core debug scenes/scripts only
    ├── debug_color_grading_overlay.gd
    ├── debug_extract_touchscreen_settings.gd
    └── debug_state_overlay.gd
```

### scripts/demo/

```text
scripts/demo/
├── ecs/
│   ├── components/
│   │   ├── c_ai_brain_component.gd
│   │   ├── c_detection_component.gd
│   │   ├── c_move_target_component.gd
│   │   ├── c_needs_component.gd
│   │   ├── c_inventory_component.gd
│   │   ├── c_build_site_component.gd
│   │   └── c_resource_node_component.gd
│   └── systems/
│       ├── s_ai_behavior_system.gd
│       ├── s_ai_detection_system.gd
│       ├── s_move_target_follower_system.gd
│       ├── s_needs_system.gd
│       └── s_resource_regrow_system.gd
├── gameplay/
│   ├── inter_ai_demo_flag_zone.gd
│   ├── inter_ai_demo_guard_barrier.gd
│   └── s_demo_alarm_relay_system.gd
├── resources/
│   ├── ai/
│   │   ├── actions/                   # demo actions (5)
│   │   │   ├── rs_ai_action_build_stage.gd
│   │   │   ├── rs_ai_action_drink.gd
│   │   │   ├── rs_ai_action_feed.gd
│   │   │   ├── rs_ai_action_harvest.gd
│   │   │   ├── rs_ai_action_haul_deposit.gd
│   │   │   └── rs_ai_action_reserve.gd
│   │   └── world/                    # demo world resource types
│   │       ├── rs_build_site_settings.gd
│   │       ├── rs_build_stage.gd
│   │       ├── rs_inventory_settings.gd
│   │       └── rs_resource_node_settings.gd
│   └── lighting/                      # lighting profile + zone resource types (demo-scene-specific)
│       ├── rs_character_lighting_profile.gd
│       └── rs_character_light_zone_config.gd
├── utils/
│   └── ai/                           # demo AI utils
│       ├── u_ai_bt_task_label_resolver.gd
│       └── u_ai_context_assembler.gd
└── debug/
    ├── debug_ai_brain_panel.gd
    ├── debug_woods_agent_label.gd
    ├── debug_woods_build_site_label.gd
    └── utils/
        └── u_ai_render_probe.gd
```

---

## resources/

### resources/core/

```text
resources/core/
├── cfg_game_config.tres
├── base_settings/
│   ├── audio/                         # 7 default sound configs
│   ├── display/                       # display/character lighting defaults
│   ├── gameplay/                      # 14 defaults (minus patrol_drone)
│   │   ├── cfg_align_default.tres
│   │   ├── cfg_camera_state_config_default.tres
│   │   ├── cfg_floating_default.tres
│   │   ├── cfg_health_settings.tres
│   │   ├── cfg_jump_default.tres
│   │   ├── cfg_jump_particles_default.tres
│   │   ├── cfg_landing_indicator_default.tres
│   │   ├── cfg_landing_particles_default.tres
│   │   ├── cfg_movement_default.tres
│   │   ├── cfg_rotate_default.tres
│   │   ├── cfg_spawn_config_default.tres
│   │   ├── cfg_spawn_recovery_default.tres
│   │   ├── cfg_spawn_recovery_player_default.tres
│   │   └── cfg_wall_visibility_config_default.tres
│   └── state/                         # initial state defaults
├── audio/
│   └── ui/                            # UI sound configs
├── display/
│   ├── cfg_post_processing_presets/   # 3 presets
│   ├── cfg_quality_presets/            # 4 presets
│   ├── cfg_window_size_presets/        # 5 presets
│   ├── color_gradings/
│   │   └── cfg_color_grading_gameplay_base.tres  # core only
│   └── vcam/                          # 6 default camera configs
├── input/                             # all input profiles + settings
├── interactions/                      # default configs only
│   ├── checkpoints/cfg_checkpoint_default.tres
│   ├── doors/cfg_door_default.tres
│   ├── endgame/cfg_endgame_goal_default.tres
│   ├── hazards/cfg_hazard_default.tres
│   ├── signposts/cfg_signpost_default.tres
│   └── victory/cfg_victory_default.tres
├── localization/                       # locale configs
├── qb/                                # rule engine configs
├── scene_director/                    # directive/objective/set configs
├── scene_registry/                    # core entries only
│   ├── cfg_gameplay_base_entry.tres
│   └── cfg_ui_*_entry.tres           # all 12 UI screen entries
├── spawn_metadata/
│   └── cfg_sp_base.tres              # core spawn metadata only
├── state/                             # initial state configs
├── textures/
│   └── tex_bayer_8x8.png             # dithering texture
├── triggers/                          # generic trigger volume presets
├── ui/                                # theme + placeholder
├── ui/motions/                        # UI animation configs
├── ui_screens/                        # 16 UI screen configs
├── ui_themes/                         # 9 accessibility palettes
└── vfx/                               # screen shake configs
```

### resources/demo/

```text
resources/demo/
├── ai/                                # creature brain configs
│   ├── cfg_ai_brain_placeholder.tres
│   ├── guide_prism/
│   ├── patrol_drone/
│   ├── sentry/
│   └── woods/
├── base_settings/
│   └── ai_woods/                      # 12 Woods AI base settings
├── audio/
│   ├── ambient/                       # scene-specific ambient configs
│   ├── scene_mappings/               # scene-to-audio mappings
│   └── tracks/                        # demo music .tres configs
│       ├── music_alleyway.tres
│       ├── music_bar.tres
│       ├── music_credits.tres
│       ├── music_exterior.tres
│       └── music_interior.tres
├── display/
│   └── color_gradings/               # demo color gradings
│       ├── cfg_color_grading_alleyway.tres
│       ├── cfg_color_grading_bar.tres
│       ├── cfg_color_grading_exterior.tres
│       └── cfg_color_grading_interior_house.tres
├── interactions/                      # scene-specific variants
│   ├── checkpoints/                   # alleyway, safe_zone
│   ├── doors/                         # all non-default door configs
│   ├── endgame/                       # alleyway, exterior
│   ├── hazards/                       # death_zone, nav_nexus_fall, spike_trap
│   ├── signposts/                     # bar_tutorial, exterior_tutorial, interior_tutorial
│   └── victory/                       # goal_bar, goal_interior_house, goal_prefab
├── lighting/                          # all demo lighting profiles + zones
│   ├── (root-level profiles)
│   ├── profiles/
│   └── zones/
├── scene_registry/                    # demo scene entries (9)
│   ├── cfg_ai_showcase_entry.tres
│   ├── cfg_ai_woods_entry.tres
│   ├── cfg_alleyway_entry.tres
│   ├── cfg_bar_entry.tres
│   ├── cfg_comms_array_entry.tres
│   ├── cfg_interior_a_entry.tres
│   ├── cfg_interior_house_entry.tres
│   ├── cfg_nav_nexus_entry.tres
│   └── cfg_power_core_entry.tres
├── spawn_metadata/                    # scene-specific spawn points (all except cfg_sp_base)
│   ├── cfg_sp_ai_patrol_drone.tres
│   ├── cfg_sp_bar.tres
│   ├── cfg_sp_bar_entrance.tres
│   ├── cfg_sp_exterior.tres
│   ├── cfg_sp_exterior_checkpoint.tres
│   ├── cfg_sp_exterior_exit_from_bar.tres
│   ├── cfg_sp_exterior_exit_from_house.tres
│   ├── cfg_sp_interior_a.tres
│   ├── cfg_sp_interior_house.tres
│   └── cfg_sp_interior_house_entrance.tres
└── base_settings/
    └── gameplay/
        └── cfg_floating_patrol_drone_default.tres
```

---

## scenes/

### scenes/core/

```text
scenes/core/
├── root.tscn
├── templates/
│   ├── tmpl_base_scene.tscn
│   ├── tmpl_camera.tscn
│   ├── tmpl_character.tscn
│   └── tmpl_character_ragdoll.tscn
├── gameplay/
│   ├── gameplay_base.tscn
│   └── gameplay_interior_base.tscn
├── prefabs/
│   ├── prefab_character.tscn
│   ├── prefab_player.tscn
│   ├── prefab_player_body.tscn
│   ├── prefab_player_ragdoll.tscn
│   ├── prefab_checkpoint_safe_zone.tscn
│   ├── prefab_death_zone.tscn
│   ├── prefab_door_trigger.tscn
│   ├── prefab_goal_zone.tscn
│   └── prefab_spike_trap.tscn
├── debug/
│   ├── debug_color_grading_overlay.tscn
│   └── debug_state_overlay.tscn
└── ui/                               # full UI system (unchanged)
    ├── hud/
    ├── menus/
    ├── overlays/
    ├── widgets/
    └── ...
```

### scenes/demo/

```text
scenes/demo/
├── gameplay/
│   ├── gameplay_ai_showcase.tscn
│   ├── gameplay_ai_woods.tscn
│   ├── gameplay_alleyway.tscn
│   ├── gameplay_bar.tscn
│   ├── gameplay_comms_array.tscn
│   ├── gameplay_exterior.tscn
│   ├── gameplay_interior_a.tscn
│   ├── gameplay_interior_house.tscn
│   ├── gameplay_nav_nexus.tscn
│   └── gameplay_power_core.tscn
├── prefabs/
│   ├── prefab_alleyway.tscn
│   ├── prefab_bar.tscn
│   ├── prefab_demo_npc.tscn
│   ├── prefab_demo_npc_body.tscn
│   ├── prefab_woods_builder.tscn
│   ├── prefab_woods_construction_site.tscn
│   ├── prefab_woods_rabbit.tscn
│   ├── prefab_woods_stockpile.tscn
│   ├── prefab_woods_stone.tscn
│   ├── prefab_woods_tree.tscn
│   ├── prefab_woods_water.tscn
│   └── prefab_woods_wolf.tscn
└── debug/
    ├── debug_ai_brain_panel.tscn
    ├── debug_woods_agent_label.tscn
    └── debug_woods_build_site_label.tscn
```

---

## assets/

Core assets stay in their current locations (fonts/, shaders/, materials/, button_prompts/, editor_icons/, video/). Demo-only assets move to `assets/demo/`.

### assets/demo/

```text
assets/demo/
├── models/
│   ├── mdl_new_exterior.glb
│   └── mdl_new_interior.glb
├── textures/
│   ├── tex_alleyway.png
│   └── tex_bar.png
└── audio/
    └── music/
        ├── mus_alleyway.mp3
        ├── mus_bar.mp3
        ├── mus_exterior.mp3
        └── mus_interior.mp3
```

Core assets that stay in place:
- `assets/fonts/` — CJK, dyslexia, default UI fonts
- `assets/shaders/` — 14 reusable shaders
- `assets/materials/` — fade materials
- `assets/button_prompts/` — input prompt icons
- `assets/editor_icons/` — custom node type icons
- `assets/video/` — UID placeholders
- `assets/textures/tex_*.svg/.png` — core icons and textures (character, checkpoint, interaction, shadow, spinner, prototype grids)
- `assets/audio/music/mus_main_menu.mp3`, `mus_pause.mp3`, `mus_credits.mp3` — core music
- `assets/models/mdl_character.glb`, `mdl_new_character.glb` — character models

---

## Migration Order (P4.3)

Recommended commit sequence to minimize mid-migration breakage:

1. **`scripts/demo/` creation** — move demo scripts first (smaller set, clearer dependencies)
   - Commit 1: ECS demo components + systems
   - Commit 2: Gameplay demo interactables
   - Commit 3: Demo AI actions + world resource types
   - Commit 4: Demo lighting resource types
   - Commit 5: Demo utils (context assembler, task label resolver, render probe)
   - Commit 6: Demo debug scripts/panels
2. **`scripts/core/` population** — move core scripts into core/
   - Commit 7: root.gd + scene_structure/ + events/ (no demo cross-deps)
   - Commit 8: interfaces/ + managers/ (no demo cross-deps)
   - Commit 9: input/ + state/ + ui/ + scene_management/ (no demo cross-deps)
   - Commit 10: resources/ core split (bt/, ai/bt/, ai/actions/, ai/brain/, other core resources)
   - Commit 11: ecs/ core split (base classes, core components, core systems, helpers)
   - Commit 12: gameplay/ core split
   - Commit 13: utils/ core split
   - Commit 14: debug/ core split
3. **`resources/` split** — move resource files
   - Commit 15: resources/demo/ (ai brains, base_settings/ai_woods, demo audio, demo interactions, demo lighting, demo scene_registry, demo spawn_metadata, demo color gradings, patrol_drone settings)
   - Commit 16: resources/core/ (everything remaining)
4. **`scenes/` split** — move scene files
   - Commit 17: scenes/demo/
   - Commit 18: scenes/core/
5. **`assets/` split** — move demo-only assets
   - Commit 19: assets/demo/
6. **`project.godot` + global updates** — update autoload paths, import references
   - Commit 20: project.godot updates + any remaining path fixes

Each commit must: (a) update all `preload()`/`load()` paths in `.gd` files, (b) update all resource references in `.tres` files, (c) update all script references in `.tscn` files, (d) pass the full test suite.

---

## Import Implications

### class_name references (no change needed)

GDScript `class_name` is resolved globally by the engine. Moving a file does not break `class_name` references — only `preload()`/`load()` with explicit `res://` paths break.

### preload() / load() paths

Every `preload("res://scripts/ecs/...")` must become `preload("res://scripts/core/ecs/...")` or `preload("res://scripts/demo/ecs/...")`. These are the highest-volume changes.

### .tres resource references
`.tres` files store script paths and resource references as `res://` paths. All must update when the referenced file moves.

### .tscn scene references
`.tscn` files store `script` resource paths and `PackedScene` instance paths. All must update.

### project.godot

Autoload entries reference `res://scripts/root.gd` → must become `res://scripts/core/root.gd`. Any other registered paths must update.

---

## Delete Test

After all moves complete, this must pass:

```bash
# Delete demo subtrees
rm -rf scripts/demo/ resources/demo/ scenes/demo/ assets/demo/

# Template still boots and passes core tests
tools/run_gut_suite.sh
```
