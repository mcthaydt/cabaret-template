# Cross-System Cleanup V7.2 — Implementation Guide & Continuation Prompt

## Overview

This guide directs you to implement Cross-System Cleanup V7.2 by following the tasks outlined in `docs/general/cleanup_v7/cleanup-v7.2-tasks.md` in sequential order, respecting the dependency graph documented below. V7.2 is the follow-up to V7 (C1–C12), addressing eight concrete architectural weaknesses that C1–C12 did not target, plus three additions (F8 Phase 0, F12, F15) surfaced during pre-implementation review.

**Branch**: GOAP-AI
**Status**: Not started — queued after cleanup-v7 C12 (`post-process-refactor-tasks.md`) lands and regression passes.
**Next Task**: Begin **F1 verification** (single commit confirming SceneManager C6 gaps are closed), then proceed to **F2** (StateStore Dispatch — Share Snapshot Across Subscribers) per `docs/general/cleanup_v7/cleanup-v7.2-tasks.md`.
**Prerequisite**: Full C1–C12 test suite green (desktop + mobile) before starting F2.

---

## Current Status: Not Started

All milestones are pending. The task file `docs/general/cleanup_v7/cleanup-v7.2-tasks.md` is the authoritative source for commit-level checklists; this continuation prompt is a working index and context bank.

- **F1 (SceneManager C6 Supplement)**: **ALREADY RESOLVED** during C6. Verification-only checkpoint (single commit adding style-enforcement grep assertions).
- **F2 (StateStore Dispatch — Share Snapshot)**: NOT STARTED.
- **F3 (StateStore — Eliminate Parallel Mutation Paths)**: NOT STARTED.
- **F4 (Slice Dependency Validator — Strict Mode)**: NOT STARTED. **Behavior-change commit gated (Commit 5 flips default to strict).**
- **F5 (Communication Channel Taxonomy)**: NOT STARTED. Depends on F3. Requires creating `docs/adr/` directory.
- **F6 (ServiceLocator Scoping)**: NOT STARTED.
- **F7 (RS_Rule Typed-Schema Erasure)**: NOT STARTED. Gated on one-commit parser feasibility investigation (Path A vs Path B).
- **F8 (VCam + CameraState Decomposition — **Expanded v7.2.1**)**: NOT STARTED. **Phase 0 (Commits 1a/1b) decomposes oversized helpers before Phase 1+ pushes system logic into them.**
- **F9 (ECS System Execution Phasing)**: NOT STARTED. Extends existing `execution_priority` system.
- **F10 (State Store History Truncation)**: **ALREADY IMPLEMENTED**. Verification-only checkpoint.
- **F11 (Event Bus Zombie Prevention)**: NOT STARTED. Scope is `BaseEventBus`, not the `U_ECSEventBus` facade.
- **F12 (Settings Overlay Deduplication — v7.2.1 Addition)**: NOT STARTED. Independent, trivial DRY collapse.
- **F15 (Designer-Facing Resource Schema Validation — v7.2.1 Addition)**: NOT STARTED. Mirrors F7's pattern for three more resources.

---

## v7.2.1 Patch (Pre-Implementation Review Additions)

Before execution begins, the v7.2 plan received three additions and one rejection. All are documented in `cleanup-v7.2-tasks.md`:

- **F8 expanded (Phase 0)**: Original F8 would have pushed system logic into 800+ line helpers. Phase 0 decomposes `u_vcam_rotation.gd` (740 → three ~80/90/180-line files) and `u_vcam_orbit_effects.gd` (650 → three ~110-line files + 80-line residual) **before** Phase 1+ extracts system-level logic. `u_vcam_response_smoother.gd` (468 lines) is coherent and explicitly left alone.
- **F12 added**: Three settings overlay wrappers (`ui_audio_settings_overlay.gd`, `ui_display_settings_overlay.gd`, `ui_localization_settings_overlay.gd`) are 53 lines each, character-for-character identical except `class_name`. Collapsed into a single `base_settings_simple_overlay.gd`. `ui_vfx_settings_overlay.gd` is legitimately different (Apply/Cancel + inline controls) and stays out of scope.
- **F15 added**: Load-time schema validation for `RS_GameConfig` (HIGH risk — zero validation on `retry_scene_id`, `route_retry`, `default_objective_set_id`, `required_final_area`), `RS_InputProfile` (MEDIUM risk — malformed `virtual_buttons` entries), `RS_SceneRegistryEntry` (MEDIUM risk — editor-only warnings, no load-time enforcement). `RS_UIThemeConfig` is out of scope because `ensure_runtime_defaults()` already prevents crash-level failures.
- **F13/F14 rejected**: Pre-implementation audit verified `_character_lighting_history`, `_character_zone_hysteresis`, `S_WallVisibilitySystem` geometry caches, `U_SceneCache`, and `_scene_history` **all have proper cleanup** (per-character pruning, per-frame stale eviction, LRU + 100MB cap, clear on gameplay entry). No memory-leak milestone needed.

