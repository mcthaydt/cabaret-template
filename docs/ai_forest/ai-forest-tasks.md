# AI Forest Simulation — Tasks Checklist

**Branch**: GOAP-AI
**Status**: Phase 1 complete (2026-04-16) — awaiting go-ahead for **Phase 2a Commit 20**.
**Methodology**: TDD (Red-Green-Refactor) — write failing tests first, implement to green, then refactor.
**Scope**: Build a standalone top-down AI-testing scene with three species (wolves, rabbits, deer) and static trees, phased over three milestones. Detailed context in `docs/ai_forest/ai-forest-overview.md`.

**Ground rules**
- Every milestone ends with the full AI unit-test suite green (current baseline: last measured 130/130 on 2026-04-16 after Phase 1c; re-measure immediately before starting new phases).
- Style enforcement test (`tests/unit/style/test_style_enforcement.gd`) must stay green. Critical rules for this plan: `test_ai_move_target_magic_strings_not_used_in_ai_scripts`, `test_ai_action_scripts_use_task_state_key_constants`, `test_ai_resource_scripts_are_grouped_by_subdirectory`, `test_gameplay_scenes_do_not_embed_hud_instances`.
- After each committed milestone: update this tasks doc (mark `[x]` with completion notes) and the continuation prompt.
- Commit per milestone at minimum; commit per commit-level task when logically self-contained.
- All new tests extend `tests/base_test.gd` for auto scope isolation.

**Design decisions locked from audit**
- Tag-based detection = read `BaseECSEntity.tags` via `entity.has_tag(target_tag)`. **No new `C_EntityTagComponent`** — tags already live on the entity root.
- Forest agents inherit `scenes/templates/tmpl_character.tscn` directly (peer to `prefab_demo_npc.tscn`).
- Debug panel lives under `scripts/debug/` + `scenes/debug/` with `debug_` prefix. **Not a HUD.**
- Wander home captured as the agent's `global_position` at `_ready()`.
- **No player entity.** No `S_InputSystem`, `C_PlayerTagComponent`, or player-facing systems in the scene.
- **No `C_SpawnRecoveryComponent`** on agents. Invisible walls prevent fall-off; recovery would no-op anyway per AGENTS.md R5 for non-player entities without a spawn_point_id.
- **No `decision_group` field on `RS_AIGoal`** — `U_AIGoalSelector` hardcodes `&"ai_goal"` globally. All goal thrash prevention uses `priority` + `cooldown` + `requires_rising_edge` + `one_shot`.

---

## Phase 1 — Scene shell + species behaviors + detection generalization

### P1a. Generalize `S_AIDetectionSystem` to tag-based targeting

**Goal**: `C_DetectionComponent` gains a `target_tag: StringName = &"player"` export. `S_AIDetectionSystem` iterates candidate entities, resolves each one's entity-root via `U_ECSUtils.find_entity_root()`, and only considers candidates whose entity root has `target_tag` in `BaseECSEntity.tags`. Default `&"player"` preserves existing behavior (plus a new `C_PlayerTagComponent` short-circuit for existing showcase entities).

**Implementation note**: current system queries `[C_PlayerTagComponent, C_MovementComponent]` to build the candidate pool. New system queries `[C_MovementComponent]` and filters candidates by `entity_root.has_tag(detector.target_tag)`. Published fields stay: `is_player_in_range`, `last_detected_player_entity_id` (names kept for back-compat — they now mean "target in range" / "last detected target id" whenever `target_tag != &"player"`).

- [x] **Commit 1** (RED) — Write `tests/unit/ecs/systems/test_s_ai_detection_system_tag_target.gd`:
  - Test: detector with `target_tag = &"prey"` flips `is_player_in_range = true` when an entity with `tags.has(&"prey")` is within `detection_radius`
  - Test: detector with `target_tag = &"prey"` ignores an entity tagged only `&"herbivore"`
  - Test: detector with `target_tag = &"player"` (default) still detects player-tagged entities (back-compat regression)
  - Test: `last_detected_player_entity_id` matches the detected target's `BaseECSEntity.get_entity_id()`
  - Confirm tests fail before implementation.
  - Completion note (2026-04-16): suite added and confirmed RED (`2/4` passing) before implementation (`test_target_tag_prey_detects_matching_entity_in_range`, `test_last_detected_entity_id_uses_base_ecs_entity_id` failed as expected).
