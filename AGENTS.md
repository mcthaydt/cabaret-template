# Agents Notes

## Start Here

- Project type: Godot 4.6 (GDScript). Core area:
  - `scripts/ecs`: Lightweight ECS built on Nodes (components + systems + manager).
- Scenes and resources:
  - `scenes/templates/`: Base scene, character, and camera templates that wire components/systems together.
  - `resources/base_settings/`: Default `*Settings.tres` for component configs (domain subfolders); update defaults when adding new exported fields.
  - `assets/audio/`, `assets/button_prompts/`, `assets/editor_icons/`: Shared asset libraries for audio, input glyphs, and editor UI.
- Documentation to consult (do not duplicate here):
  - General pitfalls: `docs/general/DEV_PITFALLS.md`
- Before adding or modifying code, re-read `docs/general/DEV_PITFALLS.md` and `docs/general/STYLE_GUIDE.md` to stay aligned with testing and formatting requirements.
- Keep project planning docs current: whenever a story advances, update the relevant plan and PRD documents immediately so written guidance matches the implementation state.
- **MANDATORY: Update continuation prompt and tasks checklist after EVERY phase**: When completing a phase (e.g., Phase 2 of Scene Manager), you MUST:
  1. Update the continuation prompt file (e.g., `docs/scene_manager/scene-manager-continuation-prompt.md`) with current status
  2. Update the tasks file (e.g., `docs/scene_manager/scene-manager-tasks.md`) to mark completed tasks with [x] and add completion notes
  3. Update AGENTS.md with new patterns/architecture (if applicable)
  4. Update DEV_PITFALLS.md with new pitfalls discovered (if applicable)
  5. Commit documentation updates separately from implementation
- Commit at the end of each completed story (or logical, test-green milestone) so every commit represents a verified state.
- Make a git commit whenever a feature, refactor, or documentation update moves the needle forward; keep commits focused and validated. Skipping required commits is a blocker—treat the guidance as non-optional.
- **MANDATORY: Run style and scene organization tests before merging**: After any changes to file naming, scene structure, or adding new scripts/scenes, run `tests/unit/style/test_style_enforcement.gd` to ensure prefix compliance and scene structure validity. Automated checks enforce the prefix rules documented in `STYLE_GUIDE.md`.

## Repo Map (essentials)

- `scripts/managers/m_ecs_manager.gd`: Registers components/systems; exposes `get_components(StringName)` and emits component signals.
- `scripts/managers/m_scene_manager.gd`: Scene transition coordinator (Phase 3+); manages ActiveSceneContainer.
- `scripts/managers/m_save_manager.gd`: Save/load coordinator; manages save slots, atomic writes, migrations, and autosave scheduling.
- `scripts/state/m_state_store.gd`: Redux store; registers with ServiceLocator for discovery via `U_StateUtils.get_store()`.
- `scripts/ui/utils/u_ui_registry.gd` + `resources/ui_screens/`: UI registry definitions (`RS_UIScreenDefinition`) for base screens and overlays.
- UI controllers are grouped by screen type: `scripts/ui/menus/`, `scripts/ui/overlays/`, `scripts/ui/hud/` (utilities live in `scripts/ui/utils/`).
- UI scenes organized by type: `scenes/ui/menus/`, `scenes/ui/overlays/`, `scenes/ui/hud/`, `scenes/ui/widgets/` (cleanup v4.5).
- `scripts/ecs/base_ecs_component.gd`: Base for components. Auto-registers with manager; exposes `get_snapshot()` hook.
- `scripts/ecs/base_ecs_system.gd`: Base for systems. Implement `process_tick(delta)`; runs via `_physics_process`.
- `scripts/ecs/components/*`: Gameplay components with `@export` NodePaths and typed getters.
- `scripts/ecs/systems/*`: Systems that query components by `StringName` and operate per-physics tick.
- `scripts/resources/ecs/*`: `Resource` classes holding tunables consumed by components/systems.
- `scripts/utils/ecs/u_ecs_utils.gd`: ECS helpers (manager lookup, time, component mapping). Input helpers live in `scripts/utils/input/`.
- `scripts/events/ecs/`: ECS event bus + typed ECS events; `scripts/events/state/` holds `U_StateEventBus` (state-domain bus).
- `scenes/root.tscn`: Main scene (persistent managers + containers).
- `scenes/gameplay/*`: Gameplay scenes (dynamic loading, own M_ECSManager).
- `tests/unit/*`: GUT test suites for ECS and state management.

## ECS Guidelines

- Components
  - Extend `BaseECSComponent`; define `const COMPONENT_TYPE := StringName("YourComponent")` and set `component_type = COMPONENT_TYPE` in `_init()`.
  - Enforce required settings/resources by overriding `_validate_required_settings()` (call `push_error(...)` and return `false` to abort registration); use `_on_required_settings_ready()` for post-validation setup.
  - Prefer `@export` NodePaths with typed getters that use `get_node_or_null(...) as Type` and return `null` on empty paths.
  - Keep null-safe call sites; systems assume absent paths disable behavior rather than error.
  - If you expose debug state, copy via `snapshot.duplicate(true)` to avoid aliasing.
  - Spawn freeze/unfreeze state lives in `C_SpawnStateComponent` (`is_physics_frozen`, `unfreeze_at_frame`, `suppress_landing_until_frame`); systems gate movement/jump/floating via this component.
- Systems
  - Extend `BaseECSSystem`; implement `process_tick(delta)` (invoked from `_physics_process`).
  - Query with `get_components(StringName)`, dedupe per-body where needed, and clamp/guard values (see movement/rotation/floating examples).
  - Use `U_ECSUtils.map_components_by_body()` when multiple systems need shared body→component dictionaries (avoids duplicate loops).
  - Auto-discovers `M_ECSManager` via parent traversal or ServiceLocator (`ecs_manager`); no manual wiring needed.
  - Event-driven request systems should extend `BaseEventVFXSystem` / `BaseEventSFXSystem` and implement `get_event_name()` + `create_request_from_payload()` to enqueue `requests`.
- VFX Event Requests (Phase 1 refactor)
  - Publisher systems translate gameplay events into VFX request events.
  - `M_VFXManager` subscribes to VFX request events and processes queues in `_physics_process()`.
  - Player-only + transition gating: `M_VFXManager` filters requests via `_is_player_entity()` and `_is_transition_blocked()` using Redux `gameplay.player_entity_id`, `scene.is_transitioning`, `scene.scene_stack`, and `navigation.shell == "gameplay"`.
  - Use `U_ECSEventNames` constants for subscriptions instead of string literals.
- VFX Tuning Resources (Phase 4)
  - `RS_ScreenShakeTuning` defines trauma decay + damage/landing/death curves; defaults in `resources/vfx/cfg_screen_shake_tuning.tres`.
  - `RS_ScreenShakeConfig` defines shake offset/rotation/noise; defaults in `resources/vfx/cfg_screen_shake_config.tres`.
  - `S_ScreenShakePublisherSystem` reads tuning (export injection optional), `M_VFXManager` uses tuning for decay and config for `U_ScreenShake`.
- VFX Settings Preview (Phase 8)
  - `M_VFXManager` supports temporary overrides via `set_vfx_settings_preview(...)` and `clear_vfx_settings_preview()`.
  - `UI_VFXSettingsOverlay` pushes preview updates on toggle/slider changes and calls `trigger_test_shake()` on intensity changes; preview is cleared on cancel or overlay exit.
- **Testing with Dependency Injection (Phase 10B-8)**
  - Systems support `@export` dependency injection for isolated testing with mocks.
  - **Inject ECS manager**: All systems inherit `@export var ecs_manager: I_ECSManager` from BaseECSSystem.
  - **Inject state store**: 9 state-dependent systems have `@export var state_store: I_StateStore` (S_HealthSystem, S_VictorySystem, S_CheckpointSystem, S_InputSystem, S_GamepadVibrationSystem, S_GravitySystem, S_MovementSystem, S_JumpSystem, S_RotateToInputSystem).
  - **Injection priority chain**: U_StateUtils.get_store() and U_ECSUtils.get_manager() check @export injection first, then fall back to ServiceLocator. Production code unchanged (auto-discovery if not injected).
  - **Mock classes**: Use `MockStateStore` and `MockECSManager` from `tests/mocks/` for isolated testing.
  - **Example test pattern**:
    ```gdscript
    var mock_manager := MockECSManager.new()
    var mock_store := MockStateStore.new()
    var system := S_HealthSystem.new()
    system.ecs_manager = mock_manager  # Inject via @export
    system.state_store = mock_store    # Inject via @export
    # Test system in isolation without real managers
    ```
  - **Mock helpers**: `MockStateStore.get_dispatched_actions()` verifies actions; `MockStateStore.set_slice()` sets up test state; `MockECSManager.add_component_to_entity()` populates components.