---

## Problem Statement

Eight concrete weaknesses surfaced during a deep-dive architectural review after C1–C12:

1. **~~Cross-manager reflection hole~~** — Resolved during C6.
2. **Per-dispatch full-state deep copy floor** in `M_StateStore.dispatch()` that bypasses the versioned cache. Per-frame cost floor for every subscriber.
3. **Two parallel mutation paths** that bypass the reducer/history/validator pipeline (`_sync_navigation_initial_scene` direct mutation + four direct `slice_updated.emit` sites).
4. **Advisory-only slice-dependency validator** that fails open — declarations drift silently out of sync.
5. **Unresolved communication-channel taxonomy** (Redux vs `U_ECSEventBus` vs Godot signals) driving most "contract-by-comment" growth in `AGENTS.md`.
6. **Process-global `U_ServiceLocator` state** with last-write-wins `register()` and no per-test scope — root cause of multiple recurring test-failure patterns in `MEMORY.md`.
7. **Type erasure on `RS_Rule.conditions`/`effects: Array[Resource]`** — authoring errors surface as silent runtime "rule scored 0.0" with no stack trace.
8. **Two more large ECS systems** (`s_vcam_system.gd` at 551 lines, `s_camera_state_system.gd` at 587 lines) not targeted by C5.

The doc closes with a non-numbered reflection on `AGENTS.md` sprawl (not a milestone — revisit after F1–F8 land).

---

## Milestone F1: SceneManager C6 Supplement — ALREADY RESOLVED

**Goal**: Verification-only checkpoint. Both original gaps (reflection hole + Array-wrapper captures) were resolved during C6.

- [ ] **Commit 1** (VERIFY) — Add style-enforcement grep assertions in `tests/unit/style/test_style_enforcement.gd`:
  - `m_scene_manager.gd` contains zero matches of `_camera_blend_tween`.
  - `m_scene_manager.gd` contains zero matches of `get("_camera_blend_tween")`.
  - `_perform_transition` under 40 lines.

**F1 Verification**:
- [ ] Style enforcement tests green.
- [ ] Existing scene-transition integration tests green.

---

## Milestone F2: StateStore Dispatch — Share Snapshot Across Subscribers

**Goal**: Eliminate the per-dispatch full-state deep copy at `m_state_store.gd:471` by using the store's existing versioned cache. With 16 slices and per-frame dispatches, this is a per-frame cost floor.

- [ ] **Commit 1** (RED) — Dispatch-path tests: 5-subscriber reference identity, zero-subscriber skip, 1000-action benchmark.
- [ ] **Commit 2** (GREEN) — Refactor `dispatch()` to use cached `get_state()`. Document the read-only subscriber contract.
- [ ] **Commit 3** (GREEN) — Skip the snapshot build entirely when `_subscribers.is_empty()`.

**F2 Verification**:
- [ ] All new tests green.
- [ ] Dispatch benchmark shows one `duplicate(true)` per dispatch with subscribers, zero without.
- [ ] Existing store/reducer tests green.
- [ ] No observable behavior change for subscribers.

---

## Milestone F3: StateStore — Eliminate Parallel Mutation Paths

**Goal**: All mutations to `_state` must flow through `dispatch()` so that action history, version bumping, validator, and signal batching stay consistent.

