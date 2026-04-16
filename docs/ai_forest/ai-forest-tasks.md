# AI Forest Simulation — Tasks Checklist

**Branch**: GOAP-AI
**Status**: Docs-only delivered — **Phase 1a next** (awaiting user go-ahead before implementation starts).
**Methodology**: TDD (Red-Green-Refactor) — write failing tests first, implement to green, then refactor.
**Scope**: Build a standalone top-down AI-testing scene with three species (wolves, rabbits, deer) and static trees, phased over three milestones. Detailed context in `docs/ai_forest/ai-forest-overview.md`.

**Ground rules**
- Every milestone ends with a green full AI unit-test suite (baseline: 124/124) plus the milestone's new tests.
- Style enforcement test (`tests/unit/style/test_style_enforcement.gd`) must stay green after any file/scene additions.
- After each committed milestone: update this tasks doc (mark `[x]` with completion notes) and the continuation prompt.
- Commit per milestone at minimum; commit per commit-level task when logically self-contained.
- All new tests extend `tests/base_test.gd` for auto scope isolation.

---

## Phase 1 — Scene shell + species behaviors + detection generalization

### P1a. Generalize `C_DetectionComponent` to tag-based targeting

**Goal**: `C_DetectionComponent` detects entities carrying `C_EntityTagComponent` with a matching `target_tag`, instead of querying `C_PlayerTagComponent` only. Preserves existing player-detection behavior when `target_tag = &"player"`.

- [ ] **Commit 1** (RED) — Write `tests/unit/ecs/systems/test_s_ai_detection_system_tag_target.gd` with:
  - Test: detector with `target_tag = &"prey"` flags `is_target_in_range = true` when an entity tagged `prey` is within `detection_radius`
  - Test: detector with `target_tag = &"prey"` ignores entity tagged `herbivore`
  - Test: detector with `target_tag = &"player"` (default) still detects player-tagged entities (back-compat)
  - Test: `detected_entity_id` matches the detected entity's `entity_id`
  - Confirm tests fail before implementation.
- [ ] **Commit 2** (GREEN) — Add `target_tag: StringName = &"player"` `@export` to `scripts/ecs/components/c_detection_component.gd`. Rewrite `scripts/ecs/systems/s_ai_detection_system.gd` proximity query to iterate `C_EntityTagComponent` holders whose `tags` contain `target_tag`. Publish `is_target_in_range` + `detected_entity_id` alongside legacy `is_player_in_range` + `last_detected_player_entity_id` (legacy aliases the new fields when `target_tag == &"player"`).
- [ ] **Commit 3** (REGRESSION) — Run `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_s_ai_detection_system.gd -gexit` and all AI integration suites to confirm no regressions.

### P1b. Forest agent prefab + species instances

**Goal**: Reusable base prefab for brain-bearing forest agents; three species-specific inheritors; a static tree prop.

- [ ] **Commit 4** — Author `scenes/prefabs/prefab_forest_agent.tscn` inheriting `scenes/templates/tmpl_character.tscn`. Attach components: `C_InputComponent`, `C_MovementComponent` (with a new `resources/base_settings/ecs/cfg_movement_settings_forest.tres`), `C_AIBrainComponent`, `C_DetectionComponent`, `C_EntityTagComponent`, `C_FloatingComponent`, `C_SpawnRecoveryComponent`.
- [ ] **Commit 5** — Author `scenes/prefabs/prefab_forest_wolf.tscn` (dark-gray CSGBox3D, `target_tag=&"prey"`, tag `&"predator"`), `prefab_forest_rabbit.tscn` (white, `target_tag=&"predator"`, tag `&"prey"`), `prefab_forest_deer.tscn` (brown, `target_tag=&"predator"`, tag `&"herbivore"`).
- [ ] **Commit 6** — Author `scenes/prefabs/prefab_forest_tree.tscn` with a `StaticBody3D` root and a dark-green CSG cylinder mesh. No brain.

### P1c. New AI actions (movement / flee / wander)

**Goal**: The three new `I_AIAction` subclasses required for Phase 1 behaviors. Existing `RS_AIActionMoveTo`, `RS_AIActionWait`, `RS_AIActionScan` cover the rest.

- [ ] **Commit 7** (RED) — Write `tests/unit/ai/actions/test_ai_actions_forest.gd` with:
  - Test: `RS_AIActionMoveToDetected` writes `task_state[U_AITaskStateKeys.MOVE_TARGET]` to the detected entity's world position when `C_DetectionComponent.is_target_in_range` is true
  - Test: `RS_AIActionMoveToDetected` completes immediately with `push_error` when detection is stale (null `detected_entity_id`)
  - Test: `RS_AIActionFleeFromDetected` writes move target at `pos + normalize(pos - detected_pos) * flee_distance`
  - Test: `RS_AIActionWander` writes a move target inside a circle of radius `home_radius` centered at `home_position`
  - Confirm failing.