- Manager
  - Ensure exactly one `M_ECSManager` in-scene. It registers with ServiceLocator on `_ready()`.
  - Emits `component_added`/`component_removed` and calls `component.on_registered(self)`.
  - `get_components()` strips out null entries automatically; only guard for missing components when logic truly requires it.
  - Entity root caching is dictionary-backed in `M_ECSManager`/`U_ECSUtils` (no metadata tags); `BaseECSEntity` registers itself with the manager for lookups.
- Entities (Phase 6 - Entity IDs & Tags)
  - All entities extend `BaseECSEntity` (Node3D with entity_id and tags exports).
  - **Entity IDs**: Auto-generated from node name (`E_Player` → `"player"`), or manually set via `entity_id` export. Cached after first access. Duplicate IDs automatically get `_{instance_id}` suffix.
  - **Tags**: Freeform `Array[StringName]` for categorization. Use `add_tag(tag)`, `remove_tag(tag)`, `has_tag(tag)` to modify. Tags auto-update manager's tag index.
  - **Manager queries**: `get_entity_by_id(id)`, `get_entities_by_tag(tag)`, `get_entities_by_tags(tags, match_all)`.
  - **Auto-registration**: Entities automatically register with `M_ECSManager` when their first component registers. Publishes `"entity_registered"` event to `U_ECSEventBus`.
  - **State integration**: `U_ECSUtils.build_entity_snapshot(entity)` includes entity_id and tags for Redux persistence.
  - Example: `player.entity_id = StringName("player"); player.tags = [StringName("player"), StringName("controllable")]`

## Scene Organization

- **Root scene pattern (NEW - Phase 2)**: `scenes/root.tscn` persists throughout session
  - Persistent managers: `M_StateStore`, `M_CursorManager`, `M_SceneManager`
  - Scene containers: `ActiveSceneContainer`, `UIOverlayStack`, `TransitionOverlay`, `LoadingOverlay`
  - Gameplay scenes load/unload as children of `ActiveSceneContainer`
- Mobile touch controls: `scenes/ui/mobile_controls.tscn` CanvasLayer lives in root; shows virtual joystick/buttons on mobile or `--emulate-mobile`, hides during transitions/pause/gamepad input
- **Gameplay scenes**: Each has own `M_ECSManager` instance
  - Example: `scenes/gameplay/gameplay_base.tscn`
  - Contains: Systems, Entities, SceneObjects, Environment
  - HUD uses `U_StateUtils.get_store(self)` to find M_StateStore via ServiceLocator (or injected store)
- Node tree structure: See `docs/scene_organization/SCENE_ORGANIZATION_GUIDE.md`
- Templates: `scenes/templates/tmpl_base_scene.tscn`, `scenes/templates/tmpl_character.tscn`, `scenes/templates/tmpl_camera.tscn`
- Marker scripts: `scripts/scene_structure/*` (11 total) provide visual organization
- Systems organized by category: Core / Physics / Movement / Feedback
- Naming: Node names use prefixes matching their script types (E_, Inter_, S_, C_, M_, SO_, Env_)

### Interactable Controllers

- Controllers live in `scripts/gameplay/` and replace ad-hoc `C_*` nodes; create a single `Inter_*` controller per interactable (node names may remain `E_*` in scenes):
  - Base stack: `base_volume_controller.gd`, `base_interactable_controller.gd`, `triggered_interactable_controller.gd`
  - Concrete controllers: `inter_door_trigger.gd`, `inter_checkpoint_zone.gd`, `inter_hazard_zone.gd`, `inter_victory_zone.gd`, `inter_signpost.gd`, `inter_endgame_goal_zone.gd`
- Controllers auto-create/adopt `Area3D` volumes using `RS_SceneTriggerSettings`—never author separate component or Area children manually.
- `triggered_interactable_controller.gd` publishes `interact_prompt_show` / `interact_prompt_hide` events; HUD renders the prompt label.
- `inter_signpost.gd` emits `signpost_message` events; HUD reuses the checkpoint toast UI for signpost text.
- Exterior/interior scenes are now fixtures built on controllers; core flow routes through `gameplay_base` instead of these fixtures.
- Controller `settings` are auto-duplicated (`resource_local_to_scene = true`). Assign shared `.tres` files freely—each controller keeps a unique copy.
- Interaction config schema resources live in `scripts/resources/interactions/` (`rs_*_interaction_config.gd`) with authored instances under `resources/interactions/**` (`cfg_*.tres`).
- Validate config resources with `scripts/gameplay/helpers/u_interaction_config_validator.gd` before binding them to controllers.
- Phase 5 config-binding pattern: interaction controllers are config-driven only. Legacy interaction export fallbacks (`door_id`, `checkpoint_id`, damage/victory/signpost literals, `required_area`) were removed; provide typed `config` resources in scenes/prefabs and treat those resources as the single source of truth.
- Phase 3 scene-authoring pattern: gameplay/prefab `Inter_*` nodes should bind `config = ExtResource("res://resources/interactions/.../cfg_*.tres")` and avoid duplicating door/checkpoint/hazard/victory/signpost literals directly in `.tscn` nodes.
- Passive volumes (`E_CheckpointZone`, `E_HazardZone`, `E_VictoryZone`) keep `ignore_initial_overlap = false` so respawns inside the volume re-register automatically. Triggered interactables (doors, signposts) leave it `true` to avoid instant re-activation.
- Use `visual_paths` to toggle meshes/lights/particles when controllers enable/disable; keep visuals as controller children instead of wiring extra logic nodes.
- Controllers run with `process_mode = PROCESS_MODE_ALWAYS` and will not activate while `scene.is_transitioning` or `M_SceneManager.is_transitioning()` is true.

### Character Lighting (Phase 1-5)

- Lighting resource scripts live under `scripts/resources/lighting/` with `rs_` prefixes.
- `RS_CharacterLightingProfile` is the base data contract; use `get_resolved_values()` for clamped runtime values (`tint`, `intensity`, `blend_smoothing`) instead of reading raw exports directly in blend code.
- `RS_CharacterLightZoneConfig` is the zone-side contract; use `get_resolved_values()` for clamped dimensions/weights and deep-copied `profile` snapshots.
- Blend calculations live in `scripts/utils/lighting/u_character_lighting_blend_math.gd` (`U_CharacterLightingBlendMath`):
  - Deterministic ordering: priority desc, weight desc, zone_id asc.
  - Weighted blending normalizes source weights.
  - Empty/invalid zone inputs fall back to a sanitized default profile.
- `Inter_CharacterLightZone` extends `BaseVolumeController` and remains config-driven:
  - Build runtime `RS_SceneTriggerSettings` from `RS_CharacterLightZoneConfig` in `_apply_config_to_volume_settings()`.
  - Use `resource_local_to_scene = true` for generated trigger settings.
  - Keep passive overlap behavior (`ignore_initial_overlap = false`) so spawn-inside zones still apply.
  - Auto-register/unregister with `character_lighting_manager` in `_ready()`/`_exit_tree()` so zones authored outside `Lighting` (goal/signpost/prefab hierarchies) are still consumed by the manager.
- Influence sampling contract for manager consumption:
  - `get_influence_weight(world_position)` returns shape-aware weight (box/cylinder) with falloff and transition gating.
  - `get_zone_metadata()` returns deterministic cache inputs (`zone_id`, `stable_key`, `priority`, `blend_weight`, deep-copied `profile` snapshot).
- Material application helper lives in `scripts/utils/lighting/u_character_lighting_material_applier.gd` (`U_CharacterLightingMaterialApplier`):
  - `collect_mesh_targets(entity)` recursively gathers `MeshInstance3D` nodes with valid mesh resources.
  - `apply_character_lighting(...)` swaps each target to `ShaderMaterial` using `assets/shaders/sh_character_zone_lighting.gdshader`, carries forward `albedo_texture`, and sets `base_tint`, `effective_tint`, `effective_intensity`.
  - Missing mesh/material/albedo texture is a deliberate no-op (skip target, do not cache).
  - Teardown contract: call `restore_character_materials(entity)` on entity cleanup and `restore_all_materials()` on broader scene teardown.