- [ ] **Commit 1** (RED) — Invariant tests: `_sync_navigation_initial_scene` produces `action_dispatched`; every `slice_updated` pairs with `action_dispatched`; action history count matches slice observer count.
- [ ] **Commit 2** (GREEN) — Add `U_NavigationActions.sync_initial_scene(scene_id)` + reducer branch; replace direct mutation.
- [ ] **Commit 3** (GREEN) — Audit `slice_updated.emit` sites at `:259, :486, :636, :684`. Each must be reachable only from the batched flush path, OR replaced with a reducer-chain dispatch, OR annotated with an explicit invariant comment.
- [ ] **Commit 4** (GREEN) — Grep-based style test forbidding `_state[` mutations outside `m_state_store.gd` utility paths and reducers.

**F3 Verification**:
- [ ] No `slice_updated` emission without a paired `action_dispatched` in the same frame.
- [ ] `_sync_navigation_initial_scene` no longer directly mutates `_state`.
- [ ] `action_history_buffer` count matches `slice_updated` observer count.
- [ ] Grep test green.
- [ ] Existing store tests green.

---

## Milestone F4: Slice Dependency Validator — Strict Mode

**Goal**: The slice-dependency check at `m_state_store.gd:565-573` currently logs an error but **still returns the data**. Add strict-mode toggle, audit + fix violations, then flip default.

- [ ] **Commit 1** (RED) — Strict-mode tests for both modes.
- [ ] **Commit 2** (GREEN) — Add `strict_slice_dependencies: bool = false` to `RS_StateStoreSettings`. Implement strict branch.
- [ ] **Commit 3** (GREEN) — Audit: enable strict mode at test-harness level, catalog every violation into a scratch file. No fixes yet.
- [ ] **Commit 4** (GREEN) — Fix each cataloged violation (declare missing dependency or refactor undeclared access).
- [ ] **Commit 5** (GREEN, **BEHAVIOR CHANGE**) — Flip `strict_slice_dependencies` default to `true`.

**F4 Verification**:
- [ ] Strict-mode tests green.
- [ ] Full test suite green with strict mode as default.
- [ ] Zero `push_error` for undeclared slice access during normal gameplay boot + main-menu round-trip.

**⚠ Commit 5 is the one explicit behavior-change commit in F4.** Run full suite before landing.

---

## Milestone F5: Communication Channel Taxonomy

**Goal**: Pick one channel per concern and document the rule in an ADR. Redux for durable state, `U_ECSEventBus` for fire-and-forget transients, Godot signals for intra-component/manager wiring.

- [ ] **Commit 1** (RED) — Style enforcement tests for the channel rule (start failing).
- [ ] **Commit 2** (GREEN) — Create `docs/adr/` directory (does not exist yet). Write `docs/adr/0001-channel-taxonomy.md`. Add pointer to `AGENTS.md`.
- [ ] **Commit 3** (GREEN) — Audit and migrate violations. Update allow-list for documented intentional exceptions.
- [ ] **Commit 4** (GREEN) — Enable grep tests in CI. Zero violations at land.

**F5 Verification**:
- [ ] ADR written and linked from `AGENTS.md`.
- [ ] Style enforcement grep tests green.
- [ ] At least one concrete migration committed (candidate: `m_scene_manager` victory routing — consolidate Redux/ECS-bus/signal trio into one channel).
- [ ] Existing test suite green.

**Dependency note**: Depends on F3 (parallel mutation paths removed) so the "Redux is the only state channel" rule is enforceable without exception.

---

## Milestone F6: ServiceLocator — Globality, Test Pollution, Last-Write-Wins

**Goal**: Fix two structural problems with `U_ServiceLocator._services`: last-write-wins `register()` and no test scope (root cause of multiple recurring test-failure patterns in `MEMORY.md`).

- [ ] **Commit 1** (RED) — Conflict test + scope-isolation test.
- [ ] **Commit 2** (GREEN) — Implement fail-on-conflict `register()` + `register_or_replace()`. Audit `root.gd:50-78` for idempotency.
- [ ] **Commit 3** (GREEN) — Implement `push_scope` / `pop_scope`. Migrate `BaseTest` to use scope push/pop instead of `clear()`. Update UI tests that call `clear()` directly.
- [ ] **Commit 4** (GREEN) — Migrate `U_StateHandoff` and `M_DisplayManager._ensure_appliers()` follow-ups to the scope pattern where applicable.