- [ ] **Commit 8** (GREEN) — Implement `scripts/resources/ai/actions/rs_ai_action_move_to_detected.gd`, `rs_ai_action_flee_from_detected.gd`, `rs_ai_action_wander.gd`. All three must `class_name` correctly, extend `I_AIAction`, use `U_AITaskStateKeys` constants (no raw strings), and resolve context paths via `U_PathResolver` where applicable.

### P1d. AI resources for each species

**Goal**: Authored `.tres` goals + brain configs under `resources/ai/forest/`. Uses `RS_ConditionComponentField` (reused) for threat/prey checks.

- [ ] **Commit 9** — Create `resources/ai/forest/shared/` goal resources: `cfg_goal_wander.tres`, `cfg_goal_graze.tres`, `cfg_goal_flee.tres`, `cfg_goal_hunt.tres`, `cfg_goal_startle.tres`. All share `decision_group = &"forest_action"`. Each references new/reused actions via `RS_AIPrimitiveTask` or `RS_AICompoundTask` as appropriate.
- [ ] **Commit 10** — Create per-species brain configs: `resources/ai/forest/wolf/cfg_wolf_brain.tres` (`default_goal_id = &"wander"`, goals `[hunt, wander]`), `rabbit/cfg_rabbit_brain.tres` (`[flee, graze, wander]`), `deer/cfg_deer_brain.tres` (`[startle, graze, wander]`). All `RS_AIBrainSettings` instances.

### P1e. Label3D + HUD overlay

**Goal**: Per-agent floating label showing `entity_id + goal + task`, plus a 2D HUD that aggregates every brain.

- [ ] **Commit 11** (RED) — Write `tests/unit/ui/hud/test_ui_ai_brain_debug_overlay.gd`:
  - Test: overlay renders one row per brain entity discovered via `M_ECSManager.get_components(C_AIBrainComponent.COMPONENT_TYPE)`
  - Test: overlay row text matches `entity_id` / `active_goal_id` / current task id
  - Test: overlay gracefully handles empty brain list (no crash)
- [ ] **Commit 12** (GREEN) — Implement `scripts/ui/hud/ui_ai_brain_debug_overlay.gd` and `scenes/ui/hud/ui_ai_brain_debug_overlay.tscn`. Pulls snapshots from `C_AIBrainComponent.get_debug_snapshot()` at 4 Hz via a `Timer`. VBoxContainer with one row per entity.
- [ ] **Commit 13** — Implement `scripts/ui/hud/ui_forest_agent_label.gd` + `scenes/ui/hud/ui_forest_agent_label.tscn`. A `Label3D` (billboard-enabled, `fixed_size = true`, `no_depth_test = true`) attached per agent; updates text from the same snapshot each frame.

### P1f. Scene assembly

**Goal**: `gameplay_ai_forest.tscn` wired up end-to-end with only AI-essential systems.

- [ ] **Commit 14** — Author `scenes/gameplay/gameplay_ai_forest.tscn`:
  - Root `Node3D`
  - `ECS_Manager` (`M_ECSManager`)
  - `Systems/Core`: `S_AIBehaviorSystem`, `S_MoveTargetFollowerSystem`, `S_AIDetectionSystem`
  - `Systems/Physics`: `S_GravitySystem`
  - `Systems/Movement`: `S_MovementSystem`, `S_FloatingSystem`
  - `World/Floor` (60×60 green CSGBox3D), `World/Walls` (4 invisible StaticBody3D borders), `World/Trees` (~30 `prefab_forest_tree.tscn` instances scattered)
  - `Agents/Wolves` (4), `Agents/Rabbits` (8), `Agents/Deer` (6)
  - `Camera/TopDownCamera` (Camera3D, `PROJECTION_ORTHOGONAL`, size 70, pos `(0, 40, 0)`, rot `(-90°, 0, 0)`, `current = true`)
  - `Lighting/SunLight` (DirectionalLight3D)
  - `UI/BrainDebugOverlay` (instance of `ui_ai_brain_debug_overlay.tscn`)
- [ ] **Commit 15** (SMOKE TEST) — Add `tests/integration/gameplay/test_forest_ecosystem_smoke.gd`: loads the scene, awaits `process_frame` × 2, steps physics 60 frames, asserts every brain entity has a non-empty task queue and non-empty `active_goal_id`.

### Phase 1 verification

- [ ] `tools/run_gut_suite.sh -gdir=res://tests/unit -ginclude_subdirs -gexit` — all green
- [ ] `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd -gexit` — all green
- [ ] `tools/run_gut_suite.sh -gdir=res://tests/unit/ai -ginclude_subdirs -gexit` — baseline 124 + new Phase 1 tests
- [ ] `tools/run_gut_suite.sh -gtest=res://tests/integration/gameplay/test_forest_ecosystem_smoke.gd -gexit` — green
- [ ] Manual visual pass: launch scene, confirm each acceptance criterion from the overview doc

---

## Phase 2 — Hunger / satiety

### P2a. `C_NeedsComponent` + `RS_NeedsSettings` + `S_NeedsSystem`