- [x] **Commit 2** (GREEN) — Add `@export var target_tag: StringName = &"player"` to `scripts/ecs/components/c_detection_component.gd`. Rewrite the candidate-pool collection in `scripts/ecs/systems/s_ai_detection_system.gd`: iterate entities with `C_MovementComponent`, resolve each one's entity root via `U_ECSUtils.find_entity_root()`, and skip any whose root does not have `target_tag` in its tags. Preserve all published fields and flag/event dispatch paths.
  - Completion note (2026-04-16): implemented tag-aware candidate filtering + `player` short-circuit via optional `C_PlayerTagComponent`; kept `is_player_in_range` / `last_detected_player_entity_id` contract unchanged.
- [x] **Commit 3** (REGRESSION) — Run `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_s_ai_detection_system.gd -gexit` and all AI integration suites (`test_ai_interaction_triggers.gd`, `test_ai_demo_power_core.gd`, `test_ai_pipeline_integration.gd`) to confirm no regressions.
  - Completion note (2026-04-16): all listed suites green; new tag-target suite also green (`4/4`).

### P1b. Forest agent prefab + species instances

**Goal**: Base prefab for brain-bearing forest agents that inherits `tmpl_character.tscn` directly; three species-specific inheritors; a static tree prop.

- [x] **Commit 4** — Author `scenes/prefabs/prefab_forest_agent.tscn` inheriting `scenes/templates/tmpl_character.tscn`. Root `E_ForestAgentRoot` (`BaseECSEntity`). Components to add (on top of what `tmpl_character` already provides):
  - `C_InputComponent` (no settings required)
  - `C_AIBrainComponent` (per-species `brain_settings` authored on inheritors)
  - `C_DetectionComponent` (per-species `target_tag` + `detection_radius` authored on inheritors)
  - `C_MoveTargetComponent` (primary move-target channel)
  - New movement settings `resources/base_settings/ai_forest/cfg_movement_forest.tres` (tuned for top-down speed)
  - **Omit** `C_SpawnRecoveryComponent` (no spawn points in this scene)
  - Completion note (2026-04-16): created `prefab_forest_agent.tscn` + `cfg_movement_forest.tres`, kept inherited template stack, added required AI components, and omitted spawn-recovery.
- [x] **Commit 5** — Author `prefab_forest_wolf.tscn` inheriting `prefab_forest_agent.tscn`. Override `E_ForestAgentRoot.tags = Array[StringName]([&"predator", &"ai", &"forest"])`, set `C_DetectionComponent.target_tag = &"prey"`, `detection_radius ≈ 12.0`, attach a dark-gray CSGBox3D as `Body_Mesh`.
  - Completion note (2026-04-16): created `prefab_forest_wolf.tscn` with predator tags, prey-target detection radius `12.0`, and dark-gray `Body_Mesh` (`use_collision = false`).
- [x] **Commit 6** — Author `prefab_forest_rabbit.tscn` (tags `[&"prey", &"ai", &"forest"]`, `target_tag = &"predator"`, `detection_radius ≈ 8.0`, white CSGBox3D smaller than wolf).
  - Completion note (2026-04-16): created `prefab_forest_rabbit.tscn` with prey tags, predator-target detection radius `8.0`, and smaller white `Body_Mesh` (`use_collision = false`).
- [x] **Commit 7** — Author `prefab_forest_deer.tscn` (tags `[&"herbivore", &"ai", &"forest"]`, `target_tag = &"predator"`, `detection_radius ≈ 10.0`, brown CSGBox3D).
  - Completion note (2026-04-16): created `prefab_forest_deer.tscn` with herbivore tags, predator-target detection radius `10.0`, and brown `Body_Mesh` (`use_collision = false`).
- [x] **Commit 8** — Author `prefab_forest_tree.tscn` with `StaticBody3D` root and a dark-green CSGCylinder3D. No brain, no entity_id. Used as decoration + collider.
  - Completion note (2026-04-16): created `prefab_forest_tree.tscn` with `StaticBody3D` root, explicit `CollisionShape3D`, and dark-green `Body_Mesh` (`CSGCylinder3D`, `use_collision = false`).

