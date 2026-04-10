# AI System Refactor — Tasks Checklist

**Branch**: `GOAP-AI` (or follow-up branch)
**Status**: Not started
**Methodology**: TDD (Red-Green-Refactor) — tests written within each milestone, not deferred
**Reference**: `docs/ai_system/ai-system-overview.md`, `docs/ai_system/ai-system-tasks.md`

---

## Purpose

The GOAP/HTN pipeline landed across M1–M15 and is functionally green, but the implementation has accreted architectural debt that will make future scaling painful. This refactor is a targeted, backwards-compatible pass to:

1. **Type-safety** — eliminate `_read_object_property`/`_read_int_property`/`_read_bool_property`/`_read_float_property`/`_variant_to_string_name` duck-typing from the AI hot path.
2. **Modularity** — split `s_ai_behavior_system.gd` (771 lines) into focused, independently-testable collaborators.
3. **Modular action registry** — formalize `I_AIAction` as a real base class and kill magic-string `task_state` keys shared between actions and the navigation system.
4. **Debug decoupling** — lift duplicated render-probe + log-throttle code out of production systems into shared utilities.
5. **Player/NPC DRY** — promote the spawn-recovery and move-target-follower patterns to shared ECS systems used by both player and NPCs.
6. **Directory hygiene** — reorganize `scripts/resources/ai/` and move demo-only systems out of production folders.

No behavioral changes. Integration suite (`tests/unit/ai/integration/test_ai_pipeline_integration.gd`) must stay green throughout.

---

## Sequencing

`R1` must land first — type safety is a prerequisite that removes duck-typing blockers from every downstream split.
`R2` next — shared `task_state` key constants are consumed by R3/R4/R6.
`R3` and `R4` can overlap — R4 lifts debug code out; R3 splits the rest of the behavior system.
`R5` and `R6` are the "share with player" milestones — independent of each other.
`R7` is a mechanical reorg, safer after R1–R6 settle.
`R8` is a trivial move.
`R9` is an internal planner cleanup (safe once callers are strongly typed).
`R10` is the final orchestration integration pass.

---

## Milestone R1: Typed Brain Settings, Goals, and Tasks

**Goal**: Tighten resource types so the hot path can drop its `_read_*_property` helpers. `C_AIBrainComponent.brain_settings`, `RS_AIBrainSettings.goals`, `RS_AIGoal.root_task`, `RS_AIPrimitiveTask.action`, and `RS_AICompoundTask.subtasks` become strongly typed.

- [ ] **Commit 1** — Extend resource unit tests (TDD RED):
  - `tests/unit/ai/resources/test_rs_ai_goal.gd` *(existing)* — add `test_goals_array_is_typed_rs_ai_goal`, `test_goals_rejects_non_rs_ai_goal_entries`, `test_root_task_typed_rs_ai_task`, `test_conditions_array_typed_i_condition`. Brain-settings coverage already lives in this file (per M2), so extend it in place rather than creating a new file.
  - `tests/unit/ai/resources/test_rs_ai_task.gd` *(existing)* — add `test_primitive_task_action_typed_i_ai_action`, `test_compound_task_subtasks_typed_rs_ai_task`
  - `tests/unit/ecs/components/test_c_ai_brain_component.gd` *(existing)* — add `test_brain_settings_export_typed_rs_ai_brain_settings`, `test_current_task_queue_typed_rs_ai_primitive_task`
- [ ] **Commit 2** — Implement typed field updates (TDD GREEN):
  - `scripts/resources/ai/rs_ai_brain_settings.gd` — `goals: Array[Resource]` → `Array[RS_AIGoal]`
  - `scripts/resources/ai/rs_ai_goal.gd` — `root_task: Resource` → `RS_AITask`; `conditions: Array[Resource]` → `Array[I_Condition]` (the `I_Condition` base lives at `scripts/interfaces/i_condition.gd` and is the shared contract used by `RS_ConditionComponentField`, `RS_ConditionReduxField`, `RS_ConditionEntityTag`, `RS_ConditionEventName`, `RS_ConditionEventPayload`, `RS_ConditionComposite`, `RS_ConditionConstant`)
  - `scripts/resources/ai/rs_ai_primitive_task.gd` — `action: Resource` → `I_AIAction`
  - `scripts/resources/ai/rs_ai_compound_task.gd` — `subtasks: Array[Resource]` → `Array[RS_AITask]`; `method_conditions: Array[Resource]` → `Array[I_Condition]`
  - `scripts/ecs/components/c_ai_brain_component.gd` — `brain_settings: Resource` → `RS_AIBrainSettings`; `current_task_queue: Array[Resource]` → `Array[RS_AIPrimitiveTask]`; add typed accessors `get_brain_settings()`, `get_active_goal_id()`, `get_current_task()`