- `M_CharacterLightingManager` runtime pattern (Phase 4):
  - Discovers dependencies via injection-first + ServiceLocator fallback (`state_store`, `scene_manager`, `ecs_manager`).
  - Discovers active scene lighting data from `ActiveSceneContainer/<GameplayScene>/Lighting`.
  - Resolves scene defaults from `Lighting/CharacterLightingSettings.default_profile` when available, otherwise sanitized white/default fallback profile.
  - Listens for `scene/swapped` via `state_store.action_dispatched` and marks lighting caches dirty for next physics tick.
  - Discovers character targets from ECS tag query (`get_entities_by_tag("character")`) and restores materials for removed/non-3D entities.
  - Applies transition gating via Redux scene/navigation slices and `scene_manager.is_transitioning()`; blocked frames restore all character lighting overrides.
- Phase 8 stabilization pattern:
  - Boundary hysteresis is per character/per zone key with a deadband (`enter >= 0.02`, `exit < 0.01`) to reduce edge flicker.
  - Temporal smoothing uses blended `blend_smoothing` per character (`alpha = 1.0 - blend_smoothing`) for tint/intensity transitions.
  - Clear smoothing/hysteresis runtime state whenever lighting is blocked/disabled or scene bindings are refreshed so stale history does not bleed across transitions.
- Phase 5 scene-authoring pattern:
  - Every migrated gameplay scene should provide `Lighting/CharacterLightingSettings` with a `default_profile` (`RS_CharacterLightingProfile`) resource.
  - Author light zones as explicit `Inter_CharacterLightZone` nodes with scene/prefab `config = ExtResource("res://resources/lighting/zones/cfg_*.tres")`.
  - Keep authoring data split into reusable resources:
    - `resources/lighting/profiles/cfg_character_lighting_profile_*.tres`
    - `resources/lighting/zones/cfg_character_light_zone_*.tres`
  - Replace character-driving `OmniLight3D` nodes (mood/objective/signpost) only after equivalent zone config is present; preserve non-light visuals (`Visual`, `Sparkles`, meshes) for readability.

## Naming Conventions Quick Reference

**IMPORTANT**: All production scripts, scenes, and resources must follow documented prefix patterns. As of Phase 5 Complete (2025-12-08), 100% prefix compliance achieved - all files follow their respective prefix patterns. See `docs/general/STYLE_GUIDE.md` for the complete prefix matrix.

- **Base classes:** `base_*` prefix (e.g., `base_ecs_component.gd` → `BaseECSComponent`, `base_panel.gd` → `BasePanel`)
- **Utilities:** `u_*` prefix (e.g., `u_ecs_utils.gd` → `U_ECSUtils`, `u_entity_query.gd` → `U_EntityQuery`)
- **Managers:** `m_*` prefix (e.g., `m_ecs_manager.gd` → `M_ECSManager`, `m_state_store.gd` → `M_StateStore`)
- **Components:** `c_*` prefix (e.g., `c_movement_component.gd` → `C_MovementComponent`)
- **Systems:** `s_*` prefix (e.g., `s_gravity_system.gd` → `S_GravitySystem`)
- **Resources:** `rs_*` prefix (e.g., `rs_jump_settings.gd` → `RS_JumpSettings`)
- **Entities:** `e_*` prefix (e.g., `e_player.gd` → `E_Player`)
- **Interactable Controllers:** `inter_*` prefix (e.g., `inter_door_trigger.gd` → `Inter_DoorTrigger`)
- **UI Scripts:** `ui_*` prefix (e.g., `ui_main_menu.gd` → `UI_MainMenu`)
- **Marker Scripts:** `marker_*` prefix (e.g., `marker_entities_group.gd`, `marker_active_scene_container.gd`)
- **Transitions:** `trans_*` prefix (e.g., `trans_fade.gd` → `Trans_Fade`)
- **Interfaces:** `i_*` prefix (e.g., `i_scene_contract.gd` → `I_SCENE_CONTRACT`)
- **Prefabs:** `prefab_*` prefix for scenes (e.g., `prefab_death_zone.tscn`)

### Resource Instance and Asset Prefixes

Resource **instances** (`.tres` files) use `cfg_` prefix to distinguish from Resource **class definitions** (`.gd` files use `rs_`):
- `cfg_movement_default.tres` = instance of `RS_MovementSettings` class
- `cfg_jump_default.tres` = instance of `RS_JumpSettings` class
- `cfg_gameplay_base_entry.tres` = scene registry entry

Production asset files use type-specific prefixes:
- `tex_` = textures (e.g., `tex_shadow_blob.png`)
- `mus_` = music (e.g., `mus_main_menu.ogg`)
- `sfx_` = sound effects (e.g., `sfx_jump.wav`)
- `amb_` = ambient sounds (e.g., `amb_exterior.wav`)
- `fst_` = footsteps (e.g., `fst_grass_01.wav`)
- `icn_` = editor icons (e.g., `icn_component.svg`)
- `fnt_` = fonts (e.g., `fnt_ui_default.ttf`)

**Test assets:** Placeholder assets for testing live in `tests/assets/audio/` and `tests/assets/textures/` (moved from production `assets/` during cleanup v4.5).

### Helper Extraction Pattern (Large Files)

- When core scripts approach 400–500 lines, prefer extracting pure helpers instead of adding more responsibilities:
  - Scene management helpers: `scripts/scene_management/helpers/u_scene_registry_loader.gd`
  - Input helpers: `scripts/managers/helpers/u_input_profile_loader.gd`
  - ECS helpers: `scripts/utils/ecs/u_ecs_query_metrics.gd`
  - UI helpers/builders: `scripts/ui/helpers/u_rebind_action_list_builder.gd`, `scripts/ui/helpers/u_touchscreen_preview_builder.gd`
- Helper scripts:
  - Live under a `helpers/` subdirectory next to their parent domain.
  - Use existing prefixes (`u_` for utilities/loaders) plus a descriptive suffix (e.g., `_loader`, `_builder`, `_metrics`).
  - Expose small, focused APIs that keep managers/systems under ~400 lines while preserving behavior.

## Conventions and Gotchas

- **Groups are NOT used**
  - This codebase does NOT use Godot's groups feature for manager discovery or node organization
  - Use `U_ServiceLocator` for all manager lookups instead of `get_tree().get_first_node_in_group()`
  - Groups add hidden coupling that's hard to track; ServiceLocator provides explicit registration with O(1) lookup
- GDScript typing
  - Annotate locals receiving Variants (e.g., from `Callable.call()`, `JSON.parse_string`, `Time.get_ticks_msec()` calc). Prefer explicit `: float`, `: int`, `: Dictionary`, etc.
  - Use `StringName` for action/component identifiers; keep constants like `const MOVEMENT_TYPE := StringName("C_MovementComponent")`.
- Time helpers
  - For ECS timing, call `U_ECSUtils.get_current_time()` (seconds) instead of repeating `Time.get_ticks_msec() / 1000.0`.
- Copy semantics
  - Use `.duplicate(true)` for deep copies of `Dictionary`/`Array` before mutating; the codebase relies on immutability patterns both in ECS snapshots and state.
- Scenes and NodePaths
- Wire `@export` NodePaths in scenes; missing paths intentionally short-circuit behavior in systems. See `scenes/templates/tmpl_character.tscn` + `scenes/prefabs/prefab_player.tscn` for patterns.
- Resources
  - New exported fields in `*Settings.gd` require updating default `.tres` under `resources/base_settings/` and any scene using them.
  - Trigger settings automatically clamp `player_mask` to at least layer 1; configure the desired mask on the resource instead of zeroing it at runtime.
- Tabs and warnings
  - Keep tab indentation in `.gd` files; tests use native method stubs on engine classes—suppress with `@warning_ignore("native_method_override")` where applicable (details in `docs/general/developer_pitfalls.md`).
- State store batching and input persistence
  - `M_StateStore` emits `slice_updated` once per physics frame; do not also flush on idle frames.
  - Actions that need same-frame visibility (e.g., input rebinds) must set `"immediate": true` on the dispatched payload; the store now flushes batched slice updates immediately for these actions.
  - Gameplay input fields are transient across scene transitions (StateHandoff) but are persisted to disk on save/load.
  - Global settings persist via `user://global_settings.json` (display/audio/vfx/input + gameplay preferences). Controlled by `RS_StateStoreSettings.enable_global_settings_persistence`; legacy `audio_settings.json`/`input_settings.json` migrate on load.
  - In non-persistence tests, set `store.settings.enable_persistence = false` before adding `M_StateStore` to the tree to avoid ambient `user://savegame.json` autoload side effects.
- State load normalization
  - `M_StateStore.load_state()` sanitizes unknown `current_scene_id`, `target_spawn_point`, and `last_checkpoint` values, falling back to `gameplay_base` / `sp_default` and deduping `completed_areas`.
- Style enforcement
  - `tests/unit/style/test_style_enforcement.gd` fails on leading spaces in gameplay/state/ui scripts and verifies trigger resources include `script = ExtResource(...)`.