### P1c. New AI actions

**Goal**: Three new `I_AIAction` subclasses. Existing `RS_AIActionMoveTo`, `RS_AIActionWait`, `RS_AIActionScan` cover the remaining behavior steps.

- [x] **Commit 9** (RED) — Write `tests/unit/ai/actions/test_ai_actions_forest.gd`:
  - `RS_AIActionMoveToDetected`: reads detected entity position from the entity's `C_DetectionComponent`, writes `task_state[U_AITaskStateKeys.MOVE_TARGET]` + activates `C_MoveTargetComponent` on the same entity. Completes early with `push_error` when detection is stale (empty `last_detected_player_entity_id`).
  - `RS_AIActionFleeFromDetected`: target = `self_pos + normalize(self_pos - detected_pos) * flee_distance`. Same writes as above.
  - `RS_AIActionWander`: captures `home_position = entity.global_position` on first `start()` call (stored in `task_state["ai_wander_home"]`) and thereafter picks random points inside a circle of radius `home_radius`.
  - Confirm failing.
  - Completion note (2026-04-16): added `test_ai_actions_forest.gd` (`6` tests) and confirmed RED before implementation (missing scripts + `WANDER_HOME` constant).
- [x] **Commit 10** (GREEN) — Implement:
  - `scripts/resources/ai/actions/rs_ai_action_move_to_detected.gd`
  - `scripts/resources/ai/actions/rs_ai_action_flee_from_detected.gd`
  - `scripts/resources/ai/actions/rs_ai_action_wander.gd`
  All extend `I_AIAction`, override `start/tick/is_complete`, use `U_AITaskStateKeys` constants (no raw strings — style rule). Add a new constant `WANDER_HOME := &"ai_wander_home"` to `scripts/utils/ai/u_ai_task_state_keys.gd` for the wander home-position scratchpad.
  - Completion note (2026-04-16): implemented the three action scripts and `WANDER_HOME`; forest action suite green (`6/6`) and full AI suite green (`130/130`).
- [x] **Commit 11** (GREEN followup) — Update `RS_AIActionMoveToDetected` + `RS_AIActionFleeFromDetected` to set the target on `C_MoveTargetComponent` (primary channel) in addition to `task_state` (fallback), matching `RS_AIActionMoveTo`'s pattern.
  - Completion note (2026-04-16): finalized detected/flee actions with move-target resolution parity and completion-state cleanup while preserving component-first move-target routing.

### P1d. AI resources for each species

**Goal**: Authored `.tres` goals + brain configs under `resources/ai/forest/`. Uses `RS_ConditionComponentField` reading `C_DetectionComponent.is_player_in_range` for threat/prey checks. No `decision_group`.

- [x] **Commit 12** — Create `resources/ai/forest/shared/` goal resources:
  - `cfg_goal_wander.tres` — `priority = 0`, constant condition score 0.3 (baseline), root_task = primitive wander
  - `cfg_goal_flee.tres` — `priority = 10`, condition = `RS_ConditionComponentField` reading `C_DetectionComponent.is_player_in_range == true`, root_task = primitive flee-from-detected
  - `cfg_goal_hunt.tres` — `priority = 10`, same condition pattern (detection-positive), root_task = compound `[move_to_detected, wait, move_to_detected]`
  - `cfg_goal_graze.tres` — `priority = 2`, constant condition 0.5, root_task = wait-in-place
  - `cfg_goal_startle.tres` — `priority = 8`, condition = detection-positive, `cooldown = 2.0`, root_task = `[scan_alert, wait_short]`
  - Completion note (2026-04-16): authored all five shared goal resources under `resources/ai/forest/shared/` using typed goal/task/action resources and `RS_ConditionComponentField` detection checks.