- [ ] **Commit 3** — Delete duck-typing helpers from `s_ai_behavior_system.gd` that are no longer reachable after the type tightening (`_read_object_property` can remain temporarily if still called from suspended-state paths; they vanish in R10)

**R1 Verification**:
- [ ] All new typed tests green
- [ ] Existing `test_ai_pipeline_integration.gd` green (no behavior change)
- [ ] `test_style_enforcement.gd` passes
- [ ] Full-suite regression green

**R1 Completion Notes**: _(to be filled during execution)_

---

## Milestone R2: Shared `task_state` Keys + Action Base Hardening

**Goal**: Eliminate magic-string coupling between actions and systems. `"ai_move_target"`, `"ai_arrival_threshold"`, `"action_started"`, `"move_target_source"`, `"move_target_resolution_reason"`, `"move_target_used_fallback"`, and the debug-probe keys are currently duplicated across `rs_ai_action_move_to.gd`, `s_ai_behavior_system.gd`, and `s_ai_navigation_system.gd`. Consolidate them. Harden `I_AIAction` so concrete actions extend it via `class_name`, not string path.

- [ ] **Commit 1** — Create keys + base tests (TDD RED):
  - `tests/unit/ai/test_u_ai_task_state_keys.gd` — `test_move_target_key_constant`, `test_arrival_threshold_key_constant`, `test_action_started_key_constant`, etc.
  - `tests/unit/ai/test_i_ai_action_base.gd` — `test_subclass_extends_class_name`, `test_base_start_virtuals_are_callable`
  - Grep-based style test (add to `test_style_enforcement.gd` or new file): assert no AI script under `scripts/resources/ai/` or `scripts/ecs/systems/s_ai_*` contains a bare `"ai_move_target"` string literal
- [ ] **Commit 2** — Implement (TDD GREEN):
  - `scripts/utils/ai/u_ai_task_state_keys.gd` — new `class_name U_AITaskStateKeys` with `const MOVE_TARGET := &"ai_move_target"`, `const ARRIVAL_THRESHOLD := &"ai_arrival_threshold"`, `const ACTION_STARTED := &"action_started"`, `const MOVE_TARGET_RESOLVED := &"move_target_resolved"`, `const MOVE_TARGET_SOURCE := &"move_target_source"`, `const MOVE_TARGET_RESOLUTION_REASON := &"move_target_resolution_reason"`, `const MOVE_TARGET_USED_FALLBACK := &"move_target_used_fallback"`, and the six `move_target_*` debug keys
  - `scripts/interfaces/i_ai_action.gd` — keep `class_name I_AIAction extends Resource`; replace `push_error` stubs with `assert(false, "...")` inside the virtuals so misuse is detected at the first call site; add a doc comment declaring the contract
  - `scripts/resources/ai/actions/rs_ai_action_move_to.gd` — replace `TARGET_STATE_KEY`, `ARRIVAL_THRESHOLD_STATE_KEY`, and every `DEBUG_*_STATE_KEY` with `U_AITaskStateKeys.*`; change `extends "res://scripts/interfaces/i_ai_action.gd"` → `extends I_AIAction`
  - Same `extends I_AIAction` fix for `rs_ai_action_wait.gd`, `rs_ai_action_scan.gd`, `rs_ai_action_animate.gd`, `rs_ai_action_publish_event.gd`, `rs_ai_action_set_field.gd`
  - `scripts/ecs/systems/s_ai_behavior_system.gd` — replace local `ACTION_STARTED_STATE_KEY` with `U_AITaskStateKeys.ACTION_STARTED`
  - `scripts/ecs/systems/s_ai_navigation_system.gd` — replace local `TARGET_STATE_KEY`/`ARRIVAL_THRESHOLD_STATE_KEY` with `U_AITaskStateKeys.*`

**R2 Verification**:
- [ ] All new key/base tests green
- [ ] Grep-based magic-string test green
- [ ] Existing AI integration suite green
- [ ] `test_style_enforcement.gd` passes

**R2 Completion Notes**: _(to be filled during execution)_

---

## Milestone R3: Split `s_ai_behavior_system.gd` Into Collaborators