**F6 Verification**:
- [ ] Duplicate-register test green.
- [ ] Scope-isolation test green.
- [ ] Full test suite green with `clear()` calls removed from `BaseTest.after_each()`.
- [ ] `MEMORY.md` test-failure patterns for `U_StateHandoff` and `_ensure_appliers` no longer manifest.

---

## Milestone F7: `RS_Rule` Typed-Schema Erasure

**Goal**: Replace `Array[Resource]` fallback on `RS_Rule.conditions`/`effects` with typed arrays OR a load-time schema validator (whichever the Godot 4.6 parser supports).

- [ ] **Commit 1** (INVESTIGATION) — Parser feasibility probe (Path A vs Path B). Document decision in milestone notes.
- [ ] **Commit 2** (RED) — Tests for the chosen path.
- [ ] **Commit 3** (GREEN) — Implement chosen path (typed arrays OR load-time validator).
- [ ] **Commit 4** (GREEN) — Remove "Fallback for headless parser stability" comment. For Path A, delete now-dead runtime type-check branches. For Path B, keep `U_RuleValidator` as a double-check layer.

**F7 Verification**:
- [ ] All 11 rule `.tres` files load green in headless + editor.
- [ ] Injecting a type error into any `.tres` file fails loudly at load with a resource path.
- [ ] Existing rule-engine tests green.
- [ ] Commit 1 notes clearly document which path was taken and why.

---

## Milestone F8: `S_VCamSystem` + `S_CameraStateSystem` Decomposition (Expanded v7.2.1)

**Goal**: Extend C5's pattern to the other two large systems. **Phase 0 decomposes oversized helpers first** so Phase 1+ can push system logic into them without creating 800+ line helper files.

**Phase 0 helper pre-decomposition**:

- [ ] **Commit 1a** (GREEN) — Decompose `u_vcam_rotation.gd` (740 lines) into:
  - `u_vcam_rotation_continuity.gd` (~80 lines): rotation-transition methods.
  - `u_vcam_orbit_centering.gd` (~90 lines): orbit "look behind" centering animation.
  - `u_vcam_look_spring.gd` (~180 lines): 2nd-order spring dynamics + release damping + debug.
  Update `u_vcam_effect_pipeline.gd` and `s_vcam_system.gd` imports. All existing VCam tests green.
- [ ] **Commit 1b** (GREEN) — Decompose `u_vcam_orbit_effects.gd` (650 lines) into:
  - `u_vcam_look_ahead.gd` (~110 lines).
  - `u_vcam_ground_anchor.gd` (~110 lines).
  - `u_vcam_soft_zone_applier.gd` (~120 lines).
  - Residual `u_vcam_orbit_effects.gd` (~80 lines): sampling + bypass + prune.
  Update imports. All existing VCam tests green.

**Phase 1+ system extraction**:

- [ ] **Commit 1** (RED) — Method-level decomposition tests for extracted logic.
- [ ] **Commit 2** (GREEN) — Extract `S_VCamSystem` private methods into (now smaller) helpers. Target: file under 400 lines.
- [ ] **Commit 3** (GREEN) — Extract `S_CameraStateSystem` private methods. Target: file under 400 lines. Create `u_camera_state_rule_applier.gd` if no existing helper fits.
- [ ] **Commit 4** (GREEN) — Style enforcement:
  - `process_tick` methods under 80 lines in all three large systems (C5 + F8).
  - System files `s_vcam_system.gd` / `s_camera_state_system.gd` under 400 lines.
  - **NEW (v7.2.1)**: Every `.gd` file under `scripts/ecs/systems/helpers/` under 400 lines.

**F8 Verification**:
- [ ] All existing VCam and camera-state integration tests green.
- [ ] System files under ~400 lines total.
- [ ] `process_tick` under 80 lines in both systems.
- [ ] All helper files under 400 lines.
- [ ] New helpers (`u_vcam_rotation_continuity`, `u_vcam_orbit_centering`, `u_vcam_look_spring`, `u_vcam_look_ahead`, `u_vcam_ground_anchor`, `u_vcam_soft_zone_applier`) all exist and are referenced by consumers.
- [ ] Style enforcement test green.