- InputMap
  - The `interact` action must remain in `project.godot`; HUD/process prompts run in `PROCESS_MODE_ALWAYS` to stay responsive when the tree is paused.
  - Device detection is centralized in `M_InputDeviceManager`; gameplay systems read `U_InputSelectors.get_active_device_type()` / `get_active_gamepad_id()` instead of dispatching their own `device_changed` actions.
  - Rebinding flows must dispatch via Redux (`U_InputActions.rebind_action`)—`M_InputProfileManager` now derives InputMap state from the store, so avoid mutating InputMap directly in UI code.
  - `S_InputSystem` only gates input on cursor capture for desktop platforms; on mobile (`OS.has_feature("mobile")`), do not depend on `Input.mouse_mode` for gamepad routing so Bluetooth controllers remain functional when MobileControls hides the touchscreen UI.
- Input Source Abstraction (Phase 10B-4 - Device Polymorphism)
  - **Centralized device types**: `U_DeviceTypeConstants.DeviceType` enum (KEYBOARD_MOUSE, GAMEPAD, TOUCHSCREEN) replaces local enums
  - **IInputSource interface**: All input devices implement `get_device_type()`, `get_priority()`, `is_active()`, `capture_input()`
  - **Source implementations**:
    - `KeyboardMouseSource`: Priority 1, captures keyboard vector + mouse delta
    - `GamepadSource`: Priority 2, handles stick deadzones + button states
    - `TouchscreenSource`: Priority 3, delegates to MobileControls virtual input
  - **M_InputDeviceManager**: Registers sources at startup, delegates input events to appropriate source
  - **S_InputSystem**: Queries active source from manager, delegates `capture_input()` call, writes to components
  - **Adding new devices (e.g., VR)**: Create new source class extending `I_InputSource`, register in `M_InputDeviceManager._register_input_sources()`
  - **Pattern**:
    ```gdscript
    # In M_InputDeviceManager
    var source := _input_device_manager.get_input_source_for_device(active_device_type)
    var input_data := source.capture_input(delta)  # {move_input, look_input, jump_pressed, etc.}
    ```