**Goal**: Carve the 771-line system into four composable `RefCounted` utilities, each under ~200 lines and unit-testable without a running ECS manager. `s_ai_behavior_system.gd` retains orchestration only; the heavy lifting moves to util classes.

- [ ] **Commit 1** — Create util tests (TDD RED):
  - `tests/unit/ai/test_u_ai_goal_selector.gd`:
    - `test_selects_highest_scoring_goal`
    - `test_ties_broken_by_priority`
    - `test_falls_back_to_default_goal`
    - `test_applies_cooldown_gate`
    - `test_applies_one_shot_gate`
    - `test_applies_rising_edge_gate`
    - `test_executing_goal_bypasses_cooldown_gate`
  - `tests/unit/ai/test_u_ai_task_runner.gd`:
    - `test_tick_starts_action_on_first_call`
    - `test_tick_invokes_action_tick`
    - `test_advances_on_complete`
    - `test_finishes_queue_and_clears_state`
    - `test_skips_invalid_primitive_tasks`
  - `tests/unit/ai/test_u_ai_replanner.gd`:
    - `test_replan_decomposes_root_task`
    - `test_suspend_current_goal_saves_queue`
    - `test_restore_suspended_queue_on_reentry`
    - `test_no_replan_when_same_goal_and_queue_nonempty`
  - `tests/unit/ai/test_u_ai_context_builder.gd`:
    - `test_builds_context_with_redux_state_snapshot`
    - `test_includes_entity_and_entity_id`
    - `test_includes_components_dict`
    - `test_handles_missing_store_gracefully`
- [ ] **Commit 2** — Implement extracted utils (TDD GREEN):
  - `scripts/utils/ai/u_ai_goal_selector.gd` (`class_name U_AIGoalSelector extends RefCounted`) — owns `select(brain_settings, context, tracker, executing_goal_id)`, internal `_build_rule_from_goal`, `_apply_state_gates`, `_find_goal_by_id`, `_rule_pool`, `_goal_by_id_cache`
  - `scripts/utils/ai/u_ai_task_runner.gd` (`class_name U_AITaskRunner extends RefCounted`) — owns `tick(brain, delta, context)`, internal `_advance_to_next_task`, `_finish_task_queue`
  - `scripts/utils/ai/u_ai_replanner.gd` (`class_name U_AIReplanner extends RefCounted`) — owns `replan_for_goal(brain, goal, context)`, `_suspend_current_goal`, `_read_suspended_state`; composes `U_HTNPlanner`
  - `scripts/utils/ai/u_ai_context_builder.gd` (`class_name U_AIContextBuilder extends RefCounted`) — owns `build(entity_query, brain, redux_state, store, manager)`, `context_key_for_context(context)`
- [ ] **Commit 3** — Refactor `s_ai_behavior_system.gd` to compose the new utils. Leave goal-fired cooldown bookkeeping and debug logging in place for now (R4 removes debug; R10 is the final cleanup pass).

**R3 Verification**:
- [ ] All new util tests green
- [ ] `test_s_ai_behavior_system_goals.gd` green (no behavior change)
- [ ] `test_ai_pipeline_integration.gd` green
- [ ] `s_ai_behavior_system.gd` LOC reduced; measured and recorded in completion notes
- [ ] `test_style_enforcement.gd` passes

**R3 Completion Notes**: _(to be filled during execution)_

---

## Milestone R4: Extract Debug Probe + Log Throttle Utilities

**Goal**: Remove ~200 lines of duplicated debug/probe code. `_build_render_probe(...)` is copy-pasted between `s_ai_behavior_system.gd` and `s_ai_navigation_system.gd` (verified: both files define the helper with the same body). The simpler `_find_character_body_recursive` helper is additionally duplicated in `scripts/ecs/components/c_movement_component.gd` and `scripts/ecs/systems/helpers/u_vcam_runtime_context.gd` — the new `U_AIRenderProbe` utility should expose `_find_character_body_recursive` as a `static` helper that those two non-AI call sites can also adopt during the R4 stretch commit. Six systems reinvent `_tick_debug_log_cooldowns`: `s_ai_behavior_system.gd`, `s_ai_navigation_system.gd`, `s_ai_spawn_recovery_system.gd`, `s_floating_system.gd`, `s_gravity_system.gd`, `s_movement_system.gd` (verified via grep). Consolidate both.