**Dependency note**: Follows C5. **Phase 0 (Commits 1a + 1b) must land before Phase 1+ (Commits 1-4).**

---

## Milestone F9: ECS System Execution Phasing — Named Phase Enum

**Goal**: Replace opaque integer `execution_priority` with a named `SystemPhase` enum. Keep `execution_priority` as within-phase tiebreaker.

- [ ] **Commit 1** (RED) — Phasing tests in `test_m_ecs_manager_phasing.gd`.
- [ ] **Commit 2** (GREEN) — Introduce `SystemPhase` enum on `BaseECSSystem` (`INPUT`, `PRE_PHYSICS`, `PHYSICS_SOLVE`, `POST_PHYSICS`, `CAMERA`, `VFX`).
- [ ] **Commit 3** (GREEN) — Refactor `M_ECSManager` sort/loop to group by phase first, then by `execution_priority`.
- [ ] **Commit 4** (GREEN) — Assign explicit phases to all existing `S_*` systems based on current priority values. Verify ordering didn't change.

**F9 Verification**:
- [ ] Phasing tests green.
- [ ] Existing ECS tests green.
- [ ] All `S_*` systems declare an explicit phase.
- [ ] No ECS system uses `_physics_process` directly (style enforcement).

---

## Milestone F10: State Store History Truncation — ALREADY IMPLEMENTED

**Goal**: Verification-only checkpoint. `U_ActionHistoryBuffer` is a ring buffer with configurable `max_history_size`, disabled on mobile.

- [ ] **Commit 1** (VERIFY) — Add `test_m_state_store_history_truncation.gd` (if not already covered):
  - Buffer does not exceed `max_history_size` after dispatching `max_history_size + 100` actions.
  - `configure(0, true)` and `configure(N, false)` both result in empty history.
  - Ring buffer wraps correctly (oldest entries evicted first).

**F10 Verification**:
- [ ] Verification tests green.
- [ ] Existing store tests green.

---

## Milestone F11: Event Bus "Zombie" Prevention (Dead Subscriber Pruning)

**Goal**: Prune dead subscriber callables from `BaseEventBus._subscribers` at publish time. Scope is `scripts/events/base_event_bus.gd` (shared base), **not** the `U_ECSEventBus` facade.

- [ ] **Commit 1** (RED) — `tests/unit/ecs/events/test_base_event_bus_zombies.gd`: dead subscriber removed after publish; no entries with `callback.is_valid() == false` in `_subscribers`.
- [ ] **Commit 2** (GREEN) — Publish-time pruning in `BaseEventBus.publish()`.
- [ ] **Commit 3** (GREEN) — Replace per-publish `.duplicate()` at `:93` with index-based iteration safe for mid-iteration removal.

**F11 Verification**:
- [ ] Zombie pruning tests green.
- [ ] Existing event bus tests green (including `test_ecs_event_bus.gd`).
- [ ] No `.duplicate()` call in `BaseEventBus.publish()` (style enforcement).

---

## Milestone F12: Settings Overlay Wrapper Deduplication (v7.2.1 Addition)

**Goal**: Three 53-line overlay wrappers are character-for-character identical except `class_name`. Collapse into a single base class.

- [ ] **Commit 1** (RED) — `test_settings_simple_overlay_base.gd`: all three overlays share behavior; each concrete script under 15 lines post-refactor.
- [ ] **Commit 2** (GREEN) — Create `scripts/ui/settings/base_settings_simple_overlay.gd` with the 52 shared lines.
- [ ] **Commit 3** (GREEN) — Reduce each of the three overlay files to ~5 lines (`@icon` + `extends` + `class_name`).
- [ ] **Commit 4** (GREEN) — Style enforcement: each simple overlay under 15 lines. `ui_vfx_settings_overlay.gd` explicitly excluded.

**F12 Verification**:
- [ ] Existing settings-overlay integration tests green (navigation, theme, close).
- [ ] Three overlay files reduced from 53 → ~5 lines each.
- [ ] `base_settings_simple_overlay.gd` contains extracted shared behavior.
- [ ] VFX overlay unchanged.
- [ ] Style enforcement test green.