- [x] **Commit 13** — Create per-species brain configs:
  - `resources/ai/forest/wolf/cfg_wolf_brain.tres` (`default_goal_id = &"wander"`, `goals = [hunt, wander]`)
  - `resources/ai/forest/rabbit/cfg_rabbit_brain.tres` (`[flee, graze, wander]`)
  - `resources/ai/forest/deer/cfg_deer_brain.tres` (`[startle, graze, wander]`)
  All are `RS_AIBrainSettings` instances with `evaluation_interval = 0.25`.
  - Completion note (2026-04-16): authored all three species brain configs under `resources/ai/forest/{wolf,rabbit,deer}/` with typed `Array[RS_AIGoal]` references and `evaluation_interval = 0.25`.

### P1e. Label3D + debug panel

**Goal**: Per-agent floating label showing `entity_id + goal + task`, plus a separate debug Control that aggregates every brain. Both read `C_AIBrainComponent.get_debug_snapshot()` (already populated by `S_AIBehaviorSystem._build_brain_snapshot()` each tick).

- [x] **Commit 14** (RED) — Write `tests/unit/debug/test_debug_ai_brain_panel.gd`:
  - Test: panel renders one row per brain entity discovered via `M_ECSManager.get_components(C_AIBrainComponent.COMPONENT_TYPE)`
  - Test: row text matches the snapshot's `entity_id` / `goal_id` / current `task_id`
  - Test: panel gracefully handles an empty brain list (no crash)
  - Completion note (2026-04-16): added panel test suite and confirmed RED before implementation.
- [x] **Commit 15** (GREEN) — Implement `scripts/debug/debug_ai_brain_panel.gd` and `scenes/debug/debug_ai_brain_panel.tscn`. Root is a `Control` (not a HUD widget). `VBoxContainer` with one row per brain, refreshed by a 4 Hz `Timer`.
  - Completion note (2026-04-16): implemented panel script/scene; `tests/unit/debug/test_debug_ai_brain_panel.gd` green (`3/3`).
- [x] **Commit 16** — Implement `scripts/debug/debug_forest_agent_label.gd` and `scenes/debug/debug_forest_agent_label.tscn`. A `Label3D` with `billboard = BILLBOARD_ENABLED`, `fixed_size = true`, `no_depth_test = true`, child of each agent's `E_ForestAgentRoot`. Text updated each frame from the agent's own `C_AIBrainComponent.get_debug_snapshot()`.
  - Completion note (2026-04-16): implemented agent label script/scene and wired the prefab to instance the label.

### P1f. Scene assembly + registry

**Goal**: `gameplay_ai_forest.tscn` wired up end-to-end with only AI-essential systems; reachable through `M_SceneManager` via registry entry.

- [x] **Commit 17** — Author `scenes/gameplay/gameplay_ai_forest.tscn`. Structure (each container node carries its matching marker script from `scripts/scene_structure/`):
  - Root `Node3D`
  - `Managers` (`marker_managers_group.gd`) — `M_ECSManager`
  - `Systems` (`marker_systems_group.gd`)
    - `Systems/Core` (`marker_systems_core_group.gd`) — `S_AIBehaviorSystem`, `S_MoveTargetFollowerSystem`, `S_AIDetectionSystem`
    - `Systems/Physics` (`marker_systems_physics_group.gd`) — `S_GravitySystem`
    - `Systems/Movement` (`marker_systems_movement_group.gd`) — `S_MovementSystem`, `S_FloatingSystem`
  - `Environment` (`marker_environment_group.gd`) — `Floor` (60×60 green CSGBox3D), `Walls` (4 invisible StaticBody3D borders), `Trees` (~30 `prefab_forest_tree.tscn` instances)
  - `Entities` (`marker_entities_group.gd`) — Wolves (×4), Rabbits (×8), Deer (×6)
  - `Lighting` (`marker_lighting_group.gd`) — `SunLight` (DirectionalLight3D downward)
  - `Camera` — `TopDownCamera` (Camera3D, `projection = PROJECTION_ORTHOGONAL`, `size = 70`, `position = (0, 40, 0)`, `rotation_degrees = (-90, 0, 0)`, `current = true`)
  - `Debug` — instance of `debug_ai_brain_panel.tscn`
  - Completion note (2026-04-16): assembled gameplay scene with required marker containers, AI runtime systems, species/tree instances, top-down camera, and debug panel.