- [ ] **Commit 1** — Create debug util tests (TDD RED):
  - `tests/unit/utils/debug/test_u_debug_log_throttle.gd`:
    - `test_consume_budget_returns_true_when_cooldown_zero`
    - `test_consume_budget_returns_false_during_cooldown`
    - `test_tick_decrements_cooldowns`
    - `test_multiple_keys_tracked_independently`
    - `test_clear_resets_all_keys`
  - `tests/unit/utils/debug/test_u_ai_render_probe.gd`:
    - `test_build_render_probe_null_safe_on_missing_body`
    - `test_build_render_probe_null_safe_on_missing_visual`
    - `test_build_render_probe_reports_body_position`
    - `test_build_render_probe_reports_visual_transparency_when_geometry`
- [ ] **Commit 2** — Implement debug utils (TDD GREEN):
  - `scripts/utils/debug/u_debug_log_throttle.gd` (`class_name U_DebugLogThrottle extends RefCounted`) — `consume_budget(key: StringName, interval_sec: float) -> bool`, `tick(delta: float) -> void`, `clear() -> void`
  - `scripts/utils/debug/u_ai_render_probe.gd` (`class_name U_AIRenderProbe extends RefCounted`) — `static func build_probe_string(entity: Node, body: CharacterBody3D, movement_component: C_MovementComponent) -> String`; internal `_resolve_visual_node`, `_find_character_body_recursive`, `_find_first_geometry_recursive`
- [ ] **Commit 3** — Migrate call sites (TDD GREEN):
  - `scripts/ecs/systems/s_ai_behavior_system.gd` — delete inline `_build_render_probe`, `_resolve_body_from_context`, `_resolve_visual_node`, `_find_character_body_recursive`, `_find_first_geometry_recursive`, `_debug_log_cooldowns` bookkeeping, `_tick_debug_log_cooldowns`. Use `U_DebugLogThrottle` and `U_AIRenderProbe` instead.
  - `scripts/ecs/systems/s_ai_navigation_system.gd` — same delete-and-replace pass