**Dependency note**: Independent.

---

## Milestone F15: Designer-Facing Resource Schema Validation (v7.2.1 Addition)

**Goal**: Extend F7's "fail loud at load" pattern to `RS_GameConfig` (HIGH risk), `RS_InputProfile` (MEDIUM), `RS_SceneRegistryEntry` (MEDIUM). `RS_UIThemeConfig` is out of scope (runtime defaults already prevent crashes).

- [ ] **Commit 1** (RED) — Validation tests for all three resources (assert empty/malformed fields fail at load with `resource_path` in error).
- [ ] **Commit 2** (GREEN) — `RS_GameConfig._init()`: validate four fields non-empty. Include `resource_path` in `push_error`.
- [ ] **Commit 3** (GREEN) — `RS_InputProfile._init()`: validate `profile_name`, `action_mappings`, `virtual_buttons` structure, `virtual_joystick_position` bounds.
- [ ] **Commit 4** (GREEN) — `RS_SceneRegistryEntry._init()`: elevate existing `_validate_property()` warnings to `push_error` on empty `scene_id` / `scene_path`.
- [ ] **Commit 5** (GREEN) — Cross-reference boot validation in `M_GameplayInitializerManager` (or equivalent): validate `retry_scene_id` exists in `U_SceneRegistry` and `default_objective_set_id` exists in objectives registry. Fail loud on boot.

**F15 Verification**:
- [ ] All validation tests green.
- [ ] Injecting an invalid field into any of the three `.tres` files fails loudly at load with `resource_path`.
- [ ] Cross-reference boot validation catches dangling scene/objective IDs before gameplay starts.
- [ ] Existing resource-consumer tests green.

**Dependency note**: Independent. Pattern mirrors F7. Can run in parallel with F7 or after.

---

## Dependency Graph / Sequencing

- **F1** → verification-only, first to land (single commit).
- **F2 → F3 → F4** → sequential chain, all touch `m_state_store.gd`. Run full test suite between each.
- **F5** → depends on F3 (single-mutation-path invariant must hold before channel taxonomy is enforceable).
- **F6** → independent.
- **F7** → independent, gated on Commit 1 parser-feasibility investigation.
- **F8** → depends on C5. **Phase 0 (Commits 1a/1b) before Phase 1+.** Extends C5's pattern.
- **F9** → independent, extends existing `execution_priority` system (does not replace it).
- **F10** → verification-only.
- **F11** → independent.
- **F12** → independent.
- **F15** → independent, mirrors F7's pattern.

**Cross-milestone integration**: Run full test suite after each milestone completes. Critical for the F2 → F3 → F4 chain.

---

## Follow TDD Discipline

For each milestone:

1. Write the test first (unit or integration).
2. Run the test and verify it fails for the expected reason.
3. Implement the minimal code to make it pass.
4. Run the full test suite and verify no regressions.
5. Run `tests/unit/style/test_style_enforcement.gd` after any file creation or rename.
6. Commit with a clear, focused message.

---

## Preserve Compatibility

You MUST:

- Keep all existing ECS systems, QB v2 consumers, state management flows, and manager APIs working.
- Follow existing composition patterns — compose shared utilities, do not create deep inheritance hierarchies. The `base_settings_simple_overlay.gd` class in F12 is the exception because the overlay hierarchy is already inheritance-based (`BaseOverlay` → `BaseMenuScreen` → `BasePanel` → `Control`).
- Maintain existing `I_*` interface contracts and `M_*Manager` public APIs.
- Ensure new `@export` fields on validated resources ship with defaults matching current values so no existing scene or test breaks.
- Register new utilities following the `U_` prefix convention and new resources following the `RS_` prefix convention per `STYLE_GUIDE.md`.

---

## Key Design Decisions