- [x] **Commit 18** — Register scene. Create `resources/scene_registry/cfg_ai_forest_entry.tres` (mirroring `cfg_ai_showcase_entry.tres`):
  - `scene_id = &"ai_forest"`
  - `scene_path = "res://scenes/gameplay/gameplay_ai_forest.tscn"`
  - `scene_type = 1` (GAMEPLAY)
  - `default_transition = "loading"`
  - `preload_priority = 0` (on-demand)
  - Completion note (2026-04-16): added `cfg_ai_forest_entry.tres` and validated SceneRegistry lookup path.
- [x] **Commit 19** (SMOKE TEST) — `tests/integration/gameplay/test_forest_ecosystem_smoke.gd`: load the scene via `M_SceneManager`, await `process_frame × 2`, step physics 60 frames, assert every brain entity has a non-empty `current_task_queue` and `active_goal_id != StringName()`.
  - Completion note (2026-04-16): added smoke test and wired wolf/rabbit/deer prefab `C_AIBrainComponent.brain_settings` to species resources so all brains select goals/tasks at runtime; smoke test green (`1/1`).

### Phase 1 verification

- [x] `tools/run_gut_suite.sh -gdir=res://tests/unit -ginclude_subdirs -gexit` — green (`3945` passing, `8` pending/risky headless skips, `0` failing; run on 2026-04-16)
- [x] `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd -gexit` — green (`58/58`)
- [x] `tools/run_gut_suite.sh -gdir=res://tests/unit/ai -ginclude_subdirs -gexit` — green (`130/130`)
- [x] `tools/run_gut_suite.sh -gtest=res://tests/integration/gameplay/test_forest_ecosystem_smoke.gd -gexit` — green (`1/1`)
- [ ] Manual visual pass: launch scene, confirm each acceptance criterion from the overview doc (not run in this headless pass)

---

## Phase 2 — Hunger / satiety

### P2a. `C_NeedsComponent` + `RS_NeedsSettings` + `S_NeedsSystem`

- [ ] **Commit 20** (RED) — `tests/unit/ecs/components/test_c_needs_component.gd`: hunger initializes to `settings.initial_hunger`, clamps to `[0, 1]`, validates when `settings` is non-null.
- [ ] **Commit 21** (RED) — `tests/unit/ecs/systems/test_s_needs_system.gd`: hunger decays at `decay_per_second × delta`, clamps at 0, multiple entities tick independently.
- [ ] **Commit 22** (GREEN) — Author:
  - `scripts/resources/ecs/rs_needs_settings.gd` — exports `initial_hunger`, `decay_per_second`, `sated_threshold`, `starving_threshold`, `gain_on_feed`
  - `scripts/ecs/components/c_needs_component.gd` — extends `BaseECSComponent`, exports `settings: RS_NeedsSettings`, runtime `hunger: float`, validates `settings != null`
  - `scripts/ecs/systems/s_needs_system.gd` — `SystemPhase.PRE_PHYSICS`, ticks hunger per entity
- [ ] **Commit 23** — Wire `C_NeedsComponent` onto `prefab_forest_agent.tscn` with per-species settings: `resources/base_settings/ai_forest/cfg_needs_{wolf,rabbit,deer}.tres`. Add `S_NeedsSystem` to `Systems/Core` in the forest scene.

### P2b. Goal scoring via hunger

- [ ] **Commit 24** (RED) — `tests/unit/ai/integration/test_hunger_drives_goal_score.gd`: a hungry wolf (hunger below `sated_threshold`) selects `hunt` over `wander`; a sated wolf picks `wander`. Mirror test for rabbit `graze`.
- [ ] **Commit 25** (GREEN) — Update `cfg_goal_hunt.tres` and `cfg_goal_graze.tres` to include an additional `RS_ConditionComponentField` reading `C_NeedsComponent.hunger` — score is `(1 - hunger)` mapped through `range_min/range_max`, so lower hunger = higher score.
- [ ] **Commit 26** — New action `scripts/resources/ai/actions/rs_ai_action_feed.gd`: increments `C_NeedsComponent.hunger` by `settings.gain_on_feed`, clamps to `[0,1]`, completes immediately. Appended as the final step in `hunt`/`graze` compound tasks.

### P2c. Debug panel hunger display