- [ ] **Commit 16** (RED) — `tests/unit/ecs/components/test_c_needs_component.gd`: hunger initializes to `settings.initial_hunger`, clamps to `[0, 1]`, survives validation when `settings` is assigned.
- [ ] **Commit 17** (RED) — `tests/unit/ecs/systems/test_s_needs_system.gd`: hunger decays at `decay_per_second × delta`, clamps at 0, multiple entities tick independently.
- [ ] **Commit 18** (GREEN) — Author `scripts/resources/ecs/rs_needs_settings.gd` with exports `initial_hunger`, `decay_per_second`, `sated_threshold`, `starving_threshold`, `gain_on_feed`. Author `scripts/ecs/components/c_needs_component.gd` (extends `BaseECSComponent`, validates `settings != null`). Author `scripts/ecs/systems/s_needs_system.gd` (`SystemPhase.PRE_PHYSICS`).
- [ ] **Commit 19** — Wire `C_NeedsComponent` onto `prefab_forest_agent.tscn` with a per-species settings resource at `resources/base_settings/ai_forest/cfg_needs_{wolf,rabbit,deer}.tres`. Add `S_NeedsSystem` to `Systems/Core` in the forest scene.

### P2b. Goal scoring via hunger

- [ ] **Commit 20** (RED) — `tests/unit/ai/integration/test_hunger_drives_goal_score.gd`: hungry wolf (hunger below `sated_threshold`) selects `hunt` over `wander`; sated wolf selects `wander`. Same test for rabbit `graze`.
- [ ] **Commit 21** (GREEN) — Update `cfg_goal_hunt.tres` and `cfg_goal_graze.tres` to include a `RS_ConditionComponentField` reading `C_NeedsComponent.hunger` with an inverse response curve (lower hunger → higher score).
- [ ] **Commit 22** — New action `scripts/resources/ai/actions/rs_ai_action_feed.gd`: increments `C_NeedsComponent.hunger` by `settings.gain_on_feed`, clamps to `[0,1]`, completes immediately. Wire into `hunt`/`graze` compound tasks' final step.

### P2c. HUD hunger display

- [ ] **Commit 23** — Extend `ui_ai_brain_debug_overlay.gd` + `ui_forest_agent_label.gd` to show hunger with color coding (green > sated, yellow mid, red < starving).
- [ ] **Commit 24** — Test update for overlay + label reflecting hunger.

### Phase 2 verification

- [ ] Full unit + integration suites green
- [ ] Visual: agents visibly fluctuate between `wander` and `hunt`/`graze` over time
- [ ] HUD hunger bars update

---

## Phase 3 — Emergent pack behavior + polish

### P3a. Wolf pack detection

- [ ] **Commit 25** — Add a second `C_DetectionComponent` child to `prefab_forest_wolf.tscn` with `target_tag = &"predator"` and a wider `detection_radius`. Distinguish via a `detection_role` string field on the component (new export: `detection_role: StringName`) — values `"primary"` (prey detection) and `"pack"` (ally detection).
- [ ] **Commit 26** (RED) — Update `S_AIDetectionSystem` tests to handle multiple detection components per entity, keyed by `detection_role`.
- [ ] **Commit 27** (GREEN) — Update system to iterate all `C_DetectionComponent` instances per entity instead of assuming one.

### P3b. Pack-hunt goal

- [ ] **Commit 28** — Author `cfg_goal_hunt_pack.tres` with `decision_group = &"forest_action"`, scoring: base hunt + bonus when `pack_detection.is_target_in_range && needs.hunger < sated_threshold`. Shares the decision group with solo `hunt` so only one fires per tick.
- [ ] **Commit 29** (RED) — `tests/unit/ai/integration/test_pack_converges.gd`: two wolves within pack-detection radius, one rabbit in prey-detection radius → both wolves select hunt with the same `detected_entity_id` within 2 seconds of sim.
- [ ] **Commit 30** (GREEN) — Tune scoring + cooldowns until test passes.

### P3c. Polish

- [ ] **Commit 31** — Tune `detection_radius`, `flee_distance`, `home_radius`, `decay_per_second` across species until visual behavior feels right. Document tuned values in the overview doc.
- [ ] **Commit 32** — Full regression pass + doc update.

### Phase 3 verification

- [ ] Full unit + integration suites green
- [ ] Visual: two wolves visibly converge on same rabbit when near each other
- [ ] No goal thrashing in HUD log

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

# Manual visual
/Applications/Godot.app/Contents/MacOS/Godot --path . scenes/gameplay/gameplay_ai_forest.tscn
```

---

## Completion hygiene

Whenever a phase finishes:
1. Mark every task `[x]` with a short completion note (line count, test IDs, caveats).
2. Update `docs/ai_forest/ai-forest-continuation-prompt.md` with the new current phase + next task.
3. Update `AGENTS.md` if new patterns or contracts emerge (e.g. multi-detection-component contract in Phase 3).
4. Update `docs/general/DEV_PITFALLS.md` if anything non-obvious is learned.
5. Commit doc updates separately from implementation commits.