- **Subscriber contract is read-only**: F2 relies on the existing implicit contract (`m_state_store.gd:468`) that subscribers treat state as read-only. Document this explicitly in F2 Commit 2.
- **Strict mode is opt-in first, default later**: F4 flips the strict-slice-dependency default to `true` only in Commit 5, after the audit-and-fix pass is green. This is the one explicit behavior-change commit in v7.2.
- **ADR-first for channel taxonomy**: F5 writes the ADR before migrating violations, so the rule is documented before enforcement starts.
- **Scope push/pop preserves production behavior**: F6's scope stack is empty in production; production `U_ServiceLocator.register()` behavior is unchanged. Test isolation is opt-in via `push_scope`/`pop_scope` in `BaseTest`.
- **Phase enum composes with priority**: F9's `SystemPhase` enum provides bucket-level ordering; `execution_priority` remains the within-phase tiebreaker. Existing systems keep their integer priorities as the secondary sort key.
- **Helper size invariant**: F8's Phase 0 establishes a 400-line ceiling for every `.gd` file under `scripts/ecs/systems/helpers/`. Codified in style enforcement so future system extraction can't regress it.
- **Overlay base class is new, but scene files are untouched**: F12 introduces `base_settings_simple_overlay.gd` between `BaseOverlay` and the three concrete overlays. The `.tscn` scene files continue to instance tab content as before.
- **Resource validation is `_init()` + boot cross-check**: F15 uses `_init()` for local schema checks (fail at load with `resource_path`) and defers cross-registry checks (e.g., "does `retry_scene_id` exist in `U_SceneRegistry`?") to a one-shot boot validation pass, because `_init()` runs before autoloads are available.

---

## Critical Notes

- **No Autoloads**: Follow existing patterns. Managers live under the `Managers` node and register with `U_ServiceLocator`.
- **Style & Organization**: Follow `docs/general/STYLE_GUIDE.md` and node naming prefixes (`S_`, `C_`, `RS_`, `U_`, `I_`, `E_`, `M_`).
- **Update Docs After Each Milestone**: Per AGENTS.md's mandatory pattern — update `cleanup-v7.2-tasks.md` completion notes and this continuation prompt after completing each milestone. Commit doc updates separately from implementation.
- **Test Suite Command**: `tools/run_gut_suite.sh` (or `tools/run_gut_suite.sh -gtest=res://tests/unit/...` for targeted suites).
- **Style Test**: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd`
- **`docs/adr/` directory must be created in F5 Commit 2** — it does not exist yet. ADR numbering starts at `0001-channel-taxonomy.md`.
- **F4 Commit 5 is the one behavior-change commit in v7.2** — strict-slice-dependency default flip. Run full suite before landing.
- **F8 Phase 0 Commits (1a + 1b) must land before Phase 1+** — otherwise system extraction pushes logic into 800+ line helpers.
- **F7 Commit 1 is an investigation commit** — record the Path A vs Path B decision and rationale in the milestone notes before writing tests or implementation.
- **F11 targets `BaseEventBus`, not `U_ECSEventBus`** — the shared base class is the fix site. Both `U_ECSEventBus` and `U_StateEventBus` facades inherit the behavior.
- **F1 and F10 are verification-only** — single-commit checkpoints confirming the original concerns were resolved during C6 and a prior cleanup respectively.
- **F13/F14 are not milestones** — the "unbounded collections" concerns were audited and rejected. Do not re-open this scope. Rationale lives in `cleanup-v7.2-tasks.md` Purpose section.

---

## Next Steps

1. Confirm C12 (`post-process-refactor-tasks.md`) has landed and full regression pass (desktop + mobile) is green.
2. **Begin F1 verification** — single-commit style-enforcement assertions confirming C6 gaps stay closed.
3. **Begin F2** — StateStore dispatch snapshot sharing. First real implementation milestone.
4. Proceed sequentially through F3 → F4 (sequential chain, run full suite between each).
5. F5 after F3 lands (cleaner to enforce channel taxonomy once state mutation is single-sourced).
6. F6, F7, F8 (incl. Phase 0), F9, F11, F12, F15 can be scheduled independently.
7. F10 verification checkpoint can run any time.
8. After F1–F8 are green and F5 has landed, revisit the closing `AGENTS.md` sprawl reflection to decide whether to promote it to a numbered F-milestone (F16).
9. Update `MEMORY.md` test-failure patterns section after F6 lands — the `U_StateHandoff` and `_ensure_appliers` entries should no longer manifest once scope-based test isolation replaces `U_ServiceLocator.clear()`.