- [ ] **Commit 27** — Extend `debug_ai_brain_panel.gd` + `debug_forest_agent_label.gd` to show hunger with color coding: green above `sated_threshold`, yellow between thresholds, red below `starving_threshold`.
- [ ] **Commit 28** — Test update for panel + label reflecting hunger state.

### Phase 2 verification

- [ ] Full unit + integration suites green
- [ ] Visual: agents visibly fluctuate between `wander` and `hunt`/`graze` over time
- [ ] Debug panel hunger colors update

---

## Phase 3 — Emergent pack behavior + polish

### P3a. Multi-detection-component support

- [ ] **Commit 29** — Extend `C_DetectionComponent` with an optional `detection_role: StringName = &"primary"` export (purely informational; `is_player_in_range` + `last_detected_player_entity_id` stay per-component). Update `S_AIDetectionSystem` to iterate *all* `C_DetectionComponent` instances per entity rather than assuming one.
- [ ] **Commit 30** (RED) — Update `tests/unit/ecs/systems/test_s_ai_detection_system_tag_target.gd` (and add a new `test_s_ai_detection_system_multi_component.gd` if needed): one entity with two detection components, each `target_tag` different, each publishes independent state.
- [ ] **Commit 31** (GREEN) — Implement multi-component iteration; preserve all back-compat fields per component.

### P3b. Pack-hunt goal

- [ ] **Commit 32** — Add a second `C_DetectionComponent` child to `prefab_forest_wolf.tscn` with `target_tag = &"predator"`, wider `detection_radius ≈ 18.0`, `detection_role = &"pack"`. Both detection components coexist on the wolf; goal conditions read both via `field_path = "detection_role_primary/is_player_in_range"` pattern (or equivalent — depends on exact multi-component exposure chosen in P3a).
- [ ] **Commit 33** — Author `cfg_goal_hunt_pack.tres`: `priority = 12` (beats solo `hunt` at 10 when its condition passes), `cooldown = 1.0` to prevent thrash with solo `hunt`, conditions = (pack-detection positive) AND (prey-detection positive) AND (hunger below sated_threshold from Phase 2).
- [ ] **Commit 34** (RED) — `tests/unit/ai/integration/test_pack_converges.gd`: two wolves within pack-detection radius of each other plus one rabbit in prey-detection radius → both wolves select hunt with the same `detected_entity_id` within 2 seconds of sim.
- [ ] **Commit 35** (GREEN) — Tune priorities, cooldowns, and detection radii until test passes without thrashing.

### P3c. Polish

- [ ] **Commit 36** — Tune `detection_radius`, `flee_distance`, `home_radius`, `decay_per_second` across species until visual behavior feels right. Document final tuned values in `ai-forest-overview.md`.
- [ ] **Commit 37** — Full regression pass + doc update.

### Phase 3 verification

- [ ] Full unit + integration suites green
- [ ] Visual: two wolves visibly converge on the same rabbit when near each other
- [ ] No goal thrashing visible in the debug panel

---

## Cross-phase testing commands

```bash
# Full unit suite
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit

# AI-only
tools/run_gut_suite.sh -gdir=res://tests/unit/ai -ginclude_subdirs -gexit

# Integration (AI + forest smoke)
tools/run_gut_suite.sh -gdir=res://tests/integration/gameplay -ginclude_subdirs -gexit

# Style enforcement
tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd -gexit

# Manual visual (direct)
/Applications/Godot.app/Contents/MacOS/Godot --path . scenes/gameplay/gameplay_ai_forest.tscn

# Manual visual (via scene manager, once registered)
# — run the game and call M_SceneManager.load_scene(&"ai_forest")
```

---

## Completion hygiene

Whenever a phase finishes:
1. Mark every task `[x]` with a short completion note (line count, test IDs, caveats).
2. Update `docs/ai_forest/ai-forest-continuation-prompt.md` with the new current phase + next task.
3. Update `AGENTS.md` if new patterns or contracts emerge (e.g. multi-detection-component contract in Phase 3, new `WANDER_HOME` task-state key).
4. Update `docs/general/DEV_PITFALLS.md` if anything non-obvious is learned.
5. Commit doc updates separately from implementation commits.