- Button Prompt Patterns (Phase 1 - Generic Glyphs)
  - **Registry handles texture loading**: `U_ButtonPromptRegistry.get_prompt(action, device_type)` returns cached Texture2D for registered actions
  - **Automatic fallback**: When texture unavailable, ButtonPrompt falls back to text label
  - **Texture priority**: Show texture if available, otherwise show text binding label
  - **Caching**: Textures loaded once and cached in registry for performance
  - **Device switching**: ButtonPrompt automatically updates texture when device changes
  - **Texture display**: TextureRect with 32x32 minimum size, aspect ratio preserved (STRETCH_KEEP_ASPECT_CENTERED)
  - **Usage**:
    ```gdscript
    button_prompt.show_prompt(StringName("interact"), "Open Door")
    # Shows texture for current device, falls back to text if unavailable
    ```
  - **Note**: Textures are mapped to actions, not specific key bindings. When user rebinds an action, the texture remains the same (shows action's registered glyph, not the new key).

## Scene Manager Patterns (Phase 10 Complete)

### Scene Registration

- **Register all scenes**: Add scenes to `U_SceneRegistry._register_all_scenes()` before using them

  ```gdscript
  _register_scene(
    StringName("my_scene"),
    "res://scenes/gameplay/my_scene.tscn",
    SceneType.GAMEPLAY,
    "fade",  # default transition
    5        # preload priority (0-10)
  )
  ```

- **Preload priority guidelines**:
  - `10`: Critical UI (main_menu, pause_menu) - preloaded at startup
  - `5-7`: Frequently accessed scenes
  - `0-4`: Occasional access
  - `0`: No preload (loaded on-demand)

### Scene Transitions

- **Get scene manager**: `U_ServiceLocator.get_service(StringName("scene_manager")) as M_SceneManager`
- **Basic transition**: `scene_manager.transition_to_scene(StringName("scene_id"))`
- **Override transition type**: `scene_manager.transition_to_scene(StringName("scene_id"), "fade")`
- **Priority transitions**: `scene_manager.transition_to_scene(StringName("game_over"), "fade", M_SceneManager.Priority.CRITICAL)`
- **Transition types**:
  - `"instant"`: < 100ms, no visual effect (UI navigation)
  - `"fade"`: 0.2-0.5s, fade out → load → fade in (polished)
  - `"loading"`: 1.5s+, loading screen with progress bar (large scenes)
- **Priority levels**:
  - `NORMAL = 0`: Standard navigation
  - `HIGH = 1`: Important but not urgent
  - `CRITICAL = 2`: Death, game over (jumps to front of queue)

### Overlay Management (Pause/Menus)

- **Push overlay**: `scene_manager.push_overlay(StringName("pause_menu"))` - adds to stack, pauses tree
- **Pop overlay**: `scene_manager.pop_overlay()` - removes top overlay, resumes if empty
- **Return stack**: `push_overlay_with_return(StringName("settings_menu"))` - remember previous overlay
- **Auto-restore**: `pop_overlay_with_return()` - return to previous overlay automatically
- **Navigation**: `go_back()` - navigate back through UI history (UI scenes only, skips gameplay)

### Scene Triggers (Doors)

- **Component setup**: Add `C_SceneTriggerComponent` to door entities with Area3D collision
- **Required properties**:
  - `door_id`: Unique identifier (e.g., `"door_to_house"`)
  - `target_scene_id`: Destination scene (e.g., `"interior_house"`)
  - `target_spawn_point`: Spawn marker name (e.g., `"sp_entrance_from_exterior"`)
- **Trigger modes**:
  - `AUTO`: Triggers on collision (walk through)
  - `INTERACT`: Requires input action (press 'E')
- **Duplicate request protection**: Components check transition state and use cooldown/pending flags to prevent duplicate requests
- **Input blocking during transitions**: Transition effects temporarily block input to prevent accidental re-triggers; restore input on completion
- **Trigger shape configuration**: Use shape resources (Box or Cylinder). Avoid non-uniform scaling of nodes; adjust shape dimensions on the resource instead. Use `local_offset` to align triggers with visual geometry
- **Cooldown**: Set `cooldown_duration` (1-2 seconds) to prevent spam
- **Door pairings**: Register bidirectional doors in `U_SceneRegistry._register_door_pairings()`

  ```gdscript
  _register_door_pair(
    StringName("exterior"), StringName("door_to_house"),
    StringName("interior_house"), StringName("door_to_exterior")
  )
  ```

### Spawn Point Management

- **Naming convention**: `sp_` prefix + descriptive name (e.g., `sp_entrance_from_exterior`)
- **Container**: Place under `Entities/SpawnPoints` (Node3D) in gameplay scenes
- **Default spawn**: Name one marker `sp_default` for initial scene load
- **Position**: Place spawn markers 2-3 units OUTSIDE trigger zones (prevents ping-pong)
- **Automatic restoration**: M_SpawnManager applies spawn on scene load using:
  - Priority: `target_spawn_point` → `last_checkpoint` → `sp_default`
  - Fallback: If a `last_checkpoint` from a different scene is invalid, fall back to `sp_default` automatically

### State Persistence

- **Automatic persistence**: `gameplay` slice persists across transitions via `StateHandoff`
- **Use action creators**: Modify state via `U_GameplayActions` (never set fields directly)

  ```gdscript
  const U_GameplayActions = preload("res://scripts/state/actions/u_gameplay_actions.gd")
  store.dispatch(U_GameplayActions.take_damage(player_id, 25.0))
  store.dispatch(U_GameplayActions.mark_area_complete("interior_house"))
  ```

- **Read state safely**: Use `U_StateUtils.get_store(self)` with `await` in `_ready()`

  ```gdscript
  await get_tree().process_frame
  var store := U_StateUtils.get_store(self)
  var state: Dictionary = store.get_state()
  ```

- **Transient fields**: Excluded from saves (e.g., `is_transitioning`, `transition_type`)
- **Save/load**: `store.save_state("user://savegame.json")` / `store.load_state("user://savegame.json")`

### Camera Blending

- **Automatic blending**: Gameplay → Gameplay transitions blend camera position, rotation, FOV
- **Requirements**: Both scenes must have a Camera3D discoverable by `M_CameraManager` (or registered via `register_main_camera()`)
- **Transition type**: Only works with `"fade"` transitions (not instant/loading)
- **Scene-specific setup**: Configure camera per-scene (e.g., exterior: FOV 80°, interior: FOV 65°)
- **Implementation**: Uses transition camera + Tween (0.2s, TRANS_CUBIC, EASE_IN_OUT)

### Scene Preloading & Performance

- **Critical scene preload**: Scenes with `preload_priority >= 10` load at startup
- **Scene cache**: LRU cache with 5 scene limit + 100MB memory cap
- **Preload hints**: Call `hint_preload_scene(StringName("scene_id"))` when player approaches door
- **Automatic hints**: `C_SceneTriggerComponent` auto-hints target scene on player proximity
- **Async loading**: Gameplay scenes load asynchronously with real progress tracking
- **Performance targets**:
  - UI transitions: < 0.5s (cached scenes are instant)
  - Gameplay transitions: < 3s (async with loading screen)
  - Large scenes: < 5s (loading screen with progress bar)

## UI Manager Patterns

### Navigation State

- **Navigation slice**: Dedicated Redux slice managing UI location (`shell`, `overlay_stack`, `active_menu_panel`)
- **Shells**: `main_menu`, `gameplay`, `endgame`
- **Overlays**: Modal dialogs stacked on gameplay via `overlay_stack` array
- **Panels**: Embedded UI within shells (e.g., `menu/main`, `menu/settings`)

### Using Navigation Actions

```gdscript
const U_NavigationActions = preload("res://scripts/state/actions/u_navigation_actions.gd")

# Open pause overlay
store.dispatch(U_NavigationActions.open_pause())

# Open nested overlay
store.dispatch(U_NavigationActions.open_overlay(StringName("settings_menu_overlay")))

# Close top overlay (CloseMode determines behavior)
store.dispatch(U_NavigationActions.close_top_overlay())

# Switch menu panels
store.dispatch(U_NavigationActions.set_menu_panel(StringName("menu/settings")))
```

### UI Registry

- **Resource-based**: All screens defined in `resources/ui_screens/cfg_*.tres`
- **Screen definition**: `RS_UIScreenDefinition` with `screen_id`, `kind`, `scene_id`, `allowed_shells`, `close_mode`
- **Validation**: Registry validates parent-child relationships and scene references

### Base UI Classes

- **BasePanel**: Auto-store lookup, focus management, back button handling
- **BaseMenuScreen**: For full-screen UIs (main menu, endgame)
- **BaseOverlay**: For modal dialogs, sets `PROCESS_MODE_ALWAYS`, manages background dimming

### Common Patterns

- UI controllers extend base classes and dispatch actions (never call Scene Manager directly)
- Subscribe to `slice_updated` for reactive updates
- Use `U_NavigationSelectors.is_paused()` for pause state (single source of truth)
- Await store ready: `await get_tree().process_frame` before accessing store in `_ready()`

### Unified Settings Panel Patterns

**Architecture**:
- `SettingsPanel` extends `BaseMenuScreen` (gets analog stick repeater)
- Tab content panels extend plain `Control` (NO nested repeaters)
- Use `ButtonGroup` for tab radio behavior (automatic mutual exclusivity)
- Auto-save pattern: dispatch Redux actions immediately (no Apply/Cancel buttons)

**Base Class Hierarchy**:
```
BasePanel (store + focus helpers)
└─ BaseMenuScreen (+ U_AnalogStickRepeater)
    ├─ SettingsPanel ← extends this
    └─ BaseOverlay (+ PROCESS_MODE_ALWAYS)

Tab panels (gamepad_tab, touchscreen_tab, etc.)
└─ Control ← extends this (NOT BaseMenuScreen!)
```

**ButtonGroup Setup**:
```gdscript
# In settings_panel.gd:
var _tab_button_group := ButtonGroup.new()
func _ready():
    input_profiles_button.toggle_mode = true
    input_profiles_button.button_group = _tab_button_group
    gamepad_button.toggle_mode = true
    gamepad_button.button_group = _tab_button_group
    # ButtonGroup automatically handles button_pressed states
    _tab_button_group.pressed.connect(_on_tab_button_pressed)
```

**Focus Management Rules**:
1. **Tab switch**: Transfer focus to first control in new tab
   ```gdscript
   await get_tree().process_frame  # Let visibility settle
   var first_focusable := _get_first_focusable_in_active_tab()
   if first_focusable:
       first_focusable.grab_focus()
   ```

2. **Device switch**: If active tab becomes hidden, switch tab AND re-focus
   ```gdscript
   _update_tab_visibility()
   if not _is_active_tab_visible():
       _switch_to_first_visible_tab()
       await get_tree().process_frame
       _focus_first_control_in_active_tab()  # Critical!
   ```

3. **Tab content**: Use `U_FocusConfigurator` for focus chains, not custom `_navigate_focus()`
   ```gdscript
   # In gamepad_tab.gd:
   func _configure_focus_neighbors():
       var controls: Array[Control] = [left_slider, right_slider, checkbox]
       U_FocusConfigurator.configure_vertical_focus(controls, false)
   ```

**Auto-Save Pattern**:
```gdscript
# ✅ CORRECT - immediate dispatch
func _on_left_deadzone_changed(value: float):
    store.dispatch(U_InputActions.update_gamepad_setting("left_stick_deadzone", value))

# ❌ WRONG - batching with Apply button
var _pending_changes: Dictionary = {}
func _on_slider_changed(value: float):
    _pending_changes["deadzone"] = value
func _on_apply_pressed():
    store.dispatch(...)
```

**Input Actions for Tab Switching**:
- Add `ui_focus_prev` (L1/LB, Page Up) and `ui_focus_next` (R1/RB, Page Down) to `project.godot`
- Shoulder buttons cycle tabs, focus transfers automatically

**Anti-Patterns**:
- ❌ Tab panels extending `BaseMenuScreen` (creates nested repeater conflict)
- ❌ Manual button state management (use `ButtonGroup` instead)
- ❌ Apply/Cancel buttons (use auto-save pattern)
- ❌ Tab content overriding `_navigate_focus()` (conflicts with parent repeater)

## Save Manager Patterns (Phase 13 Complete)

### Overview

M_SaveManager orchestrates save/load operations with atomic writes, migrations, and autosave scheduling. It does NOT define gameplay data—M_StateStore remains the single source of truth for serializable state.

### Slot System

- **1 autosave slot**: `SLOT_AUTOSAVE` (overwritten by autosave events, cannot be deleted)
- **3 manual slots**: `SLOT_01`, `SLOT_02`, `SLOT_03` (user-created via pause menu)
- **File location**: `user://saves/` (configurable for testing via `set_save_directory()`)
- **File format**: `{header: {...}, state: {...}}` with version, timestamp, playtime, scene context

### Save Operations

```gdscript
const M_SAVE_MANAGER := preload("res://scripts/managers/m_save_manager.gd")

# Get manager (discoverable via ServiceLocator)
var save_manager := U_ServiceLocator.get_service(StringName("save_manager")) as M_SaveManager

# Manual save to slot
save_manager.save_to_slot(StringName("slot_01"))  # Returns Error code

# Check slot existence
if save_manager.slot_exists(StringName("slot_01")):
    # Slot has valid save file

# Get metadata for UI display
var metadata: Dictionary = save_manager.get_slot_metadata(StringName("slot_01"))
# Returns: {save_version, timestamp, build_id, playtime_seconds, current_scene_id,
#           last_checkpoint, target_spawn_point, area_name, slot_id, thumbnail_path}

# Get all slot metadata
var all_metadata: Array[Dictionary] = save_manager.get_all_slot_metadata()
```

### Load Operations

```gdscript
# Load from slot (applies state + transitions to saved scene)
save_manager.load_from_slot(StringName("slot_01"))  # Returns Error code

# Load workflow:
# 1. Reads save file with .bak fallback on corruption
# 2. Applies migrations (v0 → v1, etc.)
# 3. Validates structure (header, state, current_scene_id)
# 4. Applies loaded state to M_StateStore via apply_loaded_state()
# 5. Transitions to saved scene_id via M_SceneManager (loading screen)
# 6. Clears loading lock when transition completes
```

### Delete Operations

```gdscript
# Delete manual slot (autosave cannot be deleted)
save_manager.delete_slot(StringName("slot_01"))  # Returns ERR_UNAUTHORIZED for autosave
```

### Autosave Triggers

Autosaves trigger on **milestones** (low-frequency, meaningful events):

- **Checkpoint activated**: `checkpoint_activated` ECS event
- **Area completed**: `gameplay/mark_area_complete` Redux action
- **Scene transition completed**: `scene/transition_completed` Redux action

**Blocking conditions** (autosave suppressed):
- `gameplay.death_in_progress == true` (no autosave during death)
- `scene.is_transitioning == true` (no autosave during transitions)
- `navigation.shell != "gameplay"` (only autosave during gameplay, not in menus)
- Save/load operations in progress (`M_SaveManager.is_locked()`)

**Cooldown/Priority**:
- NORMAL priority: 5s cooldown (checkpoint, scene transition)
- HIGH priority: 2s cooldown (area completion)
- CRITICAL priority: always trigger (reserved for future use)

### Autosave Scheduler (Internal)

U_AutosaveScheduler (helper, child of M_SaveManager):
- Subscribes to ECS events (`checkpoint_activated`) via `U_ECSEventBus`
- Subscribes to Redux actions via `M_StateStore.action_dispatched` signal
- Coalesces multiple requests within same frame (dirty flag pattern)
- Enforces blocking conditions and cooldowns
- Calls `M_SaveManager.request_autosave(priority)` when allowed

### Playtime Tracking

S_PlaytimeSystem (ECS system):
- Tracks `gameplay.playtime_seconds` (increments every second during gameplay)
- Pauses when: `navigation.shell != "gameplay"`, paused, or transitioning
- Dispatches `U_GameplayActions.increment_playtime(seconds)` periodically
- Playtime persists across scene transitions and saves/loads

### File I/O Patterns

**Atomic writes** (crash-safe):
```
1. Write to {slot}.json.tmp
2. Backup existing {slot}.json to {slot}.json.bak
3. Rename {slot}.json.tmp to {slot}.json
```

**Corruption recovery**:
```
Load order: {slot}.json → {slot}.json.bak (if .json missing/corrupted) → empty dict
```

**Orphaned .tmp cleanup**: On startup, remove all `.tmp` files from save directory

### Migration System

U_SaveMigrationEngine (helper):
- Pure `Dictionary → Dictionary` transforms (no side effects)
- Version detection from `header.save_version` (missing header = v0)
- Sequential migration chain: `v0 → v1 → v2 → ...`
- **v0 → v1 migration**: Wraps headerless saves in `{header, state}` structure

**Legacy save import**:
- On first launch, imports `user://savegame.json` (old format) to autosave slot
- Applies v0 → v1 migration automatically
- Deletes original `user://savegame.json` after successful import

### Validation & Error Handling

U_SaveValidator (utility):
- Validates save file structure (header, state must be Dictionaries)
- Validates required fields (`current_scene_id` must exist and be non-empty)
- Returns detailed error messages with context (field name, expected/actual type)

**Error codes**:
- `OK`: Success
- `ERR_BUSY`: Save/load already in progress
- `ERR_INVALID_PARAMETER`: Invalid slot_id
- `ERR_FILE_NOT_FOUND`: Slot doesn't exist
- `ERR_FILE_CORRUPT`: Invalid/corrupted save file
- `ERR_UNAUTHORIZED`: Attempted to delete autosave slot
- `ERR_UNAVAILABLE`: Scene manager unavailable for load transition

### UI Integration

**Pause menu buttons** (`ui_pause_menu.gd`):
```gdscript
const U_NAVIGATION_ACTIONS := preload("res://scripts/state/actions/u_navigation_actions.gd")

# Save button pressed
func _on_save_pressed():
    store.dispatch(U_NavigationActions.set_save_load_mode(StringName("save")))
    store.dispatch(U_NavigationActions.open_overlay(StringName("save_load_menu_overlay")))

# Load button pressed
func _on_load_pressed():
    store.dispatch(U_NavigationActions.set_save_load_mode(StringName("load")))
    store.dispatch(U_NavigationActions.open_overlay(StringName("save_load_menu_overlay")))
```

**Save/Load overlay** (`ui_save_load_menu.gd`):
- Extends `BaseOverlay` (PROCESS_MODE_ALWAYS, background dimming)
- Reads mode from `navigation.save_load_mode` on `_ready()`
- Populates slot list from `M_SaveManager.get_all_slot_metadata()`
- Shows overwrite confirmation dialog before saving to occupied slot
- Shows inline spinner + disables buttons during load operation
- Subscribes to save events (`save_started`, `save_completed`, `save_failed`) for UI refresh

**Toast notifications** (`ui_hud_controller.gd`):
- Subscribes to `U_ECSEventBus` save events
- Shows toasts for autosaves ONLY (manual saves use inline UI feedback)
- Suppressed during pause (toasts only appear during gameplay)
- "Saving..." on `save_started`, "Game Saved" on `save_completed`, "Save Failed" on `save_failed`

### Testing Patterns

**Integration tests** (`tests/integration/save_manager/test_save_load_cycle.gd`):
- Use `M_SaveManager.set_save_directory("user://test_saves/")` BEFORE adding to tree
- Create real `M_StateStore` with initial state resources (not mock)
- Set `navigation.shell = "gameplay"` to allow autosave triggers
- Use empty string for player damage: `U_GameplayActions.take_damage("", amount)`
- Wait for physics frame after dispatching actions to flush state updates

**Unit tests** (Phase 0-8):
- 94 unit tests covering manager lifecycle, slot registry, file I/O, migrations, validation
- Use `MockStateStore` and `MockSceneManager` from `tests/mocks/`
- Test directory helpers in `u_save_test_utils.gd` (setup/teardown)

### Anti-Patterns

- ❌ Calling `M_StateStore.save_state(filepath)` directly (bypasses save manager, no header/migrations)
- ❌ Triggering autosave on high-frequency events (position updates, damage ticks)
- ❌ Autosaving during death (`death_in_progress == true`)
- ❌ Autosaving during scene transitions (`is_transitioning == true`)
- ❌ Modifying state during load (let StateHandoff handle restoration)
- ❌ Attempting to delete autosave slot (returns `ERR_UNAUTHORIZED`)

## Audio Manager Patterns (Phase 10 Complete)

### Registry & Data Architecture

- **Resource-driven definitions**: All audio assets defined as resources, not hard-coded dictionaries
  - `RS_MusicTrackDefinition`: Music tracks with fade duration, volume, loop, pause behavior
  - `RS_AmbientTrackDefinition`: Ambient tracks with fade duration, volume, loop
  - `RS_UISoundDefinition`: UI sounds with volume, pitch variation, throttle_ms
  - `RS_SceneAudioMapping`: Maps scenes to music/ambient tracks
- **Registry loader**: `U_AudioRegistryLoader.initialize()` populates O(1) lookup dictionaries
  - `get_music_track(track_id)` → RS_MusicTrackDefinition or null
  - `get_ambient_track(ambient_id)` → RS_AmbientTrackDefinition or null
  - `get_ui_sound(sound_id)` → RS_UISoundDefinition or null
  - `get_audio_for_scene(scene_id)` → RS_SceneAudioMapping or null
- **Registration pattern**:
  ```gdscript
  # In U_AudioRegistryLoader._register_music_tracks()
  var track := preload("res://resources/audio/tracks/music_main_menu.tres")
  _music_tracks[track.track_id] = track
  ```

### Crossfade Patterns

- **U_CrossfadePlayer**: Reusable dual-player crossfader for music and ambient
  - **Initialization**: `var crossfader := U_CrossfadePlayer.new(owner_node, &"Music")`
  - **Crossfade**: `crossfader.crossfade_to(stream, track_id, duration, start_position)`
    - Swaps active/inactive players
    - Starts new player at -80dB, fades to 0dB
    - Fades old player out to -80dB
    - Uses parallel Tween (TRANS_CUBIC, EASE_IN_OUT)
  - **Stop**: `crossfader.stop(duration)` - fades active player out
  - **Pause/Resume**: `crossfader.pause()` / `crossfader.resume()` - stores/restores playback position
  - **Query**: `crossfader.get_current_track_id()`, `crossfader.is_playing()`
  - **Cleanup**: `crossfader.cleanup()` - frees both players
- **Usage in M_AudioManager**:
  ```gdscript
  _music_crossfader = U_CrossfadePlayer.new(self, &"Music")
  _ambient_crossfader = U_CrossfadePlayer.new(self, &"Ambient")
  ```

### Bus Layout & Validation

- **Editor-defined buses**: Bus layout defined in `default_bus_layout.tres`, not created at runtime
  - Master (0) → Music (1), SFX (2) → UI (3), Footsteps (4), Ambient (5)
- **Constants**: `U_AudioBusConstants` defines bus names and validation
  - `BUS_MASTER`, `BUS_MUSIC`, `BUS_SFX`, `BUS_UI`, `BUS_FOOTSTEPS`, `BUS_AMBIENT`
  - `REQUIRED_BUSES` array for validation
- **Validation**: Non-destructive validation at startup
  ```gdscript
  if not U_AudioBusConstants.validate_bus_layout():
      push_error("Audio bus layout invalid - check default_bus_layout.tres")
  ```
- **Safe bus access**: `U_AudioBusConstants.get_bus_index_safe(bus_name)` returns Master (0) on failure

### SFX Spawner Patterns

- **Dictionary-based API**: `U_SFXSpawner.spawn_3d(config: Dictionary)` for flexible configuration
  ```gdscript
  U_SFXSpawner.spawn_3d({
      "stream": audio_stream,
      "position": global_position,
      "volume_db": -6.0,
      "pitch_scale": 1.2,
      "bus": "SFX",
      "max_distance": 100.0,
      "attenuation_model": AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE,
      "follow_target": entity_node  # Optional: player follows entity
  })
  ```
- **Voice stealing**: Automatically steals oldest playing sound when pool exhausted (>16 sounds)
  - Tracks play times in `_play_times` dictionary
  - `_steal_oldest_voice()` finds and stops oldest player
  - Stats tracking: `U_SFXSpawner.get_stats()` returns `{spawns, steals, drops, peak_usage}`
- **Bus fallback**: `_validate_bus(bus)` returns "SFX" if bus not found, warns on invalid bus
- **Per-sound spatialization**: Override max_distance and attenuation_model per-sound
  - Respects `_spatial_audio_enabled` flag (disables attenuation/panning when false)
- **Follow-emitter mode**: Sound follows moving entity via `follow_target` config
  - `update_follow_targets()` called each frame to sync positions
  - Automatic cleanup when entity freed or playback stops
- **Stats & metrics**: `reset_stats()` clears counters, `_update_peak_usage()` tracks max concurrent

### ECS Sound Systems Patterns

- **Request-driven architecture**: Systems extend `BaseEventSFXSystem`, subscribe to ECS events
  - Implement `get_event_name()` → StringName (e.g., `"entity_jumped"`)
  - Implement `create_request_from_payload(payload)` → Dictionary `{position: Vector3, entity_id: StringName}`
  - Implement `_get_audio_stream()` → AudioStream (from settings resource)
- **Standard request schema**:
  ```gdscript
  {
      "position": Vector3,  # Required - extracted via _extract_position()
      "entity_id": StringName  # Optional - for debugging
  }
  ```
- **Shared helpers in BaseEventSFXSystem**:
  - `_should_skip_processing()` → checks settings enabled, stream exists
  - `_is_audio_blocked()` → pause/transition/shell gating (returns true if audio should not play)
  - `_is_throttled(min_interval, now)` → enforces minimum time between plays
  - `_calculate_pitch(pitch_variation)` → clamps variation to 0.0-0.95, returns randomized pitch
  - `_extract_position(request)` → safely extracts position from request Dictionary
  - `_spawn_sfx(stream, position, volume_db, pitch_scale, bus)` → delegates to U_SFXSpawner.spawn_3d()
- **Pause/transition gating**: All sound systems check before playing
  ```gdscript
  func process_tick(delta: float) -> void:
      if _is_audio_blocked():  # Checks pause, transition, shell != "gameplay"
          requests.clear()
          return
  ```
- **State store injection**: Systems support `@export var state_store: I_StateStore` for testing
  - `_is_audio_blocked()` tries injected store first, falls back to `U_StateUtils.try_get_store()`
- **Position resolution**: Resolve entity positions at event **publish time**, not in sound systems
  - ✅ Include position in event payload: `U_ECSEventBus.publish("entity_jumped", {position: global_position})`
  - ❌ Avoid O(n) lookups in sound systems: `get_entity_by_id()`, `find_child()`

### UI Sound Patterns

- **U_UISoundPlayer**: Lightweight helper wrapping M_AudioManager UI sound playback
  ```gdscript
  U_UISoundPlayer.play_focus()    # UI navigation focus
  U_UISoundPlayer.play_confirm()  # UI confirm/select
  U_UISoundPlayer.play_cancel()   # UI cancel/back
  U_UISoundPlayer.play_slider_tick()  # Slider value change
  ```
- **Per-sound throttling**: `RS_UISoundDefinition.throttle_ms` prevents rapid repeated plays
  - `throttle_ms = 100` → blocks plays within 100ms window
  - `throttle_ms = 0` → no throttle, all plays allowed
  - Tracked per sound_id in `_last_play_times` dictionary
- **Polyphony**: M_AudioManager uses 4 round-robin players for overlapping UI sounds
  - `UI_SOUND_POLYPHONY = 4` → up to 4 simultaneous UI sounds
  - `_ui_sound_index` cycles through players (0-3)
- **Usage in UI controllers**:
  ```gdscript
  func _on_button_focus_entered() -> void:
      U_UISoundPlayer.play_focus()

  func _on_confirm_pressed() -> void:
      U_UISoundPlayer.play_confirm()
  ```

### State-Driven Audio Settings

- **Hash-based optimization**: M_AudioManager only applies settings when audio slice changes
  ```gdscript
  var audio_slice: Dictionary = state.get("audio", {})
  var audio_hash := audio_slice.hash()
  if audio_hash != _last_audio_hash:
      _apply_audio_settings(state)
      _last_audio_hash = audio_hash
  ```
- **Settings preview mode**: Temporary overrides via `set_audio_settings_preview(preview_dict)`
  - Used by UI_VFXSettingsOverlay for real-time previews
  - `clear_audio_settings_preview()` restores persisted settings
  - `_audio_settings_preview_active` flag prevents hash updates during preview
- **Audio persistence**: Audio settings auto-save to disk when changed
  - `_schedule_audio_save()` debounces writes (500ms delay)
  - Only actions with `action_type.begins_with("audio/")` trigger save

### Scene-Based Audio Transitions

- **Automatic music/ambient**: M_AudioManager subscribes to `scene/transition_completed` action
  ```gdscript
  func _change_audio_for_scene(scene_id: StringName) -> void:
      var mapping := U_AudioRegistryLoader.get_audio_for_scene(scene_id)
      if mapping.music_track_id != StringName(""):
          play_music(mapping.music_track_id, 2.0)  # 2s crossfade
      if mapping.ambient_track_id != StringName(""):
          play_ambient(mapping.ambient_track_id, 2.0)
  ```
- **Pause music handling**: ACTION_OPEN_PAUSE → play "pause" track, ACTION_CLOSE_PAUSE → restore pre-pause track
  - Stores `_pre_pause_music_id` and `_pre_pause_music_position` for restoration
- **Cross-scene persistence**: Music and ambient managed by M_AudioManager (persistent), not per-scene systems

### Common Patterns

- **Access audio manager**: `U_AudioUtils.get_audio_manager()` (ServiceLocator lookup)
- **Play music**: `audio_mgr.play_music(StringName("main_menu"), 1.5)` - 1.5s crossfade
- **Play ambient**: `audio_mgr.play_ambient(StringName("exterior"), 2.0)` - 2s crossfade
- **Play UI sound**: `audio_mgr.play_ui_sound(StringName("ui_confirm"))` - round-robin polyphony
- **Spawn 3D SFX**: `U_SFXSpawner.spawn_3d({stream: sfx, position: pos, bus: "SFX"})`

### Anti-Patterns

- ❌ Hard-coding audio streams in scripts (use resource definitions instead)
- ❌ Creating bus layout at runtime (define in default_bus_layout.tres)
- ❌ O(n) entity lookups in sound systems (include position in event payload)
- ❌ Playing audio during pause/transitions (use `_is_audio_blocked()` gating)
- ❌ Spawning >16 simultaneous SFX without voice stealing (pool will exhaust)
- ❌ Bypassing throttle_ms for rapid UI sounds (causes audio spam)

## Display Manager Patterns (Phase 11 Complete)

### Overview

M_DisplayManager handles window settings, post-processing effects, UI scaling, and accessibility features. It follows the same hash-based optimization and preview mode patterns as M_AudioManager.

### Hash-Based Change Detection

Same pattern as audio manager - only applies settings when display slice hash changes:

```gdscript
var _last_display_hash: int = 0
var _display_settings_preview_active: bool = false

func _on_slice_updated(slice_name: StringName, _slice_data: Dictionary) -> void:
    if slice_name != &"display" or _display_settings_preview_active:
        return
    var state := state_store.get_state()
    var display_slice: Dictionary = state.get("display", {})
    var display_hash := display_slice.hash()
    if display_hash != _last_display_hash:
        _apply_display_settings(state)
        _last_display_hash = display_hash
```

### Preview Mode

Temporary overrides for settings UI (real-time preview without persisting):

```gdscript
# Push preview
display_manager.set_display_settings_preview({
    "film_grain_enabled": true,
    "film_grain_intensity": 0.3
})

# Clear preview (restores persisted state)
display_manager.clear_display_settings_preview()
```

### ServiceLocator Registration

Access display manager via ServiceLocator:

```gdscript
var display_manager := U_ServiceLocator.get_service(StringName("display_manager")) as I_DisplayManager
# Or use helper
var display_manager := U_DisplayUtils.get_display_manager()
```

### Post-Process Overlay (Layer 100)

Post-processing effects render via `ui_post_process_overlay.tscn`:
- **CanvasLayer**: Layer 100 (above gameplay at 0, below UI overlays)
- **Effects**: FilmGrainRect, DitherRect, CRTRect, ColorBlindRect
- **Shaders**: Each rect has a ShaderMaterial with configurable uniforms
- **Time Updates**: Film grain shader receives `TIME` updates in `_process()`

### UI Scaling

UIScaleRoot registration for consistent UI size adjustment:

```gdscript
# UIScaleRoot helper registers parent UI roots
func _ready() -> void:
    U_DisplayUtils.register_ui_scale_root(get_parent())

# M_DisplayManager applies scale to registered roots
func set_ui_scale(scale: float) -> void:
    scale = clampf(scale, 0.5, 2.0)
    for node in _ui_scale_roots:
        if node is CanvasLayer:
            node.transform = Transform2D().scaled(Vector2(scale, scale))
        elif node is Control:
            node.scale = Vector2(scale, scale)
```

**Registration rules:**
- ✅ Add UIScaleRoot helper node to menu/overlay/HUD root nodes
- ❌ Do NOT add to post-process overlay (layer 100, not UI)
- ❌ Do NOT add to nested widgets (inherit scaling from parents)

### Display Slice State Shape

```gdscript
{
    "display": {
        # Graphics
        "window_size_preset": "1920x1080",  # Valid: 1280x720, 1600x900, 1920x1080, 2560x1440, 3840x2160
        "window_mode": "windowed",          # Valid: windowed, fullscreen, borderless
        "vsync_enabled": true,
        "quality_preset": "high",           # Valid: low, medium, high, ultra

        # Post-Processing
        "film_grain_enabled": false,
        "film_grain_intensity": 0.1,        # Clamped: 0.0-1.0
        "crt_enabled": false,
        "crt_scanline_intensity": 0.3,      # Clamped: 0.0-1.0
        "crt_curvature": 2.0,
        "crt_chromatic_aberration": 0.002,
        "dither_enabled": false,
        "dither_intensity": 0.5,            # Clamped: 0.0-1.0
        "dither_pattern": "bayer",          # Valid: bayer, noise

        # UI
        "ui_scale": 1.0,                    # Clamped: 0.8-1.3

        # Accessibility
        "color_blind_mode": "normal",       # Valid: normal, deuteranopia, protanopia, tritanopia
        "high_contrast_enabled": false,
        "color_blind_shader_enabled": false,

        # Cinema Grade (transient — loaded per-scene, NOT persisted)
        "cinema_grade_filter_mode": 0,       # 0=none, 1-8=named filters
        "cinema_grade_filter_intensity": 1.0,
        "cinema_grade_exposure": 0.0,
        "cinema_grade_brightness": 0.0,
        "cinema_grade_contrast": 1.0,
        "cinema_grade_brilliance": 0.0,
        "cinema_grade_highlights": 0.0,
        "cinema_grade_shadows": 0.0,
        "cinema_grade_saturation": 1.0,
        "cinema_grade_vibrance": 0.0,
        "cinema_grade_warmth": 0.0,
        "cinema_grade_tint": 0.0,
        "cinema_grade_sharpness": 0.0,
    }
}
```

### Cinema Grading System (Phase 11)

Per-scene cinematic color grading applied as the bottom-most post-process layer. Artistic direction, not a user preference — always active regardless of `post_processing_enabled`.

**Layer Stack (bottom to top):**
- CinemaGradeLayer = CanvasLayer 1
- FilmGrainRect = CanvasLayer 2
- DitherRect = CanvasLayer 3
- CRTRect = CanvasLayer 4
- ColorBlindRect = CanvasLayer 5
- UIColorBlindLayer = CanvasLayer 11

**Scene Transition Flow:**
1. `action_dispatched` fires with `scene/transition_completed`
2. `U_DisplayCinemaGradeApplier` extracts `scene_id` from payload
3. Looks up `U_CinemaGradeRegistry.get_cinema_grade_for_scene(scene_id)` (returns neutral fallback if unmapped)
4. Dispatches `U_CinemaGradeActions.load_scene_grade(grade.to_dictionary())`
5. Display slice updates → hash change → `_apply_cinema_grade_settings()` sets shader uniforms

**Action Prefix (`cinema_grade/` NOT `display/`):**
- `cinema_grade/` prefix deliberately does NOT match `begins_with("display/")` in `U_GlobalSettingsSerialization.is_global_settings_action()`
- This ensures cinema grade state is NOT persisted to `user://global_settings.json`
- Per-scene grades are transient — loaded from `.tres` resources on each scene enter

**Registry (mobile-safe):**
```gdscript
# U_CinemaGradeRegistry uses const preload arrays (no runtime DirAccess)
const _SCENE_GRADE_PRELOADS := [
    preload("res://resources/display/cinema_grades/cfg_cinema_grade_gameplay_base.tres"),
    # ...
]
```

**Editor Preview (@tool node):**
- Drop `U_CinemaGradePreview` into any gameplay scene root
- Assign a `RS_SceneCinemaGrade` resource in the inspector
- Creates local CanvasLayer 100 + ColorRect with cinema grade shader
- `queue_free()` at runtime (M_DisplayManager handles everything in-game)

### Thread Safety

DisplayServer calls must be deferred for thread safety:

```gdscript
func set_window_mode(mode: String) -> void:
    call_deferred("_apply_window_mode", mode)

func _apply_window_mode(mode: String) -> void:
    match mode:
        "fullscreen":
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
        "borderless":
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
            DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
        _:  # windowed
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
```

### Anti-Patterns

- ❌ Mutating DisplayServer from non-main thread (use `call_deferred()`)
- ❌ Applying settings without hash check (causes redundant DisplayServer calls)
- ❌ Adding UIScaleRoot to the post-process overlay (it's not UI)
- ❌ Adding UIScaleRoot to nested widgets (causes compounding scale)
- ❌ Using instant/sync applies during preview mode (blocks preview hash)
- ❌ Relying on display settings auto-save (unlike audio, display uses M_SaveManager)
- ❌ Using `display/` prefix for cinema grade actions (would persist to global_settings.json)
- ❌ Gating cinema grade behind `post_processing_enabled` (it's artistic direction, always active)
- ❌ Using runtime `DirAccess` in cinema grade registry (breaks on Android PCK)

## Test Commands

- Run ECS tests
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs -gexit`
- Always include `-gexit` when running GUT via the command line so the runner terminates cleanly; without it the process hangs and triggers harness timeouts.
- Notes
  - Tests commonly `await get_tree().process_frame` after adding nodes to allow auto-registration with `M_ECSManager` before assertions.
  - When stubbing engine methods in tests (e.g., `is_on_floor`, `move_and_slide`), include `@warning_ignore("native_method_override")`.

## Quick How-Tos (non-duplicative)

- Add a new ECS Component
  - Create `scripts/ecs/components/c_your_component.gd` extending `BaseECSComponent` with `COMPONENT_TYPE` and exported NodePaths; add typed getters; update a scene to wire paths.
- Add a new ECS System
  - Create `scripts/ecs/systems/s_your_system.gd` extending `BaseECSSystem`; implement `process_tick(delta)`; query with your component's `StringName`; drop the node under a running scene—auto-configured.
- Find M_StateStore from any node
  - Use `U_StateUtils.get_store(self)` to find the store (internally uses U_ServiceLocator or injected store).
  - In `_ready()`: add `await get_tree().process_frame` BEFORE calling `get_store()` to avoid race conditions.
  - In `process_tick()`: no await needed (store already registered).
- Access managers via ServiceLocator (Phase 10B-7: T141)
  - Use `U_ServiceLocator.get_service(StringName("service_name"))` for fast, centralized manager access.
  - Available services: `"state_store"`, `"scene_manager"`, `"pause_manager"`, `"spawn_manager"`, `"camera_manager"`, `"cursor_manager"`, `"input_device_manager"`, `"input_profile_manager"`, `"ui_input_handler"`, `"audio_manager"`, `"display_manager"`, `"localization_manager"`, `"save_manager"`, `"vfx_manager"`.
  - ServiceLocator provides O(1) Dictionary lookup vs O(n) scene-tree traversal.
  - All services are registered at startup in `root.tscn` via `root.gd`.
- Create a new gameplay scene
  - Duplicate `scenes/gameplay/gameplay_base.tscn` as starting point.
  - Keep M_ECSManager + Systems + Entities + Environment structure.
  - Do NOT add M_StateStore or M_CursorManager (they live in root.tscn).