- [ ] **Commit 4** (stretch, optional within R4) — migrate other systems with `_tick_debug_log_cooldowns` to `U_DebugLogThrottle`: `s_floating_system.gd`, `s_gravity_system.gd`, `s_movement_system.gd`, `s_ai_spawn_recovery_system.gd`. Also migrate the `_find_character_body_recursive` duplicates in `scripts/ecs/components/c_movement_component.gd` and `scripts/ecs/systems/helpers/u_vcam_runtime_context.gd` to `U_AIRenderProbe.find_character_body_recursive(...)` (or promote that helper to a separate `U_NodeFind` utility if you'd rather not couple non-AI code to an `AI`-named util — recommended if the stretch commit runs).

**R4 Verification**:
- [ ] All new debug util tests green
- [ ] Existing AI behavior/navigation tests green
- [ ] Line count of `s_ai_behavior_system.gd` and `s_ai_navigation_system.gd` reduced; measured and recorded in completion notes
- [ ] `test_ai_pipeline_integration.gd` green
- [ ] `test_style_enforcement.gd` passes

**R4 Completion Notes**: _(to be filled during execution)_

---

## Milestone R5: Share Spawn Recovery Between Player and NPCs

**Goal**: Today the player has no "falling off-map" recovery, and `s_ai_spawn_recovery_system.gd` is NPC-only. Promote the recovery logic to a shared ECS system so both player and NPCs can use it. `RS_AIBrainSettings` currently carries `respawn_spawn_point_id`, `respawn_unsupported_delay_sec`, `respawn_recovery_cooldown_sec` — those belong on a dedicated settings resource, not the AI brain.

- [ ] **Commit 1** — Create shared recovery tests (TDD RED):
  - `tests/unit/ecs/components/test_c_spawn_recovery_component.gd`:
    - `test_component_type_constant`
    - `test_settings_export_assignable`
    - `test_validates_required_settings_with_rs_spawn_recovery_settings`
  - `tests/unit/ecs/systems/test_s_spawn_recovery_system.gd`:
    - `test_entity_unsupported_beyond_delay_triggers_respawn`
    - `test_startup_grace_period_prevents_early_recovery`
    - `test_recovery_cooldown_prevents_spam`
    - `test_supported_entity_clears_unsupported_timer`
    - `test_player_entity_respawned_via_shared_system`
    - `test_npc_entity_respawned_via_shared_system`
- [ ] **Commit 2** — Implement new component/settings/system (TDD GREEN):
  - `scripts/resources/ecs/rs_spawn_recovery_settings.gd` — `class_name RS_SpawnRecoverySettings`, fields `spawn_point_id: StringName`, `unsupported_delay_sec: float = 0.6`, `recovery_cooldown_sec: float = 1.0`, `startup_grace_period_sec: float = 1.0`
  - `scripts/ecs/components/c_spawn_recovery_component.gd` — `class_name C_SpawnRecoveryComponent extends BaseECSComponent`, `@export var settings: RS_SpawnRecoverySettings`, `_validate_required_settings()` requires non-null settings
  - `scripts/ecs/systems/s_spawn_recovery_system.gd` — `class_name S_SpawnRecoverySystem extends BaseECSSystem`, queries `[C_SpawnRecoveryComponent, C_FloatingComponent, C_MovementComponent, C_InputComponent]`, delegates actual respawn to `U_SERVICE_LOCATOR.try_get_service(&"spawn_manager") as I_SpawnManager`
- [ ] **Commit 3** — Migrate existing NPC recovery (TDD GREEN):
  - `scripts/ecs/systems/s_ai_spawn_recovery_system.gd` — **delete** after verifying `s_spawn_recovery_system.gd` covers all prior behavior
  - `scripts/resources/ai/rs_ai_brain_settings.gd` — remove `respawn_spawn_point_id`, `respawn_unsupported_delay_sec`, `respawn_recovery_cooldown_sec` fields
  - `resources/ai/patrol_drone/cfg_patrol_drone_brain.tres` is currently the **only** brain resource that populates the three `respawn_*` fields with non-default values (verified via grep). Before deleting the fields on `rs_ai_brain_settings.gd`, create a sibling `resources/ai/patrol_drone/cfg_patrol_drone_spawn_recovery.tres` that carries those values into an `RS_SpawnRecoverySettings` instance.
  - `resources/ai/sentry/cfg_sentry_brain.tres`, `resources/ai/guide_prism/cfg_guide_brain.tres`, `resources/ai/guide_prism/cfg_guide_showcase_brain.tres`, `resources/ai/cfg_ai_brain_placeholder.tres` — rely on defaults; create empty/default `RS_SpawnRecoverySettings` companions only if the prefab wiring explicitly needs them. Re-save each `.tres` after the field removal so Godot drops the now-unknown properties cleanly.
  - `scenes/prefabs/prefab_demo_npc.tscn` — add `C_SpawnRecoveryComponent` child referencing the new settings resource
  - `scenes/prefabs/prefab_player.tscn` — add `C_SpawnRecoveryComponent` wired with a player-specific `RS_SpawnRecoverySettings` (spawn point resolved from active scene's spawn registry). `scenes/templates/tmpl_character.tscn` is the shared character template — decide during execution whether to attach the component there (applies to every character inheritor automatically) or only to `prefab_player.tscn` + `prefab_demo_npc.tscn` (explicit opt-in). Explicit opt-in is recommended because each NPC archetype needs different tuning.
- [ ] **Commit 4** — Add integration test that a player dropped below a death plane respawns to the current scene's player spawn point

**R5 Verification**:
- [ ] All new recovery tests green
- [ ] Existing NPC recovery behavior preserved end-to-end (`tests/integration` + demo scene smoke run)
- [ ] Player falls below death plane and is respawned (new integration test)
- [ ] No remaining references to `s_ai_spawn_recovery_system` in the repo
- [ ] `test_style_enforcement.gd` passes

**R5 Completion Notes**: _(to be filled during execution)_

---

## Milestone R6: Generalize the Move-Target Navigation Bridge

**Goal**: `s_ai_navigation_system.gd` is effectively a generic "follow a Vector3 by writing `move_vector` into `C_InputComponent`" bridge. It's hard-coded to AI. Rename it and promote it so player-driven scripted sequences (cinematic moves, auto-walk segments) can also drop a target into a dedicated component and get the behavior for free.

- [ ] **Commit 1** — Create follower tests (TDD RED):
  - `tests/unit/ecs/components/test_c_move_target_component.gd`:
    - `test_component_type_constant`
    - `test_target_position_default_zero`
    - `test_arrival_threshold_default`
    - `test_is_active_toggle`
  - `tests/unit/ecs/systems/test_s_move_target_follower_system.gd`:
    - `test_non_ai_entity_moves_toward_target` (no `C_AIBrainComponent` present)
    - `test_writes_zero_move_vector_within_arrival_threshold`
    - `test_reads_ai_brain_task_state_when_move_target_component_absent_back_compat`
    - `test_prefers_move_target_component_when_both_sources_present`
    - `test_per_entity_throttle_honored`
- [ ] **Commit 2** — Implement follower (TDD GREEN):
  - `scripts/ecs/components/c_move_target_component.gd` — `class_name C_MoveTargetComponent extends BaseECSComponent`, `@export var target_position: Vector3`, `@export var arrival_threshold: float = 0.5`, `@export var is_active: bool = false`
  - `scripts/ecs/systems/s_move_target_follower_system.gd` — `class_name S_MoveTargetFollowerSystem extends BaseECSSystem`. Queries `[C_InputComponent, C_MovementComponent]` then branches: if entity has `C_MoveTargetComponent.is_active`, use its target; else if entity has `C_AIBrainComponent` with `task_state[U_AITaskStateKeys.MOVE_TARGET]` set, use that (back-compat path); else write `Vector2.ZERO`
- [ ] **Commit 3** — Migrate call sites and delete old system (TDD GREEN):
  - Six `.tscn` files reference `s_ai_navigation_system` today (verified via grep): `scenes/gameplay/gameplay_ai_showcase.tscn`, `gameplay_power_core.tscn`, `gameplay_comms_array.tscn`, `gameplay_nav_nexus.tscn`, `gameplay_base.tscn`, and `scenes/templates/tmpl_base_scene.tscn`. Update all six to instance `s_move_target_follower_system` instead. The template-scene change is the important one — once `tmpl_base_scene.tscn` is updated, inherited scenes pick it up automatically.
  - `scripts/ecs/systems/s_ai_navigation_system.gd` — **delete** after verification
  - `tests/unit/ecs/systems/test_s_ai_navigation_system.gd` — rename to `test_s_move_target_follower_system.gd` and update its target/assertions
  - `scripts/resources/ai/actions/rs_ai_action_move_to.gd` — keep writing to `task_state[U_AITaskStateKeys.MOVE_TARGET]` for now; the back-compat path in the follower system handles it. Mark a TODO for a follow-up milestone that routes the action through `C_MoveTargetComponent` directly if/when every AI entity has one.

**R6 Verification**:
- [ ] All new follower tests green
- [ ] Existing AI navigation tests green (back-compat path)
- [ ] Non-AI entity follower smoke test: dropped a player entity with a `C_MoveTargetComponent` into a scene and watched it walk
- [ ] No remaining references to `s_ai_navigation_system` in the repo
- [ ] `test_style_enforcement.gd` passes

**R6 Completion Notes**: _(to be filled during execution)_

---

## Milestone R7: Reorganize `scripts/resources/ai/` Directory

**Goal**: Tasks, goals, and brain settings currently live at the top level while actions are in an `actions/` subfolder. Nest everything by concept.

- [ ] **Commit 1** — Add style enforcement test (TDD RED):
  - Extend `tests/unit/style/test_style_enforcement.gd`: assert every file matching `scripts/resources/ai/rs_ai_*.gd` lives under `brain/`, `goals/`, `tasks/`, or `actions/`
- [ ] **Commit 2** — Mechanical move + preload updates (TDD GREEN):
  - `scripts/resources/ai/rs_ai_brain_settings.gd` → `scripts/resources/ai/brain/rs_ai_brain_settings.gd`
  - `scripts/resources/ai/rs_ai_goal.gd` → `scripts/resources/ai/goals/rs_ai_goal.gd`
  - `scripts/resources/ai/rs_ai_task.gd` → `scripts/resources/ai/tasks/rs_ai_task.gd`
  - `scripts/resources/ai/rs_ai_primitive_task.gd` → `scripts/resources/ai/tasks/rs_ai_primitive_task.gd`
  - `scripts/resources/ai/rs_ai_compound_task.gd` → `scripts/resources/ai/tasks/rs_ai_compound_task.gd`
  - Carry the `.uid` files alongside
  - Update every `preload("res://scripts/resources/ai/...")` call-site across `scripts/`, `tests/`, and `resources/ai/*.tres` `[ext_resource]` entries

**R7 Verification**:
- [ ] New style test green
- [ ] All existing tests green
- [ ] No broken `preload` or `ext_resource` references (`tools/run_gut_suite.sh` clean)

**R7 Completion Notes**: _(to be filled during execution)_

---

## Milestone R8: Move Demo-Only Systems Out of Production `systems/`

**Goal**: `s_ai_demo_alarm_relay_system.gd` is Signal Lost–specific. It doesn't belong next to production AI systems.

- [ ] **Commit 1** — Add style enforcement test (TDD RED):
  - Extend `tests/unit/style/test_style_enforcement.gd`: assert no file matching `scripts/ecs/systems/*.gd` contains `_demo_` in its filename
- [ ] **Commit 2** — Move file and update wiring (TDD GREEN):
  - `scripts/ecs/systems/s_ai_demo_alarm_relay_system.gd` → `scripts/gameplay/s_demo_alarm_relay_system.gd`. Rationale: the existing convention already groups demo-specific gameplay scripts flat under `scripts/gameplay/` (see `inter_ai_demo_flag_zone.gd`, `inter_ai_demo_guard_barrier.gd`). Introducing a new `demo_signal_lost/` subfolder would break that convention — avoid it unless that reorganization is its own separate milestone. Verify the style test rule covers the new location.
  - Caveat: `scripts/gameplay/` currently holds interactable controllers (`inter_*.gd`, `base_*.gd`). An ECS `System` at that level is a new shape. If the style test enforces "no `s_*.gd` files under `scripts/gameplay/`", relax it or create `scripts/gameplay/ecs_systems/` as a subfolder — decide at R8 execution time, not speculatively.
  - Rename class to `S_DemoAlarmRelaySystem`
  - Update scene wiring: `s_ai_demo_alarm_relay_system` is referenced **only** by `scenes/gameplay/gameplay_ai_showcase.tscn` (verified via grep — *not* `gameplay_comms_array.tscn`). Update just that one scene.
  - Update `.uid` references and rename the sibling test file `tests/unit/ecs/systems/test_s_ai_demo_alarm_relay_system.gd` → `tests/unit/gameplay/test_s_demo_alarm_relay_system.gd`

**R8 Verification**:
- [ ] New style test green
- [ ] `test_ai_pipeline_integration.gd` green
- [ ] Comms array demo scene loads and alarm relay fires as before

**R8 Completion Notes**: _(to be filled during execution)_

---

## Milestone R9: HTN Planner Context Object

**Goal**: `u_htn_planner.gd` currently threads `reusable_rule`, `recursion_stack`, `result`, `max_depth`, `depth` through every recursive call. Collapse them into a single context `RefCounted` so internals are tidy. Public signature stays stable.

- [ ] **Commit 1** — Add internal-coverage tests (TDD RED if any gap exists; otherwise mark GREEN):
  - `tests/unit/ai/test_u_htn_planner.gd` — confirm existing 8 tests still green; add `test_reusable_rule_is_not_mutated_between_calls` if not already present
- [ ] **Commit 2** — Refactor internals (TDD GREEN):
  - `scripts/utils/ai/u_htn_planner.gd` — introduce inner `class PlannerContext` (or a top-level `U_HTNPlannerContext` under `scripts/utils/ai/`) carrying `reusable_rule`, `recursion_stack`, `result`, `max_depth`, `depth`. Keep public `static func decompose(task, context, max_depth)` identical.

**R9 Verification**:
- [ ] All planner tests green with zero behavioral change
- [ ] Line count of `u_htn_planner.gd` internal recursive helper reduced

**R9 Completion Notes**: _(to be filled during execution)_

---

## Milestone R10: Behavior System Orchestration Integration Pass

**Goal**: Final cleanup. After R1–R9 have landed, `s_ai_behavior_system.gd` should be a thin orchestrator that builds per-entity context, asks the goal selector for a winner, asks the replanner to replan if the winner changed, and asks the task runner to tick. Delete every remaining duck-typing helper (`_read_object_property`, `_read_int_property`, `_read_bool_property`, `_read_float_property`, `_variant_to_string_name`) — they should have no call sites left **within `s_ai_behavior_system.gd`**.

**Scope note**: The same duck-typing helper family is used elsewhere in the codebase (`s_camera_state_system.gd`, `s_character_state_system.gd`, `s_game_event_system.gd`, `u_vcam_runtime_context.gd`, `u_vcam_landing_impact.gd`, `u_rule_scorer.gd`, `u_rule_selector.gd`, `u_rule_validator.gd`). Global removal is **out of scope** for this AI refactor — the R10 grep test must be scoped narrowly to `s_ai_behavior_system.gd` only, otherwise it will fail the first time it runs. A follow-up "project-wide duck-typing removal" initiative can tackle the QB/camera/character systems once this refactor lands.

- [ ] **Commit 1** — Confirm no remaining duck-typing call sites (TDD RED):
  - Grep-based test in `test_style_enforcement.gd`: assert `scripts/ecs/systems/s_ai_behavior_system.gd` does not contain `_read_object_property`, `_read_int_property`, `_read_bool_property`, `_read_float_property`, or `_variant_to_string_name`
- [ ] **Commit 2** — Rewrite orchestrator (TDD GREEN):
  - `scripts/ecs/systems/s_ai_behavior_system.gd` target: under 200 lines. Imports `U_AIGoalSelector`, `U_AITaskRunner`, `U_AIReplanner`, `U_AIContextBuilder`, `U_AIRenderProbe`, `U_DebugLogThrottle`, `U_AITaskStateKeys`. `process_tick` becomes: (1) tick debug throttle + rule state tracker, (2) query brain entities, (3) build frame snapshot, (4) loop entities — for each: `U_AIContextBuilder.build(...)`, `U_AIGoalSelector.select(...)`, `U_AIReplanner.replan_for_goal(...)` when the winner changes, `U_AITaskRunner.tick(...)`, debug log dispatch.
- [ ] **Commit 3** — Delete all duck-typing helpers and any other now-unused private methods

**R10 Verification**:
- [ ] Grep test green (no duck-typing helpers remain)
- [ ] `test_ai_pipeline_integration.gd` green
- [ ] All milestone-specific test suites green
- [ ] `s_ai_behavior_system.gd` final line count under 200, measured and recorded
- [ ] Full-suite regression green
- [ ] `test_style_enforcement.gd` passes

**R10 Completion Notes**: _(to be filled during execution)_

---

## Global Verification Checklist (run after every milestone)

1. `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/integration/test_ai_pipeline_integration.gd` green
2. `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` green
3. `tools/run_gut_suite.sh` full-suite regression green (baseline pass/fail counts recorded in completion notes)
4. Demo scenes smoke-loaded and the 3 archetypes (Patrol Drone, Sentry, Guide Prism) behave as designed
5. No new `TODO` markers left behind without a referenced follow-up milestone

## Files Touched by Milestone (quick index)

| Milestone | Primary files |
|-----------|---------------|
| R1 | `c_ai_brain_component.gd`, `rs_ai_brain_settings.gd`, `rs_ai_goal.gd`, `rs_ai_task.gd`, `rs_ai_primitive_task.gd`, `rs_ai_compound_task.gd` |
| R2 | `u_ai_task_state_keys.gd` *(new)*, `i_ai_action.gd`, all `rs_ai_action_*.gd`, `s_ai_behavior_system.gd`, `s_ai_navigation_system.gd` |
| R3 | `u_ai_goal_selector.gd` *(new)*, `u_ai_task_runner.gd` *(new)*, `u_ai_replanner.gd` *(new)*, `u_ai_context_builder.gd` *(new)*, `s_ai_behavior_system.gd` |
| R4 | `u_debug_log_throttle.gd` *(new)*, `u_ai_render_probe.gd` *(new)*, `s_ai_behavior_system.gd`, `s_ai_navigation_system.gd` |
| R5 | `c_spawn_recovery_component.gd` *(new)*, `rs_spawn_recovery_settings.gd` *(new)*, `s_spawn_recovery_system.gd` *(new)*, `s_ai_spawn_recovery_system.gd` *(delete)*, `rs_ai_brain_settings.gd`, all NPC brain `.tres` files, `prefab_demo_npc.tscn`, player prefab/template |
| R6 | `c_move_target_component.gd` *(new)*, `s_move_target_follower_system.gd` *(new)*, `s_ai_navigation_system.gd` *(delete)*, gameplay `.tscn` files |
| R7 | every `scripts/resources/ai/rs_ai_*.gd` *(move)*, every `.tres` and `preload()` referencing them |
| R8 | `s_ai_demo_alarm_relay_system.gd` *(move/rename)*, `gameplay_comms_array.tscn` |
| R9 | `u_htn_planner.gd` |
| R10 | `s_ai_behavior_system.gd` |

## Links

- [AI System Overview](ai-system-overview.md)
- [AI System Plan](ai-system-plan.md)
- [AI System Tasks (M1–M15)](ai-system-tasks.md)
- [AI System Continuation Prompt](ai-system-continuation-prompt.md)
