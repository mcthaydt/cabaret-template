# Cross-System Cleanup V8 — Tasks Checklist

**Branch**: `cleanup-v8` (off `main`, with `GOAP-AI` merged via PR #16). Phase 1 proceeds on this branch. Subsequent phases can branch from `main` after Phase 1 merges, or continue on `cleanup-v8` if preferred. Matches continuation prompt.
**Status**: Phase 1 complete — P1.1 complete; P1.2 complete (`b5962d32`, `e07a933a`, `a70032dd`, `784aede9`, `e84e2890`, `79344746`); P1.3 complete (`8c163ae0`, `5051a2c4`, `fa7fc071`, `aa083186`, `7a3e936f`); P1.4 complete (`6ad6e79c`, `677003b4`, `b5eafe91`); P1.5 complete (`488807d2`, `cf80eb4f`, `4069c08a`, `165d93c4`, `4ea75032`, `5e3bdf5e`, `a2c54f7b`); P1.6 complete (`f46f1fa3`, `5967661e`); P1.6b complete (`a98fd907`, `08f2aaf4`, `0c196e7d`, `3dda0fd5`, `0128edd0`, `78d73d09`, `8b2198c6`, `97252380`, `0ad8c49d`, `90ce7243`, `07ba856a`, `64de76f6`, `7364b41f`); P1.7 complete (`6385e68d`, `fbcaccd9`, `54425b93`, `bf2a734e`); P1.8 complete (`fee01ce5`, `301b39be`, `2b04de39`, `a3f4bc33`); P1.9 complete (`26289494`, `fffa2e55`, `7de2a6cf`, `c1d7b0fb`, `a2766455`, `2aacb999` + remediation `91c094c0`..`e416469c`); P1.9b complete (`348802ca`, `b2c67185`, `7a96c4b0`, `d2644cf3`, `0bb07870`, `085c428d`, `73a66510`, `cd2afbcf`, `94d4b7c6` + 2026-04-22 verification follow-through); P1.10 BT-only legacy cleanup complete (`43035ad6`, `6a30f13c` + 2026-04-23 docs hygiene follow-through). Phase 2 complete through P2.4 (`28702b95`) with style recheck passing (`83/83`). Phase 3 complete as of 2026-04-23: P3.0–P3.4 + P3.6 landed, and the P3.5 framework deliverable (dir + `README.md` + `TEMPLATE.md` + `test_extension_recipe_structure`) shipped; the 18 individual extension recipes still ship at the tail of their owning phase (Phases 1/4/5), so overall P3 Verification closes only once those recipe commits land. Style recheck now `86/86` after `test_adr_structure` + `test_extension_recipe_structure` were added. Phase 4: P4.1–P4.2 complete; P4.3 complete (`0dba3719`..`ed8e5de0` — all scripts moved to scripts/core/ or scripts/demo/, core→demo import violations eliminated, stale dirs removed, full suite 4587/4595 green); P4.4 enforcement test already in style suite (`test_core_scripts_never_import_from_demo` 87/87). P4 Scripts Verification complete (2026-04-24). P4.5 complete (`72272902` audit); P4.6 complete (`2f753915`..`7c33705b` — all core resources → resources/core/); P4.7 complete (`f66a7ce7`..`ef5d8e07` — core scenes → scenes/core/, demo scenes → scenes/demo/); P4.8 complete (`fece8d8c` — demo audio/models/textures → assets/demo/); P4.9 complete (`a85d963b` — core-never-references-demo enforcement tests, 6 violations fixed); P4.10 complete (`bfc64316`..`58e4263e` — prototype_grids → assets/demo/textures/, editor_icons → assets/core/, remaining core dirs → assets/core/). Style suite 89/89. Phase 6: P6.1 complete (`10310f00`..`ec14181a` — RS_BTScoredNode decorator + utility selector scored-node detection, duck-typing, style cap 50 lines). Style suite 90/90. Full suite 4601/4601 passing. P6.2 complete (`a4c41434`..`a23270b1`). P6.3 complete (`d0c1224a`..`0cd59475`). P6.4 complete (`4a1218f1`..`c6608c79` — RS_AIBrainScriptSettings, get_root() virtual, caller updates). P6.5 complete (`6e9e7b6a`..`e28d0c30` — 6 creature BT .tres deleted, builder scripts, script-backed .tres, scene rewire; gap-patched `5a176f9a`..`b29e3618` — guide_showcase_behavior builder + migration of cfg_guide_showcase_brain.tres). P6.7 note: manifest at `scripts/core/scene_management/u_scene_manifest.gd` (not demo/ as originally spec'd — intentional; manifest drives core loader). P6.9 complete with loader unit tests (`a16b0783`). P6.10–P6.12 complete (`eb7f37c0`..`1148e2f5` — U_QBRuleBuilder + 11 br_*.gd builders + ECS rewires + ADR 0011 + extensions/builders.md). Phase 6 closed. **Audit 2026-04-27** (post-P7 work): full suite 4807/4815 passing, 8 pre-existing pending, 0 failures (verified after `92c146e1` UID refresh on `gameplay_ai_woods.tscn` resolved 5 stale prefab UIDs introduced by P7.7b/c). Style suite 92/92. Phase 7 in progress through P7.8. Phase 8 (UI menu builders): in progress through P8.4 (audio tab migration).
**Methodology**: TDD (Red-Green-Refactor) — tests written within each milestone, not deferred.
**Scope**: Eight phases. Phase 1 is the largest (AI rewrite) and must complete before Phases 2–5, because Phases 4–5 depend on a stable AI architecture to decide what is "core template" vs "demo content." Phase 6 (fluent builders) can proceed after Phase 4 completes. Phase 7 (EditorScript + PackedScene builders) proceeds after Phase 6 completes. Phase 8 (UI menu builders) proceeds after Phase 6 (builder precedent) and extends the fluent-builder philosophy to UI layout, theming, localization, focus, and signal wiring.
**Current status (2026-04-28)**: Phases 1–4, 6–7 COMPLETE. Phase 5 not started (deferred to last). Phase 8 not started. Style suite 94/94. P6.13 (gap patches + constant migrations) complete. P7.1–P7.8 all complete. 21 builder scripts under `scripts/demo/editors/`. ADR-0012 (Editor Builder Pattern) shipped.

**Relationship to cleanup-v7.2**: This is a successor plan, not a replacement. V7.2 addressed architectural weaknesses inside existing systems. V8 addresses structural/organizational debt surfaced while working on the AI forest: the planner stack is overbuilt, debug/perf code is scattered across managers, `AGENTS.md` is sprawling, template-vs-demo content is entangled, and temp scenes are piling up.

---

## Purpose

Eight phases bundled because they share an outcome: **make the template LLM-friendly, modular, and ship-ready as a reusable base.**

1. **Phase 1 — AI rewrite.** Replace the GOAP + HTN stack with utility-scored behavior trees. Plan file: `~/.claude/plans/whats-a-better-approach-snoopy-candle.md`. ~940 LOC of planning infrastructure serves behaviors that are, in practice, priority-ordered condition checks → fixed 2–4 step action sequences. No compound task has multiple decomposition methods. Every behavior-add touches 4 layers across two planning vocabularies, which is exactly where LLMs struggle.
2. **Phase 2 — Debug/perf extraction.** Managers and ECS systems have accumulated in-line debug logging and perf probes (e.g., mobile camera perf probes documented in `DEV_PITFALLS.md`). Consolidate through the existing `U_DebugLogThrottle` / `U_PerfProbe` utilities so production code paths stop carrying inspection logic. `U_PerfProbe` already exists at `scripts/utils/debug/u_perf_probe.gd` and is in use; Phase 2 extends adoption and forbids bare `print()` in managers/systems.
3. **Phase 3 — Docs split.** `AGENTS.md` has grown into a single mega-doc with overlap against `DEV_PITFALLS.md`. Split by audience and concern so LLMs (and humans) can load just the section they need.
4. **Phase 4 — Template vs demo separation.** Forest AI (wolf/deer/rabbit), sentry/drone/prism agents, and any demo-only scenes are entangled with core template code under `scripts/` and `resources/`. Reorganize into `template/` (core) and `demo/` (examples) so consumers can delete the demo tree without breaking the template.
5. **Phase 5 — Base scene reset.** Multiple temp / fake scenes exist under `scenes/`. Define one canonical base scene, migrate the real demo content to it, delete the rest.
6. **Phase 6 — LLM-first fluent builders.** All configuration is currently authored as `.tres` resource files via Godot's inspector — hostile to LLM co-pilots (multiple turns, hallucinated ExtResource IDs, unreadable git diffs). Introduce GDScript builder APIs for BT trees, scene registry, input profiles, and QB rules. Each builder provides a programmatic alternative that an LLM can write in a single 20-line script. Migrate all existing `.tres` configuration to builder scripts.
7. **Phase 7 — EditorScript + PackedScene builders.** Hand-authored `.tscn` scene creation is hostile to LLM co-pilots for the same reasons as `.tres` resources: multi-file coordination, unreadable git diffs, and drag-and-drop NodePath requirements. Introduce `U_EditorPrefabBuilder` and `U_EditorBlockoutBuilder` fluent APIs. Migrate all demo prefab scenes to builder scripts.
8. **Phase 8 — LLM-first UI menu builders.** UI settings screens and menu overlays are authored via `.tscn` scenes with dozens of `@onready` variables, 50+ line `_apply_theme_tokens()` / `_localize_labels()` / `_configure_focus_neighbors()` methods, and per-control null-guard boilerplate — exactly the LLM-hostile pattern that Phases 6–7 eliminated for data resources and scene authoring. Introduce `U_SettingsTabBuilder` and `U_UIMenuBuilder` fluent APIs that programmatically construct UI nodes, wire signals, apply theme tokens, localize labels, and configure focus chains in a single declarative chain. A `U_UISettingsCatalog` utility centralizes dropdown/slider option data. Migrate all settings tabs and menu screens to builder-driven implementations.

Phases 2–5 are independent of each other and can be reordered, but all depend on Phase 1. Phase 6 depends on Phase 4 (template/demo split). Phase 7 depends on Phase 6 (builder precedent). Phase 8 depends on Phase 6 (builder precedent + core/demo directory split).

---

## Sequencing

- **Phase 1** lands first. Non-trivial rewrite with full TDD discipline. Separate branch recommended.
- **Phase 2** can land any time after Phase 1.
- **Phase 3** can run in parallel with Phase 2 (pure docs).
- **Phase 4** must come after Phase 1 (the AI split is the largest template-vs-demo decision).
- **Phase 5** should come last — scene cleanup is easier once code is organized.
- **Phase 6** depends on Phase 4 (builders must respect the core/demo directory split). Can proceed in parallel with Phase 5.
- **Phase 7** depends on Phase 6 (builder precedent). Proceeds after Phase 6 completes.
- **Phase 8** depends on Phase 6 (builder precedent + core/demo directory split). Can proceed in parallel with Phase 7.

**Cross-milestone integration**: Full test suite after each phase. The Phase 1 → Phase 4 → Phase 6 → Phase 7/8 chain is the highest-risk path.

---

# Phase 1 — AI Rewrite: Utility-Scored Behavior Trees

**Reference plan**: `~/.claude/plans/whats-a-better-approach-snoopy-candle.md` (approved).

**Goal**: Replace GOAP + HTN with a data-driven behavior tree framework where each creature's brain is one `.tres` readable top-to-bottom. Utility scoring replaces goal-selector priority arbitration. Cooldown / one-shot / rising-edge become decorator nodes. All 10 existing `I_AIAction` resources are reused unchanged.

**LOC target**: ~400 added (BT framework + nodes + runner), ~700 removed. Measured delete targets: `u_htn_planner.gd` 110 + `u_ai_goal_selector.gd` 225 + `u_ai_task_runner.gd` 88 + `u_ai_replanner.gd` 87 + `u_ai_context_builder.gd` 82 + `u_htn_planner_context.gd` 14 + `rs_ai_goal.gd` 32 + `rs_ai_{task,compound_task,primitive_task}.gd` 51 = 689 LOC. Net ~300 LOC reduction. (QB rule/scorer infra is retained per P3.5 Commit 12 — not counted in deletions.)

**Creatures to migrate**: wolf, deer, rabbit, sentry, patrol_drone, guide_prism. Demo parity is the acceptance bar.

---

## Milestone P1.1: BT Framework Scaffolding

**Goal**: Introduce the node base class, status enum, and per-node state contract. Zero behavior change — nothing wired up to the game yet.

- [x] **Commit 1** (RED) — `tests/unit/ai/bt/test_rs_bt_node_base.gd`:
  - Status enum has exactly `RUNNING`, `SUCCESS`, `FAILURE`.
  - Base `tick(context, state_bag)` calls `push_error` when not overridden (matches `I_AIAction` / `I_Condition` pattern per F16).
  - `node_id` is stable per instance (used as state-bag key).
- [x] **Commit 2** (GREEN) — Create (general framework under `scripts/resources/bt/` — these base classes have no AI dependencies):
  - `scripts/resources/bt/rs_bt_node.gd` — `class_name RS_BTNode`, `extends Resource`. `enum Status { RUNNING, SUCCESS, FAILURE }`. Virtual `tick(context: Dictionary, state_bag: Dictionary) -> Status`.
  - `scripts/resources/bt/rs_bt_composite.gd` — `class_name RS_BTComposite`, `extends RS_BTNode`. Typed `children: Array[RS_BTNode]` with `_sanitize_children()` setter matching F7 pattern.
  - `scripts/resources/bt/rs_bt_decorator.gd` — `class_name RS_BTDecorator`, `extends RS_BTNode`. Typed `child: RS_BTNode`.
- [x] **Commit 3** (GREEN) — Style enforcement:
  - Add to `tests/unit/style/test_style_enforcement.gd`: every file under `scripts/resources/bt/` AND `scripts/resources/ai/bt/` under 200 lines.
  - Files under `scripts/resources/bt/` must not import `U_AI*` legacy planner utils OR any AI-specific types (prevents backslide; keeps the framework general). Files under `scripts/resources/ai/bt/` may reference `I_Condition` / `I_AIAction` / `U_AITaskStateKeys`.

**P1.1 Verification**:
- [x] All new tests green.
- [x] Existing test suite green (no code wired yet).
- [x] Style enforcement green.

**P1.1 Completion Notes (2026-04-17)**:
- Implemented `RS_BTNode`, `RS_BTComposite`, and `RS_BTDecorator` under `scripts/resources/bt/`.
- Added RED base-contract test coverage at `tests/unit/ai/bt/test_rs_bt_node_base.gd`.
- Added BT style guards for per-file line-count and AI-dependency boundaries in `tests/unit/style/test_style_enforcement.gd`.
- Re-verified on `cleanup-v8` after P1.2 RED test commit: full suite is currently green (`4460` passing, `8` expected pending/headless skips, `0` failing).
- Re-verified after P1.2 Commit 2 (GREEN): full suite is currently green (`4465` passing, `8` expected pending/headless skips, `0` failing).
- Re-verified after P1.2 Commit 6 (GREEN): full suite is currently green (`4478` passing, `8` expected pending/headless skips, `0` failing).

---

## Milestone P1.2: Composites — Sequence, Selector, UtilitySelector

- [x] **Commit 1** (RED) — `test_rs_bt_sequence.gd`:
  - Empty sequence returns SUCCESS.
  - All-SUCCESS children → SUCCESS.
  - First FAILURE short-circuits → FAILURE.
  - RUNNING child → returns RUNNING, re-enters same child next tick.
  - Completed in commit `b5962d32`; test run is red for expected reason (`res://scripts/core/resources/bt/rs_bt_sequence.gd` missing).
- [x] **Commit 2** (GREEN) — `scripts/resources/bt/rs_bt_sequence.gd`. State bag stores current child index.
  - Completed in commit `e07a933a` (`RS_BTSequence` + headless-safe BT test helper/coercion updates).
- [x] **Commit 3** (RED) — `test_rs_bt_selector.gd`:
  - Empty selector → FAILURE.
  - First SUCCESS short-circuits → SUCCESS.
  - All-FAILURE → FAILURE.
  - RUNNING child → RUNNING, re-enters next tick.
  - Completed in commit `a70032dd`; test run is red for expected reason (`res://scripts/core/resources/bt/rs_bt_selector.gd` missing).
- [x] **Commit 4** (GREEN) — `scripts/resources/bt/rs_bt_selector.gd`.
  - Completed in commit `784aede9`.
- [x] **Commit 5** (RED) — `test_rs_bt_utility_selector.gd`:
  - Picks highest-scoring child.
  - Score ≤ 0 treated as "not viable" and skipped.
  - Re-scores each tick at the root (not when mid-RUNNING on same child — state bag pins running child until it returns SUCCESS/FAILURE).
  - Tie-break: earlier child wins (stable).
  - Empty / all-zero-score → FAILURE.
- [x] **Commit 6** (GREEN) — `scripts/resources/bt/rs_bt_utility_selector.gd`. Scoring delegated to per-child scorers (see P1.4 — base `RS_AIScorer` lives under `scripts/resources/ai/bt/scorers/` since scoring is AI-specific; the utility selector accepts any callable that returns a float, keeping it general).
  - Commit 5 completed in `e84e2890`.
  - Commit 6 completed in `79344746`.

**P1.2 Verification**:
- [x] All composite tests green.
- [x] No regressions.

**P1.2 Completion Notes (2026-04-17)**:
- Added RED contract coverage for `RS_BTUtilitySelector` at `tests/unit/ai/bt/test_rs_bt_utility_selector.gd`.
- Implemented `scripts/resources/bt/rs_bt_utility_selector.gd` with:
  - highest-positive-score child selection,
  - stable first-child tie-break behavior,
  - running-child pinning via state bag until completion.
- Verified with:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/bt/test_rs_bt_utility_selector.gd`
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd`
  - `tools/run_gut_suite.sh` (`4478` passing, `8` pending, `0` failing).

---

## Milestone P1.3: Leaves — Condition, Action

- [x] **Commit 1** (RED) — `test_rs_bt_condition.gd`:
  - Wraps existing `I_Condition` (reuse `scripts/resources/qb/conditions/*` infra — the implementations the goal selector consumes via `U_RuleScorer`).
  - TRUE → SUCCESS, FALSE → FAILURE.
  - Never returns RUNNING.
- [x] **Commit 2** (GREEN) — `scripts/resources/ai/bt/rs_bt_condition.gd`. Exports typed `condition: I_Condition`.
- [x] **Commit 3** (RED) — `test_rs_bt_action.gd`:
  - Wraps existing `I_AIAction` (reused unchanged from current tree).
  - First tick calls `action.start()`, subsequent ticks call `action.tick()`, polls `action.is_complete()`.
  - While not complete → RUNNING.
  - On complete → SUCCESS and resets state so next entry calls `start()` again.
  - Uses `U_AITaskStateKeys.ACTION_STARTED` (reused — `u_ai_task_state_keys.gd` is retained after P1.10 legacy deletion, per scope decision) plus a new `BT_ACTION_STATE_BAG` key constant.
- [x] **Commit 4** (GREEN) — `scripts/resources/ai/bt/rs_bt_action.gd`. Typed `action: I_AIAction` export.

**P1.3 Verification**:
- [x] All 10 existing `RS_AIAction*` scripts run under BT without modification.
- [x] Leaf tests green.

**P1.3 Completion Notes (2026-04-17)**:
- Commit 1 (RED) `8c163ae0`: added `tests/unit/ai/bt/test_rs_bt_condition.gd` (failing for expected missing-script reason).
- Commit 2 (GREEN) `5051a2c4`: implemented `scripts/resources/ai/bt/rs_bt_condition.gd` (score > 0.0 => `SUCCESS`, else `FAILURE`; never `RUNNING`).
- Commit 3 (RED) `fa7fc071`: added `tests/unit/ai/bt/test_rs_bt_action.gd` plus helper `tests/unit/ai/bt/helpers/test_bt_counting_action.gd` (failing for expected missing-script reason).
- Commit 4 (GREEN) `aa083186`: implemented `scripts/resources/ai/bt/rs_bt_action.gd` with `ACTION_STARTED` lifecycle, per-node task-state bag (`BT_ACTION_STATE_BAG`), `RUNNING` until completion, then reset-and-`SUCCESS`.
- Verification (2026-04-17): added `tests/unit/ai/bt/test_rs_ai_actions_bt_compat.gd` — asserts all 10 `RS_AIAction*` scripts (`animate`, `feed`, `flee_from_detected`, `move_to`, `move_to_detected`, `publish_event`, `scan`, `set_field`, `wait`, `wander`) load, extend `I_AIAction`, and bind unmodified to `RS_BTAction.action` (typed export). Proves BT-compatibility without source changes.
- Verification commands:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/bt/test_rs_bt_condition.gd`
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/bt/test_rs_bt_action.gd`
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/bt/test_rs_ai_actions_bt_compat.gd` (3/3 passing, 107 asserts).
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` (60/60 passing).
  - `tools/run_gut_suite.sh` (`4498` passing, `8` pending, `0` failing).

---

## Milestone P1.4: Scorers

- [x] **Commit 1** (RED) — `test_rs_ai_scorer.gd`:
  - `RS_AIScorerConstant(value)` → returns `value`.
  - `RS_AIScorerCondition(condition, if_true, if_false)` → gated score.
  - `RS_AIScorerContextField(path, multiplier)` → reads `context[path]` (dot-separated) and multiplies.
  - Invalid path → 0 + `push_error`.
- [x] **Commit 2** (GREEN) — Implement 3 scorer resources in `scripts/resources/ai/bt/scorers/`. Base `RS_AIScorer` with virtual `score(context) -> float`.
- [x] **Commit 3** (GREEN) — Wire `RS_BTUtilitySelector` to call `child_scorers[i].score(context)` per tick.

**P1.4 Verification**:
- [x] Scorer tests green.
- [x] `RS_BTUtilitySelector` integration test with mixed scorers green.

**P1.4 Completion Notes (2026-04-17)**:
- Commit 1 (RED) `6ad6e79c`: added `tests/unit/ai/bt/test_rs_ai_scorer.gd` (failing for expected missing scorer scripts).
- Commit 2 (GREEN) `677003b4`: implemented scorer resources:
  - `scripts/resources/ai/bt/scorers/rs_ai_scorer.gd`
  - `scripts/resources/ai/bt/scorers/rs_ai_scorer_constant.gd`
  - `scripts/resources/ai/bt/scorers/rs_ai_scorer_condition.gd`
  - `scripts/resources/ai/bt/scorers/rs_ai_scorer_context_field.gd`
- Commit 2 also updated style enforcement to allow `rs_ai_*` scripts under `scripts/resources/ai/bt/`.
- Commit 3 (GREEN) `b5eafe91`: updated `scripts/resources/bt/rs_bt_utility_selector.gd` to support resource-driven child scorers and added integration coverage in `tests/unit/ai/bt/test_rs_bt_utility_selector.gd`.
- Verification commands:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/bt/test_rs_ai_scorer.gd`
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/bt/test_rs_bt_utility_selector.gd`
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd`
  - `tools/run_gut_suite.sh` (`4492` passing, `8` pending, `0` failing).

---

## Milestone P1.5: Decorators — Cooldown, Once, RisingEdge, Inverter

Ports the features currently implemented in `U_AIGoalSelector` (cooldown/one-shot/rising-edge) into reusable decorator nodes.

- [x] **Commit 1** (RED) — `test_rs_bt_cooldown.gd` — `488807d2`:
  - First entry runs child.
  - After child returns SUCCESS, decorator blocks (returns FAILURE) for `duration` seconds.
  - Uses `context.time` or injected time source (not `Time.get_ticks_msec` directly — testability).
- [x] **Commit 2** (GREEN) — `scripts/resources/bt/rs_bt_cooldown.gd` — `cf80eb4f`.
- [x] **Commit 3** (RED) — `test_rs_bt_once.gd` — `4069c08a`:
  - Runs child once per brain lifetime. Subsequent entries → FAILURE.
  - Reset via `context.brain.reset_once_nodes()` (used on scene change).
- [x] **Commit 4** (GREEN) — `scripts/resources/bt/rs_bt_once.gd` — `165d93c4`.
- [x] **Commit 5** (RED) — `test_rs_bt_rising_edge.gd` — `4ea75032`:
  - Only enters child when gate condition transitions false → true.
  - While child RUNNING, re-ticks child regardless of gate (completes what it started).
- [x] **Commit 6** (GREEN) — `scripts/resources/bt/rs_bt_rising_edge.gd` — `5e3bdf5e`.
- [x] **Commit 7** (RED+GREEN) — `test_rs_bt_inverter.gd` + `scripts/resources/bt/rs_bt_inverter.gd` (trivial) — `a2c54f7b`.

**P1.5 Verification**:
- [x] All decorator tests green.
- [x] Time-based tests use injected clock (no real sleeps).

**P1.5 Completion Notes (2026-04-17)**:
- Commit 1 (RED) `488807d2`: added `tests/unit/ai/bt/test_rs_bt_cooldown.gd`.
- Commit 2 (GREEN) `cf80eb4f`: implemented `scripts/resources/bt/rs_bt_cooldown.gd`.
- Commit 3 (RED) `4069c08a`: added `tests/unit/ai/bt/test_rs_bt_once.gd` (failing for expected missing-script reason).
- Commit 4 (GREEN) `165d93c4`: implemented `scripts/resources/bt/rs_bt_once.gd`.
- Commit 5 (RED) `4ea75032`: added `tests/unit/ai/bt/test_rs_bt_rising_edge.gd` (failing for expected missing-script reason).
- Commit 6 (GREEN) `5e3bdf5e`: implemented `scripts/resources/bt/rs_bt_rising_edge.gd`.
- Commit 7 (RED+GREEN) `a2c54f7b`: added `tests/unit/ai/bt/test_rs_bt_inverter.gd` and implemented `scripts/resources/bt/rs_bt_inverter.gd`.
- Verification commands:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/bt/test_rs_bt_once.gd` (4/4 passing).
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/bt/test_rs_bt_rising_edge.gd` (4/4 passing).
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/bt/test_rs_bt_inverter.gd` (4/4 passing).
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` (60/60 passing).
  - `tools/run_gut_suite.sh` (`4512` passing, `8` pending, `0` failing).

---

## Milestone P1.6: Runtime Driver — `U_BTRunner`

Replaces `u_ai_goal_selector`, `u_ai_replanner`, `u_htn_planner`, `u_htn_planner_context`, `u_ai_task_runner`.

- [x] **Commit 1** (RED) — `test_u_bt_runner.gd`:
  - Single `tick(root, context, state_bag) -> Status` entry point.
  - State bag is `Dictionary[int, Variant]` keyed by `node.get_instance_id()`.
  - Action lifecycle test: start → multiple tick → is_complete → next frame re-enters parent.
  - Parallel subtree state isolation (two sibling sequences don't share action state).
  - Handles null nodes with `push_error` (F16 pattern).
- [x] **Commit 2** (GREEN) — `scripts/utils/bt/u_bt_runner.gd` (general-purpose BT driver; no AI-specific imports).

**P1.6 Verification**:
- [x] Runner tests green.
- [x] No reliance on `U_AITaskRunner` or `U_HTNPlanner` imports.

**P1.6 Completion Notes (2026-04-17)**:
- Commit 1 (RED) `f46f1fa3`: added `tests/unit/ai/bt/test_u_bt_runner.gd` with coverage for runner entrypoint delegation, node-id-keyed state bag contract, action lifecycle/re-entry, subtree state isolation, and null-root error handling.
- Commit 1 RED verification: `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/bt/test_u_bt_runner.gd` failed for expected missing script reason (`res://scripts/utils/bt/u_bt_runner.gd` absent).
- Commit 2 (GREEN) `5967661e`: implemented `scripts/utils/bt/u_bt_runner.gd` as a general BT runtime driver (`tick(root, context, state_bag) -> Status`) with null-root fail-loud behavior and state-bag key sanitization.
- Verification commands:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/bt/test_u_bt_runner.gd` (6/6 passing).
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` (60/60 passing).
  - `tools/run_gut_suite.sh` (`4518` passing, `8` pending, `0` failing).

---

## Milestone P1.6b: Planning — `RS_BTPlanner` + World State

Opt-in planning scoped to a single BT composite node. Adds A* search over an action pool with preconditions/effects. Rest of the BT vocabulary is untouched.

**Key design constraints**:
- Planning vocabulary (preconditions/effects/world state) lives only inside `RS_BTPlanner` — the rest of the tree stays vanilla.
- Opt-in: trees without a `RS_BTPlanner` pay zero planning cost.
- Forward-chained A* from current world state → goal predicate. Depth-capped (`max_depth: int = 6`).
- Loud failures: no plan found → `push_error` with state/goal/pool/depth.
- Reuses `I_Condition` for preconditions and for the goal predicate (no new condition type).
- Only one new resource type: `RS_WorldStateEffect`.

- [x] **Commit 1** (RED) — `test_rs_world_state_effect.gd`:
  - `Op.SET` overwrites key with value.
  - `Op.ADD` numeric-adds to existing (missing key treated as 0).
  - `Op.REMOVE` deletes key.
  - Applying an array of effects to a Dictionary returns a new Dictionary (input not mutated).
- [x] **Commit 2** (GREEN) — `scripts/resources/ai/bt/rs_world_state_effect.gd`:
  - `@export var key: StringName`
  - `@export var value: Variant`
  - `@export var op: Op` with `enum Op { SET, ADD, REMOVE }`
  - Static helper `apply_all(state: Dictionary, effects: Array[RS_WorldStateEffect]) -> Dictionary` used by both planner simulation and action execution.

- [x] **Commit 3** (RED) — `test_u_ai_world_state_builder.gd`:
  - Reads selected ECS components (`C_AIBrainComponent`, `C_MovementComponent`, `C_DetectionComponent`, hunger/health fields) and returns a flat `Dictionary[StringName, Variant]`.
  - Never returns nested dicts (flat-only invariant).
  - Missing components → absent keys (not null values).
  - Immutable: caller-mutation of returned dict doesn't affect next build.
- [x] **Commit 4** (GREEN) — `scripts/utils/ai/u_ai_world_state_builder.gd`.

- [x] **Commit 5** (RED) — `test_rs_bt_planner_action.gd`:
  - Typed `preconditions: Array[I_Condition]` with sanitize setter (F7 pattern).
  - Typed `effects: Array[RS_WorldStateEffect]` with sanitize setter.
  - `cost: float = 1.0` (must be > 0; `push_error` if ≤ 0).
  - `child: RS_BTNode` (the behavior to run when planner selects this action).
  - `is_applicable(state: Dictionary) -> bool` — all preconditions satisfied.
- [x] **Commit 6** (GREEN) — `scripts/resources/ai/bt/rs_bt_planner_action.gd` (extends `RS_BTNode`; delegates tick to `child`).

- [x] **Commit 7** (RED) — `test_u_bt_planner_search.gd`:
  - Trivial case: goal already satisfied → empty plan, cost 0.
  - Single-action plan: one action's effects satisfy goal → plan `[A]`.
  - Multi-step plan: A's effects enable B's preconditions; plan `[A, B]` satisfies goal.
  - Cost-optimal: given two plans reaching goal, returns lower-cost path.
  - Unsolvable: empty pool or no path → returns `[]` + `push_error` with `pool size`, `depth`, `goal`, `initial state` in the message.
  - `max_depth` respected: plans longer than cap are rejected.
  - No action self-chains (same action twice consecutively) unless effects demonstrably changed state.
- [x] **Commit 8** (GREEN) — `scripts/utils/ai/u_bt_planner_search.gd`:
  - `find_plan(initial_state, goal: I_Condition, pool: Array[RS_BTPlannerAction], max_depth: int) -> Array[RS_BTPlannerAction]`
  - Forward-chained A*. State hashing via canonicalized `var_to_str`. Heuristic: count of goal sub-conditions not yet satisfied (admissible for conjunctive goals).
  - Target: ~80 LOC.

- [x] **Commit 9** (RED) — `test_rs_bt_planner.gd`:
  - On entry with solvable goal: search runs once, plan cached in state bag.
  - Plan executes as a sequence: step i returns RUNNING → planner returns RUNNING, re-enters step i next tick.
  - Step i returns SUCCESS → advance to step i+1.
  - Final step SUCCESS + goal satisfied → planner returns SUCCESS.
  - Step failure → one replan attempt. If replan finds new plan, continue. If replan fails → planner returns FAILURE.
  - Goal already satisfied on entry → SUCCESS without running any action.
  - Unsolvable on entry → FAILURE + `push_error`.
  - `last_plan: Array[StringName]` + `last_plan_cost: float` written to state bag for debug snapshot.
- [x] **Commit 10** (GREEN) — `scripts/resources/ai/bt/rs_bt_planner.gd` (extends `RS_BTComposite`).

- [x] **Commit 11** (GREEN) — Wire debug snapshot:
  - `C_AIBrainComponent.get_debug_snapshot()` includes `last_plan` + `last_plan_cost` from the most recent planner tick.
  - `debug_ai_brain_panel.gd` renders plan when present.

- [x] **Commit 12** (GREEN) — Style enforcement:
  - `scripts/resources/bt/` (general framework) must not reference `I_Condition`, `I_AIAction`, `RS_WorldStateEffect`, `RS_BTPlanner*`, or any other AI-specific types (AI-specific types stay in `scripts/resources/ai/bt/`).
  - `scripts/utils/bt/` (general driver) must not reference AI-specific types.
  - `rs_bt_planner.gd` under 150 LOC.
  - `u_bt_planner_search.gd` under 120 LOC.

**P1.6b Verification**:
- [x] All planner tests green.
- [x] Unsolvable cases fail loud (every test confirms `push_error` content).
- [x] A tree with zero planner nodes has zero planner imports pulled in (lazy reference) — enforced by `test_bt_general_does_not_reference_planner_runtime_utils` in `test_style_enforcement.gd` (P1.9 Remediation Commit 5, `8ef32d5f`).
- [x] Debug panel shows plan when a planner runs.

**P1.6b Progress Notes (2026-04-18)**:
- Commit 1 (RED) `a98fd907`: added `tests/unit/ai/bt/test_rs_world_state_effect.gd`.
- RED verification: `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/bt/test_rs_world_state_effect.gd` failed for expected reason (`res://scripts/core/resources/ai/bt/rs_world_state_effect.gd` missing).
- Style verification after test-file creation: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` passed (`60/60`).
- Commit 2 (GREEN) `08f2aaf4`: implemented `scripts/resources/ai/bt/rs_world_state_effect.gd` with `SET`/`ADD`/`REMOVE`, immutable `apply_to(...)`, and typed static `apply_all(...)`.
- GREEN verification: `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/bt/test_rs_world_state_effect.gd` passed (`4/4`).
- Regression verification: `tools/run_gut_suite.sh` passed (`4522` passing, `8` pending, `0` failing).
- Commit 3 (RED) `0c196e7d`: added `tests/unit/ai/bt/test_u_ai_world_state_builder.gd`.
- RED verification: `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/bt/test_u_ai_world_state_builder.gd` failed for expected reason (`res://scripts/utils/ai/u_ai_world_state_builder.gd` missing).
- Style verification after test-file creation: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` passed (`60/60`).
- Commit 4 (GREEN) `3dda0fd5`: implemented `scripts/utils/ai/u_ai_world_state_builder.gd` with flat world-state extraction for `C_AIBrainComponent`, `C_MovementComponent`, `C_DetectionComponent`, `C_NeedsComponent`, and `C_HealthComponent`.
- GREEN verification: `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/bt/test_u_ai_world_state_builder.gd` passed (`3/3`).
- Regression verification: `tools/run_gut_suite.sh` passed (`4525` passing, `8` pending, `0` failing).
- Commit 5 (RED) `0128edd0`: added `tests/unit/ai/bt/test_rs_bt_planner_action.gd`.
- RED verification: `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/bt/test_rs_bt_planner_action.gd` failed for expected reason (`res://scripts/core/resources/ai/bt/rs_bt_planner_action.gd` missing).
- Style verification after test-file creation: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` passed (`60/60`).
- Commit 6 (GREEN) `78d73d09`: implemented `scripts/resources/ai/bt/rs_bt_planner_action.gd` with typed/sanitized `preconditions` and `effects`, positive-cost applicability guard, and `child` tick delegation.
- GREEN verification: `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/bt/test_rs_bt_planner_action.gd` passed (`6/6`).
- Style verification after script creation: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` passed (`60/60`).
- Regression verification: `tools/run_gut_suite.sh` passed (`4531` passing, `8` pending, `0` failing).
- Commit 7 (RED) `8b2198c6`: added `tests/unit/ai/bt/test_u_bt_planner_search.gd` covering trivial-goal, single-action, multi-step, cost-optimal, unsolvable diagnostics, max-depth cap, and self-chain contracts.
- RED verification: `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/bt/test_u_bt_planner_search.gd` failed for expected reason (`res://scripts/utils/ai/u_bt_planner_search.gd` missing).
- Style verification after test-file creation: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` passed (`60/60`).
- Commit 8 (GREEN) `97252380`: implemented `scripts/utils/ai/u_bt_planner_search.gd` with cost-optimal forward search, depth-cap rejection diagnostics, world-state effect application, and no-op self-chain suppression when effects do not change state.
- Commit 8 follow-through: updated `scripts/resources/ai/bt/rs_bt_planner_action.gd` to preserve runtime preconditions/effects during `Object.set(...)` assignment while keeping typed property-hint contracts (`Array[I_Condition]` / `Array[RS_WorldStateEffect]`) green.
- GREEN verification:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/bt/test_u_bt_planner_search.gd` passed (`8/8`).
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/bt/test_rs_bt_planner_action.gd` passed (`6/6`).
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` passed (`60/60`).
  - `tools/run_gut_suite.sh` passed (`4539` passing, `8` pending, `0` failing).
- Commit 9 (RED) `0ad8c49d`: added `tests/unit/ai/bt/test_rs_bt_planner.gd`.
- Commit 10 (GREEN) `90ce7243`: implemented `scripts/resources/ai/bt/rs_bt_planner.gd` with plan caching, step progression, one-replan-on-failure behavior, and planner debug state writes (`last_plan`, `last_plan_cost`) to node-local state bag.
- Follow-up (GREEN) `07ba856a`: tightened `U_BTPlannerSearch` no-plan diagnostics and trimmed implementation to 113 LOC while preserving P1.6b contracts.
- Commit 11 (GREEN) `64de76f6`: wired planner debug snapshot propagation in `scripts/ecs/components/c_ai_brain_component.gd` (`get_debug_snapshot()` now merges `last_plan`/`last_plan_cost` from planner state bag data) and updated `scripts/demo/debug/debug_ai_brain_panel.gd` to render planner path + cost when present.
- Commit 11 verification:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/components/test_c_ai_brain_component.gd` passed (`16/16`).
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/debug/test_debug_ai_brain_panel.gd` passed (`4/4`).
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/bt/test_rs_bt_planner.gd` passed (`9/9`).
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` passed (`60/60`).
- Commit 12 (GREEN) `7364b41f`: enforced planner boundary/LOC style follow-through:
  - Added `scripts/utils/ai/u_bt_planner_runtime.gd` and refactored `scripts/resources/ai/bt/rs_bt_planner.gd` to 135 LOC while preserving planner behavior.
  - Extended `tests/unit/style/test_style_enforcement.gd` with:
    - `scripts/utils/bt/` AI-type boundary checks,
    - planner LOC caps (`rs_bt_planner.gd <= 149`, `u_bt_planner_search.gd <= 119`).
- Commit 12 verification:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` passed (`62/62`).
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/bt/test_rs_bt_planner.gd` passed (`9/9`).
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/bt/test_u_bt_planner_search.gd` passed (`9/9`).
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/components/test_c_ai_brain_component.gd` passed (`16/16`).
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/debug/test_debug_ai_brain_panel.gd` passed (`4/4`).
- Current verification (2026-04-18):
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/bt/test_rs_bt_planner.gd` passed (`9/9`).
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` passed (`62/62`).
  - `tools/run_gut_suite.sh` passed (`4553` passing, `8` pending, `0` failing).

---

## Milestone P1.7: Brain Component + Settings Refactor

- [x] **Commit 1** (RED) — `test_c_ai_brain_component_bt.gd` (`6385e68d`):
  - New `bt_state_bag: Dictionary` field.
  - `get_debug_snapshot()` (F16 pattern) now returns `{ active_path: Array[String], bt_state_keys: int }`.
  - Drops `current_task_queue`, `current_task_index`, `task_state`, `suspended_goal_state` — asserts these fields no longer exist (catches stale references).
- [x] **Commit 2** (GREEN) — Modify `scripts/ecs/components/c_ai_brain_component.gd` (`fbcaccd9`).
- [x] **Commit 3** (RED) — `test_rs_ai_brain_settings_bt.gd` (`54425b93`):
  - `root: RS_BTNode` export replaces `goals: Array[RS_AIGoal]`.
  - `evaluation_interval: float` preserved.
  - Load an existing `.tres` with the old `goals` field → `push_error` with path (loud migration failure).
- [x] **Commit 4** (GREEN) — Modify `scripts/resources/ai/brain/rs_ai_brain_settings.gd` (`bf2a734e`).

**P1.7 Verification**:
- [x] Component + settings tests green.
- [x] Compile errors in consumers are expected here (wired up in P1.8).

**P1.7 Completion Notes (2026-04-18)**:
- Commit 1 (RED) `6385e68d`: added `tests/unit/ecs/components/test_c_ai_brain_component_bt.gd` covering `bt_state_bag`, BT snapshot keys, and legacy runtime-field removal contract.
- Commit 2 (GREEN) `fbcaccd9`: refactored `C_AIBrainComponent` to remove GOAP task-queue/runtime-state fields and expose BT-focused debug snapshot output (`active_path`, `bt_state_keys`).
- Commit 3 (RED) `54425b93`: added `tests/unit/ai/resources/test_rs_ai_brain_settings_bt.gd` for BT root export + legacy goals migration-error contract.
- Commit 4 (GREEN) `bf2a734e`: migrated `RS_AIBrainSettings` to `root: RS_BTNode`, preserved `evaluation_interval`, and added deferred legacy-goals migration error emission with resource path.
- P1.7 targeted GREEN checks:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/components/test_c_ai_brain_component_bt.gd` passed (`3/3`).
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/resources/test_rs_ai_brain_settings_bt.gd` passed (`3/3`).
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` passed (`62/62`).
- Expected P1.7 fallout prior to P1.8 cutover:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/components/test_c_ai_brain_component.gd` currently fails (`9/16` passing) because assertions still target removed GOAP fields/snapshot keys.
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/resources/test_rs_ai_goal.gd` currently fails (`7/10` passing) because assertions still target removed `RS_AIBrainSettings.goals`.

---

## Milestone P1.8: System Integration — `S_AIBehaviorSystem` Cutover

- [x] **Commit 1** (RED) — `tests/unit/ai/integration/test_s_ai_behavior_system_bt.gd`:
  - Context construction unchanged (same ECS component refs passed through).
  - System calls `U_BTRunner.tick(brain.root, context, brain.bt_state_bag)` each phase.
  - Evaluation interval still honored.
  - `debug_snapshot` updated each tick (F16 pattern).
- [x] **Commit 2** (GREEN) — Rewrite `scripts/ecs/systems/s_ai_behavior_system.gd`:
  - Remove `U_AIGoalSelector`, `U_AIReplanner`, `U_AITaskRunner`, `U_AIContextBuilder` fields.
  - Keep `U_DebugLogThrottle`.
  - Single `U_BTRunner` instance.
- [x] **Commit 3** (GREEN) — Update `scripts/demo/debug/debug_ai_brain_panel.gd` to render active BT path from `get_debug_snapshot()` instead of goal + queue.

**P1.8 Verification**:
- [x] System integration tests green.
- [x] Debug panel renders without errors in-editor.

**P1.8 Completion Notes (2026-04-18)**:
- Commit 1 (RED) `fee01ce5`: added `tests/unit/ai/integration/test_s_ai_behavior_system_bt.gd`.
- Commit 2 (GREEN) `301b39be`: rewrote `scripts/ecs/systems/s_ai_behavior_system.gd` to execute BT roots via `U_BTRunner`, preserved evaluation-interval gating, and retained context construction contract.
- Commit 3 (GREEN) `2b04de39`: updated tracking docs after cutover.
- Commit 4 (GREEN) `a3f4bc33`: patched follow-through gaps in the cutover.
- BT snapshot follow-through: `scripts/ecs/components/c_ai_brain_component.gd` now forwards `entity_id` and planner debug (`last_plan`, `last_plan_cost`) from runtime BT state so the panel can render planner details without legacy GOAP task-state fields.
- Verification commands (passing at P1.8 completion time):
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/integration/test_s_ai_behavior_system_bt.gd` (`3/3`)
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/debug/test_debug_ai_brain_panel.gd` (`4/4`)
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/components/test_c_ai_brain_component_bt.gd` (`3/3`)
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` (`62/62`)
- Known full-suite fallout remains expected pre-P1.10 cleanup: legacy GOAP-content tests/resources (for example AI demo brains and GOAP-oriented AI suites) still fail until BT content migration updates and legacy deletions land.

---

## Milestone P1.9: Content Migration — Forest Creatures

For each creature, write an integration test asserting **behavior parity** with the current implementation, then author the BT `.tres`.

- [x] **Commit 1** (RED) — `tests/unit/ai/integration/test_wolf_brain_bt.gd` (`26289494`):
  - Port existing wolf pack convergence test `tests/unit/ai/integration/test_pack_converges.gd` plus any adjacent coverage from `test_ai_pipeline_integration.gd` / `test_hunger_drives_goal_score.gd` / `test_ai_goal_resume.gd` that still applies under the BT model.
  - Assert: with prey detected + pack context, wolf executes move → wait → move → feed sequence.
  - Assert: without prey, wolf wanders.
  - Uses the new BT brain resource (file doesn't exist yet → red).
- [x] **Commit 2** (GREEN) — Author `resources/ai/forest/wolf/cfg_wolf_brain_bt.tres`:
  ```
  RS_BTUtilitySelector
  ├── hunt_pack sequence      scorer: RS_AIScorerCondition(pack_has_prey, 12, 0)
  ├── hunt_solo sequence      scorer: RS_AIScorerCondition(prey_detected, 10, 0)
  ├── search_food (cooldown 6s)  scorer: RS_AIScorerContextField("hunger", 6.0)
  └── wander                  scorer: RS_AIScorerConstant(1)
  ```
  Point `cfg_wolf_brain.tres`'s `root` to this tree. Old `goals` array removed.
- [x] **Commit 3** (RED+GREEN) — Deer: port flee/startle/graze/wander. `test_deer_brain_bt.gd` first, then `cfg_deer_brain_bt.tres` (`7de2a6cf`).
- [x] **Commit 4** (RED+GREEN) — Rabbit: same shape as deer minus startle (`c1d7b0fb`).
- [x] **Commit 5** (RED+GREEN) — Sentry, patrol_drone, guide_prism: port each. Smaller trees; one commit per creature acceptable (`a2766455`).
- [x] **Commit 6** (RED+GREEN) — **Planner showcase**: upgraded wolf `hunt_pack` to route through `RS_BTPlanner` with a concrete action pool (`planner_pack_close_in`, `planner_pack_hold`, `planner_pack_reacquire`, `planner_pack_feed`) and world-state preconditions/effects (`is_player_in_range`, `hunger`, `planner_stage`). Added planner-plan debug assertion coverage in `test_wolf_brain_bt.gd`, then authored planner wiring in `cfg_wolf_brain_bt.tres` plus runtime world-state context follow-through (`entity_query` propagation and context-aware world-state builder input). Other creatures remain utility-only BTs.

**P1.9 Verification**:
- [x] All per-creature integration tests green.
- [x] Pre-existing AI forest scene renders and creatures behave at parity — wolf now loads canonical brain with planner; all integration tests green (P1.9 Remediation).
- [ ] **Manual check**: launch the AI forest demo scene, observe wolf with prey + pack for 30+ seconds; `debug_ai_brain_panel` should surface `last_plan`/`last_plan_cost` for wolves in hunt_pack. Tick only after this passes.

**P1.9 Progress Notes (2026-04-18)**:
- Commit 1 (RED) `26289494`: added `tests/unit/ai/integration/test_wolf_brain_bt.gd` with hunt-pack sequence and wander-branch parity assertions targeting `res://resources/ai/forest/wolf/cfg_wolf_brain_bt.tres`.
- RED verification command: `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/integration/test_wolf_brain_bt.gd` fails for expected reason (`cfg_wolf_brain_bt.tres` missing).
- Commit 2 (GREEN) `fffa2e55`: authored `resources/ai/forest/wolf/cfg_wolf_brain_bt.tres` with utility-scored `hunt_pack` / `hunt_solo` / `search_food` / `wander` branches, migrated `resources/ai/forest/wolf/cfg_wolf_brain.tres` to BT `root`, and patched BT runtime context wiring in `S_AIBehaviorSystem` so action/cooldown decorators receive `delta` + `time`.
- Commit 2 follow-through test fix: adjusted `tests/unit/ai/integration/test_wolf_brain_bt.gd` fixture to set `prey.global_position` after `add_child` (prevents detached-node `global_transform` engine error in headless runs).
- Commit 3 (RED+GREEN) `7de2a6cf`: added `tests/unit/ai/integration/test_deer_brain_bt.gd`, confirmed expected RED failure for missing deer BT resource, then authored `resources/ai/forest/deer/cfg_deer_brain_bt.tres` and migrated `resources/ai/forest/deer/cfg_deer_brain.tres` to BT `root`.
- Commit 4 (RED+GREEN) `c1d7b0fb`: added `tests/unit/ai/integration/test_rabbit_brain_bt.gd`, confirmed expected RED failure for missing rabbit BT resource, then authored `resources/ai/forest/rabbit/cfg_rabbit_brain_bt.tres` and migrated `resources/ai/forest/rabbit/cfg_rabbit_brain.tres` to BT `root`.
- Commit 5 (RED+GREEN) `a2766455`: added `tests/unit/ai/integration/test_patrol_drone_brain_bt.gd`, `tests/unit/ai/integration/test_sentry_brain_bt.gd`, and `tests/unit/ai/integration/test_guide_prism_brain_bt.gd`; confirmed expected RED failures for missing BT resources; then authored:
  - `resources/ai/patrol_drone/cfg_patrol_drone_brain_bt.tres`
  - `resources/ai/sentry/cfg_sentry_brain_bt.tres`
  - `resources/ai/guide_prism/cfg_guide_brain_bt.tres`
  - `resources/ai/guide_prism/cfg_guide_showcase_brain_bt.tres`
  and migrated existing `cfg_*_brain.tres` sentry/patrol_drone/guide_prism resources to BT `root` definitions.
- Commit 6 (RED+GREEN) `2aacb999`: added planner-visibility RED assertion `test_wolf_hunt_pack_branch_reports_planner_plan_snapshot` in `tests/unit/ai/integration/test_wolf_brain_bt.gd` (confirmed failing with missing `last_plan`), then implemented wolf planner showcase wiring:
  - `resources/ai/forest/wolf/cfg_wolf_brain_bt.tres` now drives `hunt_pack` through `RS_BTPlanner` + `RS_BTPlannerAction` + `RS_WorldStateEffect`.
  - Added `scripts/resources/qb/conditions/rs_condition_context_field.gd` for flat world-state key evaluation.
  - `scripts/ecs/systems/s_ai_behavior_system.gd` now injects `entity_query` into BT runtime context.
  - `scripts/utils/ai/u_bt_planner_runtime.gd` and `scripts/utils/ai/u_ai_world_state_builder.gd` now support context-backed component maps for planner world-state construction.
- GREEN verification commands:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/integration/test_patrol_drone_brain_bt.gd` passes (`3/3`).
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/integration/test_sentry_brain_bt.gd` passes (`3/3`).
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/integration/test_guide_prism_brain_bt.gd` passes (`3/3`).
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/integration/test_rabbit_brain_bt.gd` passes (`3/3`).
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/integration/test_deer_brain_bt.gd` passes (`3/3`).
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/integration/test_wolf_brain_bt.gd` passes (`2/2`).
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/integration/test_s_ai_behavior_system_bt.gd` passes (`3/3`).
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/integration/test_wolf_brain_bt.gd` passes (`3/3`) with planner snapshot assertion.
  - Rechecks pass: `test_s_ai_behavior_system_bt.gd` (`3/3`), `test_deer_brain_bt.gd` (`3/3`), `test_rabbit_brain_bt.gd` (`3/3`), `test_patrol_drone_brain_bt.gd` (`3/3`), `test_sentry_brain_bt.gd` (`3/3`), `test_guide_prism_brain_bt.gd` (`3/3`).
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/bt/test_u_ai_world_state_builder.gd` passes (`3/3`).
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/bt/test_rs_bt_planner.gd` passes (`9/9`).
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` still fails on pre-existing unrelated guard (`S_AIBehaviorSystem` LOC cap, 248 > 199).
  - `tools/run_gut_suite.sh` remains expected pre-P1.10 fallout territory due unmigrated legacy GOAP-era consumers.

**P1.9 Remediation Notes (2026-04-18)**:
- Commit 1 (GREEN) `91c094c0`: merged RS_BTPlanner + RS_BTPlannerAction + RS_WorldStateEffect subtree from `cfg_wolf_brain_bt.tres` into `cfg_wolf_brain.tres`; deleted `cfg_wolf_brain_bt.tres`; repointed `test_wolf_brain_bt.gd` to canonical path.
- Commit 2 (GREEN) `d7f8567a`: confirmed byte-identity of 6 remaining `_bt.tres` duplicates (deer, rabbit, sentry, patrol_drone, guide_brain, guide_showcase); deleted all 6; repointed 5 integration tests to canonical paths.
- Commit 3 (GREEN) `668af269`: extracted `_build_context`, `_inject_role_keyed_detection`, `_resolve_root_id` from `S_AIBehaviorSystem` into new `scripts/utils/ai/u_ai_context_assembler.gd`; system drops from 247 → 180 lines, satisfying `test_ai_behavior_system_stays_under_two_hundred_lines`.
- Commit 4 (GREEN) `f741df2d`: added `U_DebugLogThrottle.log_message()` (TDD: `test_log_message_method_exists_and_does_not_throw`); replaced 2 bare `print(` calls in `S_AIBehaviorSystem` with `_debug_log_throttle.log_message(...)`; added `test_ai_behavior_system_has_no_bare_print_calls` style assertion.
- Commit 5 (RED+GREEN) `8ef32d5f`: added `test_bt_general_does_not_reference_planner_runtime_utils` asserting `U_BTPlannerSearch`/`U_BTPlannerRuntime` absent from general BT dirs; ticked P1.6b lazy-reference verification item.
- Commit 6 (GREEN) `e416469c`: deleted 4 full GOAP-era integration tests (`test_pack_converges`, `test_hunger_drives_goal_score`, `test_ai_goal_resume`, `test_ai_pipeline_integration`); trimmed 7 failing assertions from `test_c_ai_brain_component.gd` and 4 from `test_rs_ai_goal.gd` that assert removed GOAP fields.
- File inventory change: 7 `_bt.tres` files deleted (1 wolf + 6 others), 1 `u_ai_context_assembler.gd` created, `S_AIBehaviorSystem` shrunk 67 LOC, 2 new style assertions, ~1600 lines of superseded test code removed.

**P1.9 Post-Cut Note (2026-04-18)**:
- Commit `16eed2c4` ("cut ai forest") removed the entire forest demo (40 files, ~4271 lines): `scenes/gameplay/gameplay_ai_forest.tscn`, all forest prefabs, all `resources/ai/forest/**`, `resources/scene_registry/cfg_ai_forest_entry.tres`, `tests/unit/gameplay/test_forest_ecosystem_smoke.gd`, all per-creature BT integration tests, and `debug_forest_agent_label.gd`. `cfg_game_config.retry_scene_id` flipped from `&"ai_forest"` back to `&"alleyway"`. The BT stack itself is unchanged; only the authored content was cut.

---

## Milestone P1.9b: Woods Replacement Scene

Replace the deleted forest demo with a house-building-agent showcase that exercises the same BT+HTN+detection stack under a new scenario. Scope is forest-parity (3 AI archetypes + resource nodes + 1 authored scene) with a new full action set for harvest/haul/build-stage. Plan file: `~/.claude/plans/we-deleted-the-forest-ticklish-tarjan.md`.

Archetypes: **Builder** (primary; gather→haul→build loop), **Wolf** (threat; reincarnated forest brain), **Rabbit** (passive; reincarnated forest brain).

- [x] **Commit 1** (RED) — `tests/unit/ai/integration/test_builder_brain_bt.gd` (`348802ca`):
  - With inventory empty + build site missing wood + no threats, builder selects `gather_wood` and queues move + harvest.
  - With inventory full, builder selects `haul_to_build_site`.
  - With placed_materials >= required_materials, builder selects `build_current_stage`.
  - Uses `res://resources/ai/woods/builder/cfg_builder_brain.tres` (does not exist → red).
- [x] **Commit 2** (GREEN) — New ECS components + settings resources + unit tests (`b2c67185`):
  - `scripts/ecs/components/c_resource_node_component.gd` + `scripts/resources/ai/world/rs_resource_node_settings.gd`
  - `scripts/ecs/components/c_inventory_component.gd` + `scripts/resources/ai/world/rs_inventory_settings.gd`
  - `scripts/ecs/components/c_build_site_component.gd` + `scripts/resources/ai/world/rs_build_site_settings.gd` + `scripts/resources/ai/world/rs_build_stage.gd`
  - `tests/unit/ecs/components/test_c_resource_node_component.gd`, `test_c_inventory_component.gd`, `test_c_build_site_component.gd`
- [x] **Commit 3** (GREEN) — New AI action resources + task_state key additions + action tests (`7a96c4b0`):
  - `rs_ai_action_harvest.gd`, `rs_ai_action_haul_deposit.gd`, `rs_ai_action_build_stage.gd`, `rs_ai_action_drink.gd`, `rs_ai_action_reserve.gd`
  - Extend `scripts/utils/ai/u_ai_task_state_keys.gd` with `HARVEST_ELAPSED`, `BUILD_ELAPSED`, `INVENTORY_RESERVED_TYPE`
  - `tests/unit/ai/actions/test_ai_actions_woods.gd` covers each action's start/tick/is_complete + task_state writes + side effects
- [x] **Commit 4** (GREEN) — Builder brain + condition-based scorers + integration test rewrite (`d2644cf3`):
  - `resources/ai/woods/builder/cfg_builder_brain.tres` (utility selector: drink / gather_wood / haul / build / wander)
  - Condition-based scorers replacing constant scorers for correct branch selection
  - `fill_ratio` on C_InventoryComponent, `materials_ready`/`refresh_materials_ready()` on C_BuildSiteComponent
  - `resources/base_settings/ai_woods/cfg_movement_woods.tres`, `cfg_needs_builder.tres`, `cfg_inventory_builder.tres`
- [x] **Commit 5** (RED+GREEN) — Woods wolf (`0bb07870`):
  - `tests/unit/ai/integration/test_woods_wolf_brain_bt.gd` (port forest wolf test against woods brain path)
  - `resources/ai/woods/wolf/cfg_woods_wolf_brain.tres` (utility-only, no planner: hunt_solo / search_food / wander)
  - `scenes/prefabs/prefab_woods_wolf.tscn`, `resources/base_settings/ai_woods/cfg_movement_woods_wolf.tres`, `cfg_needs_wolf.tres`
- [x] **Commit 6** (RED+GREEN) — Woods rabbit (`085c428d`):
  - `tests/unit/ai/integration/test_woods_rabbit_brain_bt.gd`
  - `resources/ai/woods/rabbit/cfg_woods_rabbit_brain.tres`, `scenes/prefabs/prefab_woods_rabbit.tscn`, `cfg_needs_rabbit.tres`
- [x] **Commit 7** (GREEN) — Static world prefabs + builder prefab + debug label (`73a66510`):
  - `prefab_woods_builder.tscn`, `prefab_woods_tree.tscn`, `prefab_woods_stone.tscn`, `prefab_woods_water.tscn`, `prefab_woods_stockpile.tscn`, `prefab_woods_construction_site.tscn` (4 stage visuals, initially hidden)
  - `scripts/demo/debug/debug_woods_agent_label.gd` + `scenes/debug/debug_woods_agent_label.tscn` (shows goal/task/thirst/hunger/inventory)
  - Resource node settings: `cfg_resource_node_wood.tres`, `cfg_resource_node_stone.tres`, `cfg_resource_node_water.tres`
  - `cfg_inventory_stockpile.tres`, `cfg_build_site_house.tres`, `cfg_needs_builder.tres`, `cfg_inventory_builder.tres`
- [x] **Commit 8** (GREEN) — Scene composition + registry (`cd2afbcf`):
  - `scenes/gameplay/gameplay_ai_woods.tscn` (top-down ortho cam; 1 builder + 1 wolf + 4 rabbits + 5 trees + 3 stones + 1 water + 1 stockpile + 1 construction site)
  - `resources/scene_registry/cfg_ai_woods_entry.tres`
  - `scripts/scene_management/helpers/u_scene_registry_loader.gd` — added CFG_AI_WOODS_ENTRY preload + array entry
  - `scripts/managers/m_scene_manager.gd` — replaced stale `ai_forest` with `ai_woods` in `_start_background_gameplay_preload()`
  - `resources/cfg_game_config.tres` — retry_scene_id changed from `&"alleyway"` to `&"ai_woods"`
- [x] **Commit 9** (RED+GREEN) — Ecosystem smoke test (`94d4b7c6`):
  - `tests/unit/gameplay/test_woods_ecosystem_smoke.gd` mirrors deleted `test_forest_ecosystem_smoke.gd`: load via `M_SceneManager` with `"instant"` transition, warmup 180+60 frames, assert brains tick, stable archetype authoring, resource harvest, and build-site stage progression within the observation window.
- [x] **Commit 10** (DOCS) — Update trackers:
  - Tick P1.9b boxes above, commit hashes, verification command outputs.
  - Update `cleanup-v8-continuation-prompt.md` Status + Next Task.
  - `AGENTS.md`: add one-line contract for each new component and action task_state contract.
- [x] **Commit 11** (GREEN+DOCS, 2026-04-22) — P1.9b remediation pass:
  - `tests/unit/gameplay/test_woods_ecosystem_smoke.gd`: fixed service lookup (`scene_manager`), removed warning-based skips, bootstraps `scenes/root.tscn` inside test scope.
  - `scripts/ecs/systems/s_ai_behavior_system.gd`: running BT actions now tick every physics frame; `evaluation_interval` gates re-evaluation only when there is no running BT state.
  - Resource reservation contract hardening:
    - `scripts/resources/ai/actions/rs_ai_action_harvest.gd` now validates inventory acceptance before node harvest and clears reservations after attempt.
    - `scripts/ecs/systems/s_resource_regrow_system.gd` clears stale reservations on regrow.
    - `scripts/ecs/components/c_resource_node_component.gd` now exposes `clear_reservation()` + `clear_reservation_if_owned(...)`.
  - Builder-authoring follow-through:
    - `resources/ai/woods/builder/cfg_builder_brain.tres` adds water-targeted drink movement, wood-only gather scan filter, and sets `evaluation_interval = 0.0`.
    - `scenes/gameplay/gameplay_ai_woods.tscn` fixes physics/movement marker script mapping and adds minimal `E_Player` node to satisfy root scene-manager spawn contract.
  - New/updated test coverage:
    - `tests/unit/ai/actions/test_ai_actions_woods.gd` adds regression tests for inventory-first harvest ordering, reservation release, and `RS_AIActionMoveToNearest` resource-type filters.
    - `tests/unit/ecs/components/test_c_resource_node_component.gd` adds reservation-clear helper coverage.
    - `tests/unit/ecs/systems/test_s_resource_regrow_system.gd` adds regrow reservation-clear coverage.
- [x] **Commit 12** (GREEN+DOCS, 2026-04-22) — Woods showcase verification fix:
  - Added `scripts/utils/ai/u_ai_action_position_resolver.gd` so AI actions resolve moving actor/target body positions before falling back to stale entity roots.
  - Updated movement-sensitive actions to use the resolver: `RS_AIActionMoveToNearest`, `RS_AIActionWander`, `RS_AIActionFleeFromDetected`, `RS_AIActionMoveToDetected`, and `RS_AIActionFeed`.
  - `U_AIContextAssembler` now injects the active scene `ecs_manager` into BT action context so scan/reserve/harvest/deposit/build actions can resolve authored scene targets.
  - Woods scene authoring now keeps the Builder out of `prey`, gives Wolf/Rabbit/Builder visible labels, pins the scene camera current, and frames the setpiece.
  - The first house stage now requires only wood, matching the current Builder gather loop.
  - Smoke coverage now asserts one Builder, one Wolf, four Rabbits, stable labels, Builder not prey, resource harvest, and build-site stage 0 -> 1 progression.

**P1.9b Verification**:
- [x] All new per-entity and action tests green (`test_builder_brain_bt` 9/9, `test_woods_wolf_brain_bt` 3/3, `test_woods_rabbit_brain_bt` 3/3, `test_ai_actions_woods` 15/15, `test_ai_actions_movement` 16/16, `test_ai_action_feed` 6/6, component tests passing, `test_s_resource_regrow_system` 1/1).
- [x] `test_woods_ecosystem_smoke.gd` fully green headless (`4/4`); verifies scene-manager load, AI brain tick, stable archetypes/labels, Builder not prey, resource harvest, and build-site stage 0 -> 1 progression.
- [x] `test_style_enforcement.gd` rerun; current result is `63/64` with the pre-existing unrelated CRT identifier failure in display scripts.
- [ ] **Manual check**: launch `scenes/root.tscn` and transition to `ai_woods` via `M_SceneManager`; within ~60s the builder harvests at least one tree, deposits at the stockpile/site, and the construction site advances stage 0 → stage 1 (visible mesh change). Headless parity is green; GUI visual confirmation still needs a manual pass.
- [x] No new `DirAccess.open(...)` calls; all resource arrays use `const … preload(...)` per mobile-compat memory note.

---

## Milestone P1.10: Legacy Deletion

Only after P1.9 is green and the demo scene has been manually verified.

- [x] **Commit 1** (GREEN) — Delete scripts:
  - `scripts/utils/ai/u_htn_planner.gd`
  - `scripts/utils/ai/u_htn_planner_context.gd`
  - `scripts/utils/ai/u_ai_replanner.gd`
  - `scripts/utils/ai/u_ai_goal_selector.gd`
  - `scripts/utils/ai/u_ai_task_runner.gd`
  - `scripts/utils/ai/u_ai_context_builder.gd` (fully replaced by BT context construction in `S_AIBehaviorSystem` per P1.8)
  - `scripts/utils/ai/u_ai_debug_formatter.gd`
  - `scripts/resources/ai/goals/rs_ai_goal.gd`
  - `scripts/resources/ai/tasks/` (entire dir)
  - Retained: `scripts/utils/ai/u_ai_task_state_keys.gd` (still used by `RS_BTAction` per P1.3 Commit 3; keeps F16 style enforcement intact).
- [x] **Commit 2** (GREEN) — Delete legacy tests (`test_u_htn_planner.gd`, `test_u_ai_goal_selector.gd`, `test_u_ai_replanner.gd`, `test_u_ai_task_runner.gd`, `test_u_ai_context_builder.gd`) plus remaining GOAP-only suites (`test_rs_ai_goal.gd`, `test_rs_ai_task.gd`, `test_s_ai_behavior_system_goals.gd`, `test_s_ai_behavior_system_tasks.gd`).
- [x] **Commit 3** (informational) — QB rule/scorer infra under `scripts/{utils,resources}/qb/` (`U_RuleScorer`, `RS_Rule`, `U_RuleSelector`, `U_RuleStateTracker`, `U_RuleValidator`, `scripts/resources/qb/conditions/`, `scripts/resources/qb/effects/`) is **kept** as the non-AI game-logic rules framework — see P3.5 Commit 12's `conditions_effects_rules.md` recipe. Only the AI-specific consumers are deleted in Commits 1–2. No code action in this commit; noted for clarity so reviewers do not re-open the delete-vs-keep question.
- [x] **Commit 4** (GREEN) — Style enforcement grep: `scripts/resources/ai/` contains zero references to `U_HTNPlanner`, `U_AIGoalSelector`, `RS_AIGoal`, `RS_AICompoundTask`, `RS_AIPrimitiveTask`.
- [x] **Commit 5** (GREEN) — Update `DEV_PITFALLS.md` / `AGENTS.md` — remove or edit any entries that reference deleted AI planner/goal-selector files, classes, or patterns.

**P1.10 Verification**:
- [x] Full test suite green.
- [ ] LOC delta roughly matches target (~300 net reduction; ~689 removed vs ~400 added).
- [x] No dangling imports.

**P1.10 Completion Notes (2026-04-22)**:
- Removed GOAP runtime + test surface and migrated remaining AI resource tests to BT contracts.
- Added deterministic legacy migration fixture at `tests/unit/ai/resources/fixtures/cfg_ai_brain_legacy_goals_fixture.tres` for `test_rs_ai_brain_settings_bt.gd`.
- Updated style guards after GOAP deletions (`tests/unit/style/test_style_enforcement.gd`) and removed move-target follower GOAP task-state fallback (`scripts/ecs/systems/s_move_target_follower_system.gd` + tests) to keep BT-only runtime paths.
- Verification:
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/ai -gdir=res://tests/unit/ecs/components -gdir=res://tests/unit/ecs/systems -gdir=res://tests/unit/debug -ginclude_subdirs=true` -> `928/928` passing (`0` failing).
  - Integration trio from `ai_unit_integration_20260422_203326.log` remains green:
    - `test_ai_interaction_triggers.gd` + `test_ai_demo_power_core.gd` + `test_ai_spawn_recovery_power_core.gd` -> `20/20` passing.
  - Historical (2026-04-22): `test_style_enforcement.gd` was `63/64` with pre-existing unrelated `test_no_crt_identifiers_in_display_scripts`.
  - Historical (2026-04-22): full-suite run still reported unrelated non-P1.10 failures (for example display scanline toggle, scene-manager endgame reset assertion, woods smoke audio-bus/env assertions).
- P1.10 docs-hygiene follow-through (2026-04-23):
  - Updated `AGENTS.md` AI-system contracts to BT-only runtime terminology; removed deleted GOAP/HTN utility/class references.
  - Updated `DEV_PITFALLS.md` stale GOAP-era wording to BT runtime terminology and current movement pipeline names.
  - Full suite status now green (user-verified in-thread handoff for this phase closeout).

---

# Phase 2 — Debug/Perf Extraction from Systems/Managers

**Goal**: Production code paths should not carry inline debug logging or perf probing. Route all inspection through shared utilities so managers/systems stay focused on their actual job.

**Starting state (not empty)**: Phase 2 is ~20% complete at plan time:
- `U_PerfProbe` already exists at `scripts/utils/debug/u_perf_probe.gd` (102 LOC, scope tracking, flush cadence, mobile auto-enable, zero-cost when disabled).
- `U_PerfProbe` is in active use across `s_floating_system.gd`, `s_landing_indicator_system.gd`, `s_wall_visibility_system.gd`, `s_region_visibility_system.gd`, `s_movement_system.gd`, `m_display_manager.gd`, `m_character_lighting_manager.gd`.
- `U_DebugLogThrottle` is a util but adoption is uneven.
- Sibling utils present: `u_perf_monitor.gd`, `u_perf_fade_bypass.gd`, `u_perf_shader_bypass.gd`, `u_ai_render_probe.gd` (specialized; out of scope for Phase 2 consolidation, but catalogued).

**Known pollution sites** (from `DEV_PITFALLS.md` and grep, 2026-04-17):
- Bare `print(` in managers (7 occurrences across 6 files): `m_save_manager.gd:2`, `m_vcam_manager.gd:1`, `m_run_coordinator_manager.gd:1`, `m_scene_manager.gd:1`, `m_scene_director_manager.gd:1`, `helpers/u_vcam_collision_detector.gd:1`.
- Bare `print(` in ECS systems: `s_floating_system.gd`, `s_landing_indicator_system.gd`, `s_wall_visibility_system.gd`, `s_region_visibility_system.gd`, `s_movement_system.gd` (5 files — note these already use `U_PerfProbe`; the prints may or may not be probe-adjacent and must be audited individually).
- Mobile camera perf probes (2026-04-08) scattered across camera managers/systems (documented in `DEV_PITFALLS.md`).

**Utility status**:
- `U_DebugLogThrottle` — exists; adopt uniformly in P2.3.
- `U_PerfProbe` — exists; Phase 2 locks in current behavior via tests and extends coverage. No rewrite.
- `U_DebugDraw` — new if audit shows it's needed. Optional.

## Milestone P2.1: Audit

- [x] **Commit 1** — `docs/guides/cleanup_v8/debug_perf_audit.md`: grep all managers + systems, catalog every `print`, `push_warning` (intentional warnings excluded), inline timer, and `DebugDraw`. Also catalog every `U_PerfProbe.start()`/`stop()` call site and every `U_DebugLogThrottle.tick(...)` / `log(...)` call site — to confirm the audit covers both pollution and the existing consolidation baseline. One row per site with file + line + category (pollution | consolidated | perf-probe | throttled-log).
  - Completed 2026-04-23 with command evidence and one-row-per-site inventories captured in `debug_perf_audit.md`.
  - Baseline counts captured for migration planning: `print`=`39`, `push_warning`=`57`, inline timer/frame API=`21`, `U_PerfProbe`=`20`, `U_DebugLogThrottle`=`1`.

## Milestone P2.2: `U_PerfProbe` test backfill

`U_PerfProbe` already exists. This milestone locks in its current behavior with a test suite, not a rewrite.

- [x] **Commit 1** (RED) — `tests/unit/utils/debug/test_u_perf_probe.gd`: scope start/end, zero-cost when disabled flag, accumulation (sample_count, total_usec, min/max), flush cadence (default 2s), mobile auto-enable behavior, reset semantics. Tests should fail until the test file is authored (no existing tests).
  - Completed in `93f10490`: moved coverage to the requested path and expanded contract assertions.
  - RED proof: `tools/run_gut_suite.sh -gtest=res://tests/unit/utils/debug/test_u_perf_probe.gd` failed `1/11` on `test_create_default_enabled_on_mobile`.
- [x] **Commit 2** (GREEN) — Verify existing `scripts/utils/debug/u_perf_probe.gd` passes every test. If any behavior diverges from tests, patch the source minimally and note the patch in the commit message. Do NOT rewrite from scratch.
  - Completed in `8f4ce20b`: minimal patch to `U_PerfProbe.create(...)` default-enabled resolution (`enabled == null` -> `U_MobilePlatformDetector.is_mobile()`) while preserving explicit bool overrides.
  - GREEN verification:
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/utils/debug/test_u_perf_probe.gd` -> `11/11` passing.
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` -> `64/64` passing.
- [ ] **Commit 3** (GREEN, optional) — If audit flagged `U_DebugDraw` as needed, scaffold it here under the same TDD pattern. Skip if audit shows no demand.

## Milestone P2.3: Migration

Convert the ~7 bare-print sites (per P2.1 audit) to either `U_DebugLogThrottle`, silent removal, or explicit `push_warning` (for genuine warnings). One commit per touched file to keep reviewable.

- [ ] **Commit 1+** (per file, RED+GREEN pair per file) — RED adds a grep test forbidding bare `print(` in that specific file; GREEN migrates the bare prints.
- [x] Manager file complete: `m_save_manager.gd` (`48d60305` RED guard + `5e0911ac` GREEN migration).
- [x] Manager file complete: `m_vcam_manager.gd` (`4bcf7111` RED guard + `16c5c6f0` GREEN migration).
- [x] Manager file complete: `m_run_coordinator_manager.gd` (`18bf9075` RED guard + `0d9a2683` GREEN migration).
- [x] Manager file complete: `m_scene_manager.gd` (`ef4743fa` RED guard + `8ff6c203` GREEN migration).
- [x] Manager file complete: `m_scene_director_manager.gd` (`10d7ca7f` RED guard + `24073e62` GREEN migration).
- [x] Manager file complete: `scripts/managers/helpers/u_vcam_collision_detector.gd` (`fd9e7d0d` RED guard + `a227e8b5` GREEN migration).
- [x] ECS system file complete: `scripts/ecs/systems/s_victory_handler_system.gd` (`9b91b977` RED guard + `c4438ff0` GREEN migration).
- [x] ECS system file complete: `scripts/ecs/systems/s_spawn_recovery_system.gd` (`34850084` RED guard + `19307d8b` GREEN migration).
- [x] ECS system file complete: `scripts/ecs/systems/s_gravity_system.gd` (`7650556b` RED guard + `01f2fccb` GREEN migration).
- [x] ECS system shared debug-routing follow-through: `scripts/ecs/systems/{s_ai_detection_system,s_floating_system,s_input_system,s_move_target_follower_system,s_movement_system,s_rotate_to_input_system,s_gravity_system,s_spawn_recovery_system,s_victory_handler_system}.gd` (`6fc2d089` RED + `07892b12` GREEN).
- [x] ECS system-helper files migrated: `scripts/ecs/systems/helpers/{u_vcam_debug,u_vcam_look_input,u_vcam_look_spring}.gd` (`c6a3ac25` RED + `d4fb4047` GREEN).

## Milestone P2.4: Enforcement

- [x] **Commit 1** — Style enforcement: `scripts/managers/**/*.gd` and `scripts/ecs/systems/**/*.gd` contain zero bare `print(` calls. Debug output must route through `U_DebugLogThrottle` or `U_PerfProbe`.
  - Completed in `28702b95`: added `test_managers_and_ecs_systems_have_no_bare_print_calls` + `_collect_bare_print_calls(...)` in `tests/unit/style/test_style_enforcement.gd`.
  - Verification: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` passes (`83/83`).

**P2 Verification**:
- [x] Audit doc complete and signed off.
- [x] `U_PerfProbe` test suite green; existing call sites unchanged.
- [x] All bare-print migrations green.
- [x] Style enforcement green.
- [x] Release build has zero debug overhead (perf probe disabled flag verified by mobile profiling session). Note: All demo AI action bare print() calls migrated to U_DebugLogThrottle gated by @export debug_logging: bool = false; core scripts already used throttle pattern.

---

# Phase 3 — Split AGENTS.md + DEV_PITFALLS.md

**Goal**: `AGENTS.md` and `DEV_PITFALLS.md` have grown to the point where LLMs and humans can't cheaply load just the relevant section. Split by audience and concern.

**Authorization scope (important)**: Phase 3 creates ~26 docs (18 extension recipes + 5 ADRs + 1 ADR amendment + 2 READMEs + structure tests). Per the standing `CLAUDE.md` rule (*"Do not create documentation unless I tell you to do so"*) and the `feedback_docs_only_scope` memory, committing the V8 plan does **not** blanket-authorize every doc creation in Phase 3. Each recipe commit requires a separate user check-in at the tail of its owning phase (e.g., `ai.md` after P1.10 needs user sign-off before landing). ADRs are authored per-phase tail, not batched. READMEs, structure-test code, and AGENTS.md/DEV_PITFALLS.md splits (P3.3 Commits 1–3) are covered by this plan commit.

## Milestone P3.0: Pre-Migration Docs Reorg

Completed 2026-04-23. This milestone reshaped the docs tree before AGENTS/DEV_PITFALLS split work.

- [x] **Commit 1** — Reconciled ADR conventions to numeric `NNNN-kebab.md` under `docs/architecture/adr/`:
  - `0001-channel-taxonomy.md` preserved at `0001`
  - `ADR-001..004` renamed to `0002..0005`
  - Existing ADR references updated to numeric filenames
- [x] **Commit 2** — Moved the legacy channel-taxonomy ADR path into `docs/architecture/adr/0001-channel-taxonomy.md` and removed the old top-level ADR directory.
- [x] **Commit 3** — Created `docs/history/` and moved frozen archives:
  - `cleanup_v1`, `cleanup_v2`, `cleanup_v3`, `cleanup_v4`, `cleanup_v4.5`, `cleanup_v5`, `cleanup_v6`, `cleanup_v7`
  - `interactions_refactor`, `quality_of_life_refactors`, `ui_layers_transitions_refactor`
  - `cleanup_v8` intentionally remains under `docs/guides/` until P3.6.
- [x] **Commit 4** — Consolidated system-specific docs under `docs/systems/` (audio/display/vcam/vfx/input/save/scene/state/UI/ECS/AI/etc.).
- [x] **Commit 5** — Renamed the legacy general-guides root to `docs/guides/` and updated references.

**P3.0 Verification**:
- [x] Legacy top-level ADR directory does not exist.
- [x] `docs/architecture/adr/` contains only numeric ADR filenames (`0001..0005`) and no `ADR-NNN-*.md`.
- [x] `docs/guides/` contains evergreen guides plus `cleanup_v8/` (temporary Phase 3 exception).
- [x] `docs/history/` contains all frozen cleanup/refactor planning directories listed above.
- [x] `docs/systems/` contains per-system documentation directories.
- [x] `docs/` root now contains exactly five subdirectories: `_templates/`, `architecture/`, `guides/`, `history/`, `systems/`.
- [x] Required style/organization check passed: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` (`83/83`).

---

## Milestone P3.1: Inventory

- [x] **Commit 1** — `docs/guides/cleanup_v8/docs_inventory.md` (path reflects P3.0 rename): section-by-section table of contents for both files with proposed new home for each section.
  - 44 DEV_PITFALLS sections + 19 AGENTS sections mapped to destinations with actions (move/merge/collapse/drop).
  - 16 new destination files identified; 13 existing files receive content; 29-commit migration sequence documented.

## Milestone P3.2: Target Structure

- [x] **Commit 1** — Confirmed target structure for P3.3 migration.
  - `docs_inventory.md` is the authoritative source for destination ownership and commit sequence.
  - Existing tracked pitfall files under `docs/guides/pitfalls/` are retained and filled out by P3.3 instead of recreated.
  - Cross-cutting architecture files stay directly under `docs/architecture/`; `docs/architecture/extensions/` is introduced later by P3.5.
  - `AGENTS.md` remains the repo-root routing index and must stay under 150 lines after P3.3.

Final layout:

```
docs/
├── _templates/                  # existing; prompt/plan scaffolding
├── architecture/
│   ├── adr/                     # decision records (numeric NNNN-*.md)
│   ├── extensions/              # "how to add a feature" recipes (P3.5)
│   ├── dependency_graph.md      # cross-cutting architecture map
│   └── ecs_state_contract.md    # cross-cutting ECS/state contract
├── guides/                      # evergreen developer-facing docs (was docs/guides/)
│   ├── STYLE_GUIDE.md
│   ├── SCENE_ORGANIZATION_GUIDE.md
│   ├── ARCHITECTURE.md          # ECS + state store + managers overview (from AGENTS.md)
│   ├── COMMIT_WORKFLOW.md       # RED/GREEN discipline, commit message style (from AGENTS.md)
│   └── pitfalls/
│       ├── GODOT_ENGINE.md      # from DEV_PITFALLS.md
│       ├── GDSCRIPT_4_6.md      # from DEV_PITFALLS.md
│       ├── TESTING.md           # from DEV_PITFALLS.md test pitfalls
│       ├── MOBILE.md            # from DEV_PITFALLS.md patterns
│       ├── ECS.md
│       └── STATE.md
├── systems/                     # per-manager/system docs (was root-level dirs)
│   ├── audio_manager/
│   ├── vcam_manager/
│   └── ...
└── history/                     # frozen planning archives
    ├── cleanup_v1..v8/
    ├── interactions_refactor/
    └── ...
```

Root `AGENTS.md` stays at repo root as the thin routing entry point.

**P3.2 Completion Notes (2026-04-23)**:
- Confirmed the P3.2 target structure against the current docs tree and P3.1 inventory.
- Adjusted the proposed layout to match existing tracked files: `docs/guides/pitfalls/GODOT_ENGINE.md`, `GDSCRIPT_4_6.md`, `ECS.md`, `STATE.md`, and `MOBILE.md` already exist; P3.3 will continue filling/moving content and add only the missing destinations listed in `docs_inventory.md`.
- Kept architecture cross-cutting files directly under `docs/architecture/` instead of introducing an extra `docs/architecture/systems/` bucket.
- Verification: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` passed (`83/83`).

## Milestone P3.3: Migration

- [x] **Commit 1** — `docs/guides/pitfalls/GODOT_ENGINE.md` (DEV_PITFALLS §1–5).
  - Completed in `5a33f386`.
- [x] **Commit 2** — `docs/guides/pitfalls/GDSCRIPT_4_6.md` (DEV_PITFALLS §7, §28).
  - Completed in `c23319fa`.
- [x] **Commit 3** — `docs/guides/pitfalls/ECS.md` (DEV_PITFALLS §29).
  - Completed in `c7fbe1a8`.
- [x] **Commit 4** — `docs/guides/pitfalls/STATE.md` (DEV_PITFALLS §23, §30).
  - Completed in `c7fbe1a8`.
- [x] **Commit 5** — `docs/guides/pitfalls/MOBILE.md` (DEV_PITFALLS §40).
  - Completed in `cbb8617d`.
- [x] **Commit 6** — `docs/guides/pitfalls/TESTING.md` (DEV_PITFALLS §8, §9, §31, §32, §39; AGENTS §6f, §18).
  - Migrated GUT, headless, asset-import, dependency-injection, test-command, and test-coverage limitation guidance into the dedicated testing pitfalls file.
  - Replaced migrated `DEV_PITFALLS.md` sections and AGENTS testing snippets with routing pointers.
  - Verification: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` passed (`83/83`).
- [x] **Commit 7** — `docs/systems/vcam_manager/vcam-pitfalls.md` (DEV_PITFALLS §6, §13–20, §36).
  - Migrated room-fade, QB camera-rule, vCam scene-wiring, orbit/soft-zone/OTS/fixed, wall-visibility, silhouette, touch-look, stale-frame, rotation-smoothing, and mode-continuity pitfalls into the dedicated vCam pitfalls file.
  - Replaced migrated `DEV_PITFALLS.md` sections with routing pointers.
  - Verification: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` passed (`83/83`).
- [x] **Commit 8** — `docs/systems/lighting_manager/lighting-manager-overview.md` (AGENTS §7e; DEV_PITFALLS §21).
  - Migrated character lighting resource, blend math, zone controller, material applier, manager runtime, scene authoring, and pitfall guidance into the dedicated lighting manager overview.
  - Replaced migrated `AGENTS.md` and `DEV_PITFALLS.md` sections with routing pointers.
  - Verification: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` passed (`83/83`).
- [x] **Commit 9** — `docs/systems/ui_manager/ui-manager-overview.md` (AGENTS §7b, §7c, §13).
  - Migrated UI navigation state/action, registry, base class, theme pipeline, motion pipeline, and settings-panel guidance into the dedicated UI manager overview.
  - Replaced migrated `AGENTS.md` sections with routing pointers.
  - Verification: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` passed (`83/83`).
- [x] **Commit 10** — `docs/systems/ui_manager/ui-pitfalls.md` (DEV_PITFALLS §22, §37, §38, §41).
  - Migrated UI navigation, focus, signal-wiring, UI/Input boundary, pause-flow, settings-panel, and tab-navigation pitfalls into the dedicated UI pitfalls file.
  - Replaced migrated `DEV_PITFALLS.md` sections with routing pointers.
  - Verification: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` passed (`83/83`).
- [x] **Commit 11** — `docs/systems/scene_manager/scene-manager-overview.md` (AGENTS §12; DEV_PITFALLS §27, §34).
  - Migrated Scene Manager registration, transitions, overlays, triggers, spawn points, persistence, camera blending, cache/loading, and transition pitfall guidance into the dedicated Scene Manager overview.
  - Replaced migrated `AGENTS.md` and `DEV_PITFALLS.md` sections with routing pointers.
  - Verification: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` passed (`83/83`).
- [x] **Commit 12** — `docs/systems/input_manager/input-manager-overview.md` (DEV_PITFALLS §35).
  - Migrated Input Manager ownership, runtime contracts, mobile input, device detection, reserved pause binding, and test-state pitfalls into the dedicated Input Manager overview.
  - Replaced migrated `DEV_PITFALLS.md` section with a routing pointer.
  - Verification: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` passed (`83/83`).
- [x] **Commits 13–27** — Completed remaining destination-file migrations.
  - Commit 13: `docs/systems/ecs/ecs_architecture.md` ECS runtime contracts.
  - Commit 14: `docs/systems/qb_rule_manager/qb-v2-overview.md` QB rule contracts/pitfalls.
  - Commit 15: `docs/systems/ai_system/ai-system-overview.md` BT runtime contracts/pitfalls.
  - Commit 16: `docs/systems/vfx_manager/vfx-manager-overview.md` VFX runtime contracts/pitfalls.
  - Commit 17: `docs/systems/vcam_manager/vcam-manager-overview.md` vCam runtime contracts.
  - Commit 18: `docs/systems/scene_director/scene-director-overview.md` objectives/director contracts.
  - Commit 19: `docs/systems/localization_manager/localization-manager-overview.md` localization contracts.
  - Commit 20: `docs/systems/time_manager/time-manager-overview.md` time manager contracts.
  - Commit 21: `docs/systems/save_manager/save-manager-overview.md` save manager contracts/pitfalls.
  - Commit 22: `docs/systems/audio_manager/AUDIO_MANAGER_GUIDE.md` audio contracts.
  - Commit 23: `docs/systems/display_manager/display-manager-overview.md` display contracts/pitfalls.
  - Commit 24: `docs/guides/STYLE_GUIDE.md` style/resource hygiene.
  - Commit 25: `docs/guides/SCENE_ORGANIZATION_GUIDE.md` scene/interactable routing.
  - Commit 26: `docs/guides/ARCHITECTURE.md` architecture routing guide.
  - Commit 27: `docs/guides/COMMIT_WORKFLOW.md` commit workflow guide.
- [x] **Final AGENTS commit** — Shrink `AGENTS.md` to a routing index (~100 lines target, 150 hard cap — matches P3 Verification).
  - Completion notes: `AGENTS.md` is now 57 lines.
- [x] **Final pitfalls commit** — Delete `DEV_PITFALLS.md` once contents fully redistributed.
  - Completion notes: `AGENTS.md` is now a 57-line routing index, `docs/guides/DEV_PITFALLS.md` was deleted, and active references were redirected to focused `docs/guides/pitfalls/**` or system overview docs.

## Milestone P3.4: Decision ADRs — "Why We Chose X"

V7.2 F5 created `docs/architecture/adr/0001-channel-taxonomy.md`. V8 moves ADRs under `docs/architecture/adr/` so decision records live under the architecture bucket, while extension recipes live separately under `docs/architecture/extensions/`. V8 makes several structural decisions worth recording so future contributors (and LLMs) can audit *why* without reverse-engineering from code or git history.

- [x] **Commit 0** (migration) — ADR directory already normalized under `docs/architecture/adr/` during P3.0.

**ADR template** (mirror `0001-channel-taxonomy.md`'s shape):

- Title + number + status (Accepted / Superseded / Deprecated)
- Context (what prompted the decision)
- Decision (what was chosen)
- Alternatives considered (brief pros/cons of each)
- Consequences (positive and negative)
- References (plan files, PRs, commit ranges)

**ADRs to author** (each lives at the tail of its owning phase, not batched):

- [x] **Commit 1** (tail of P1) — `docs/architecture/adr/0006-ai-architecture-utility-bt-with-scoped-planning.md`:
  - Decision: utility-scored behavior trees with opt-in `RS_BTPlanner` for planning.
  - Alternatives: full GOAP + MBT, keep GOAP + HTN, plain BT without scoring.
  - References: `~/.claude/plans/whats-a-better-approach-snoopy-candle.md`, Phase 1 commits.
- [x] **Commit 2** (tail of P1) — `docs/architecture/adr/0007-bt-framework-scope-general-vs-ai-specific.md`:
  - Decision: general BT under `scripts/resources/bt/`; AI-specific leaves + planner under `scripts/resources/ai/bt/`.
  - Alternatives: AI-only; fully general with AI imports in core.
- [x] **Commit 3** (tail of P2) — `docs/architecture/adr/0008-debug-perf-utility-extraction.md`:
  - Decision: managers + ECS systems route debug through `U_DebugLogThrottle` / `U_PerfProbe`; bare `print()` forbidden.
  - Alternatives: inline guards, compile-time flags.
- [x] **Commit 4** (tail of P4) — `docs/architecture/adr/0009-template-vs-demo-separation.md`:
  - Decision: `scripts/core/` + `scripts/demo/` (same in `resources/`); enforced by import-boundary grep.
  - Alternatives: keep mixed; top-level `template/`/`game/`.
- [x] **Commit 5** (tail of P5) — `docs/architecture/adr/0010-base-scene-and-demo-entry-split.md`:
  - Decision: two scenes — existing `scenes/templates/tmpl_base_scene.tscn` (refactored in P5.2) + `scenes/demo/demo_entry.tscn`.
  - Alternatives: single scene with embedded demo menu; minimal-only.
- [x] **Commit 6** (tail of P3 itself) — amend `docs/architecture/adr/0005-service-locator.md` in-place (not a new file):
  - Add V7.2 F6 scope isolation clause (`push_scope`/`pop_scope` per-test) to Decision + Consequences sections.
  - Add "no Godot autoloads" clause (empty autoload list; codifies `CLAUDE.md` rule) to Decision + Consequences sections.
  - Bump Status line (e.g., `Status: Accepted (amended 2026-04-DD — V8 P3)`). Do not supersede; the original decision stands with clarifications.
  - Rationale for amendment (not new ADR): pre-existing `0005-service-locator.md` already records the service-locator decision; V8's additions are clarifications of the same decision, not a new one.

- [x] **Commit 7** — `docs/architecture/adr/README.md`: index with status + one-line summary per ADR.
- [x] **Commit 8** — Style enforcement: `test_adr_structure` asserts every `docs/architecture/adr/[0-9]{4}-*.md` has required sections (Status / Context / Decision / Alternatives / Consequences).

**P3.4 Verification**:
- [x] All 5 new decision ADRs (`0006..0010`) exist with required sections.
- [x] `docs/architecture/adr/0005-service-locator.md` amendment includes scope-isolation + no-autoloads clauses and an updated Status line.
- [x] `docs/architecture/adr/README.md` indexes all ADRs.
- [x] ADR structure test green.

---

## Milestone P3.5: Extension Recipes — "How to Add a Feature Here"

**Phase 3 deliverable (framework only)**: the P3.5 milestone *inside Phase 3* ships the `docs/architecture/extensions/` directory, the recipe template (spec below), the `README.md` routing scaffold (filled as recipes land), and `test_extension_recipe_structure.gd` structure test (Commits 19–20 below). The 18 individual recipe commits (1–18) are tracked here for provenance but each lands at the tail of its owning phase — not in Phase 3 itself. This prevents authoring recipes against code that's still being refactored in Phases 1/4/5. See also the sequencing note at the end of this milestone.

Separate from decision ADRs. Lives under `docs/architecture/extensions/` (new). One recipe per major subsystem, framed as a **derivation template**: after the subsystem is built, every new feature should be mechanical pattern-following.

The goal: "**read this recipe, follow the steps, ship the feature.**" If adding an N+1th AI behavior / vcam effect / state slice / ECS system requires more than the recipe, the recipe is incomplete.

**Relationship to ADRs**: each recipe links to its governing decision ADR(s). ADRs answer "why"; recipes answer "how to derive the next one."

**Recipe template** (derivation-focused):

- Title + status
- **When to use this recipe** — what kinds of features it covers (and what it doesn't)
- **Governing ADR(s)** — links to `docs/architecture/adr/*` for the "why"
- **Canonical example in the repo** — file paths of the reference implementation. New features are literal copy-edits of this.
- **Vocabulary** — the specific resource / class / file-name prefixes used in this subsystem
- **Recipe — "to add a new X"**:
  1. Create file at path
  2. Extend/implement interface
  3. Wire into registry / brain / manager
  4. Write test at path
  5. Run style enforcement
- **Anti-patterns** — known wrong ways to extend, with rationale
- **Out of scope** — pointers to other recipes when a feature crosses boundaries
- **References** — plan files, PRs, commit ranges

The recipes below each own one subsystem. Written after that subsystem stabilizes, so the recipe reflects real shipping code, not aspirational design. Grouped as **core** (every LLM-driven change likely touches one of these) and **secondary** (smaller systems, lower frequency of extension).

### Core recipes

- [ ] **Commit 1** — `docs/architecture/extensions/ai.md`:
  - Scope: adding new creatures, behaviors, actions, conditions, scorers, BT node types, planner actions.
  - Canonical example: wolf brain (hunt_pack uses `RS_BTPlanner`; other branches use pure utility-scored BT).
  - Recipes:
    - "To add a new creature" → author `cfg_<name>_brain.tres` at `resources/ai/<set>/<name>/`; wire into spawn registry; write integration test at `tests/unit/ai/integration/test_<name>_brain_bt.gd`.
    - "To add a new action" → implement `I_AIAction` in `scripts/resources/ai/actions/rs_ai_action_<verb>.gd`; reuse `U_AITaskStateKeys`; add `test_rs_ai_action_<verb>.gd`.
    - "To add a new BT node type" → decide scope (general → `scripts/resources/bt/`, AI-only → `scripts/resources/ai/bt/`); extend `RS_BTNode`/`RS_BTComposite`/`RS_BTDecorator`; add unit test.
    - "To add a new planner action" → extend `RS_BTPlannerAction` with preconditions/effects; add to a `RS_BTPlanner`'s pool; integration test must assert plan contains the new action for a chosen goal.
  - Anti-patterns: silent action stubs (must `push_error`), bare string keys in `task_state` (must use `U_AITaskStateKeys`), creating a new brain component alongside `C_AIBrainComponent`, authoring a new HTN-style planner (use `RS_BTPlanner` or extend scorers instead).
  - References: `~/.claude/plans/whats-a-better-approach-snoopy-candle.md`, Phase 1 commits.
  - **Authored at the tail of Phase 1** (after P1.10).

- [ ] **Commit 2** — `docs/architecture/extensions/state.md`:
  - Scope: adding new state slices, actions, reducers, subscribers.
  - Canonical example: one existing slice (pick the smallest clean one during authoring — e.g., the navigation slice referenced in V7.2 F3).
  - Recipes:
    - "To add a new slice" → define slice key constant; add reducer branch; declare slice dependencies (strict mode per V7.2 F4); add `test_<slice>_reducer.gd`.
    - "To add a new action" → create `U_<Domain>Actions` static dispatcher; action payload is a Dictionary; reducer matches on action id.
    - "To subscribe to state" → call `store.subscribe(slice_key, callable)`; treat snapshot as read-only (V7.2 F2 invariant); unsubscribe in `_exit_tree`.
  - Anti-patterns: direct `_state[...] =` mutation outside `m_state_store.gd` (V7.2 F3 grep test forbids), `slice_updated.emit` outside dispatch path, reading a slice without declaring the dependency (V7.2 F4 fails strict).
  - References: V7.2 F2–F5 ADRs and commits.

- [ ] **Commit 3** — `docs/architecture/extensions/vcam.md`:
  - Scope: adding new vcam effects, camera states, blend curves, pipeline stages.
  - Canonical example: an existing effect from `scripts/ecs/systems/helpers/u_vcam_*` (pick a post-F8 helper — e.g., `u_vcam_ground_anchor.gd`).
  - Recipes:
    - "To add a new vcam effect" → author helper under `scripts/ecs/systems/helpers/u_vcam_<effect>.gd` (< 400 LOC per F8 style rule); register with `U_VCamPipelineBuilder`; unit test at `tests/unit/ecs/systems/helpers/test_u_vcam_<effect>.gd`.
    - "To add a new camera state" → extend `U_CameraStateRuleApplier`'s rule set; define FOV/trauma/config deltas; integration test asserts state applies.
  - Anti-patterns: putting effect logic directly into `S_VCamSystem` (F8 forbids — process_tick < 80 lines), helpers > 400 LOC (F8 style enforcement), reading camera state outside the pipeline.
  - References: V7.2 F8 (Phase 0 + Phase 1).

- [ ] **Commit 4** — `docs/architecture/extensions/ecs.md`:
  - Scope: adding new ECS systems, components, events.
  - Canonical example: a small clean system (pick one during authoring — probably a post-F9 system with explicit `SystemPhase`).
  - Recipes:
    - "To add a new system" → `scripts/ecs/systems/s_<name>_system.gd` extends `BaseECSSystem`; declare explicit `SystemPhase` via `get_phase()` (F9); `process_tick` < 80 lines; helpers under `scripts/ecs/systems/helpers/` < 400 lines; register with `M_ECSManager`; add `test_s_<name>_system.gd`.
    - "To add a new component" → `scripts/ecs/components/c_<name>_component.gd`; expose `get_debug_snapshot()` if inspectable (F16 pattern); `COMPONENT_TYPE` constant.
    - "To add a new event" → define on the appropriate bus (ECS events → `U_ECSEventBus`, state → Redux dispatch per V7.2 F5 channel taxonomy); subscribers call `subscribe`/`unsubscribe`.
  - Anti-patterns: opaque integer priorities without a phase (F9 style enforcement fails), publishing manager-domain events onto `U_ECSEventBus` (V7.2 F5 ADR 0001 forbids), `Variant`-typed service fields in systems (F16 pattern).
  - References: V7.2 F5 (channel taxonomy), F9 (phasing), F16 (AI system type safety pattern).

- [ ] **Commit 5** — `docs/architecture/extensions/managers.md` — **core**:
  - Scope: adding new managers under the `Managers` node.
  - Governing ADRs: `0007` (service locator), V7.2 F5 ADR (channel taxonomy).
  - Canonical example: a small clean manager (pick during authoring — likely `m_save_manager` post-V7.2 F5).
  - Recipe:
    - "To add a new manager" → define `I_<Name>Manager` interface; implement `M_<Name>Manager` under `scripts/managers/`; register via `U_ServiceLocator.register()` (fails on conflict per V7.2 F6); no autoload; managers publish to Redux only, not `U_ECSEventBus` (V7.2 F5).
    - "To add a manager-UI wire" → Godot signal on the manager; UI controller subscribes (F5 channel taxonomy: manager↔UI uses signals).
  - Anti-patterns: adding a `project.godot` autoload (forbidden by CLAUDE.md + ADR 0007), `U_ECSEventBus.publish` from a manager (F5 grep test fails), last-write-wins replace without `register_or_replace()` (V7.2 F6).
  - References: V7.2 F5, F6.

- [ ] **Commit 6** — `docs/architecture/extensions/ui.md` — **core**:
  - Scope: adding overlays, panels, menus, settings screens, HUD elements.
  - Governing ADRs: V7.2 F5 (channel taxonomy: manager↔UI via signals), F12 (settings overlay base class pattern).
  - Canonical examples: `base_settings_simple_overlay.gd` for simple toggle/list settings (audio, display, localization); `ui_vfx_settings_overlay.gd` for Apply/Cancel flows.
  - Recipe:
    - "To add a simple settings screen" → extend `BaseSettingsSimpleOverlay` (F12); author `.tscn` with tab content; register with UI router.
    - "To add a custom panel" → extend `BasePanel` or `BaseMenuScreen`; subscribe to Redux state via `M_StateStore`; unsubscribe in `_exit_tree`.
    - "To wire a button to a manager action" → UI emits signal → controller calls `U_<Domain>Actions.<action>()` → reducer updates state → UI re-renders from subscription. Never call manager methods directly from UI nodes.
  - Anti-patterns: reading ECS state from UI, `await get_tree()` in UI init (use manager-deferred pattern), new BaseOverlay subclass when BaseSettingsSimpleOverlay suffices.
  - References: V7.2 F5, F12.

- [ ] **Commit 7** — `docs/architecture/extensions/scenes.md` — **core**:
  - Scope: adding scene registry entries, scene transitions, scene director routing, scene lifecycle hooks.
  - Governing ADRs: V7.2 C6 (scene manager decomposition), F15 (scene registry entry validation).
  - Canonical examples: an existing `RS_SceneRegistryEntry` `.tres`; `M_SceneManager._perform_transition`.
  - Recipe:
    - "To register a new scene" → create `RS_SceneRegistryEntry` `.tres` with `scene_id` + `scene_path` (F15 push_error validates non-empty); add to registry; cross-ref from `RS_GameConfig` if referenced.
    - "To add a transition effect" → extend `U_TransitionOrchestrator` with new effect; keep `_perform_transition` under 40 lines (V7.2 C6 rule).
    - "To add scene director routing" → dispatch `U_SceneDirectorActions`; reducer updates navigation slice; `M_SceneDirectorManager` subscribes.
  - Anti-patterns: reflection-based cross-manager access (V7.2 C6/F1 forbids `get("_camera_blend_tween")`), `U_ECSEventBus.publish` from scene manager (V7.2 F5).
  - References: V7.2 C6, F3, F5, F15.

- [ ] **Commit 8** — `docs/architecture/extensions/save.md` — **core**:
  - Scope: adding save slots, serializable fields, save migration.
  - Governing ADRs: V7.2 F3 (state mutation invariant), F5 (manager channel taxonomy).
  - Canonical example: `m_save_manager` post-V7.2 F5 with `u_save_actions.gd`.
  - Recipe:
    - "To add a new saved field" → add to state slice; include in `apply_loaded_state` path (V7.2 F3 `INVARIANT` comment applies); version migration if schema changed.
    - "To add a save slot" → dispatch `U_SaveActions.save_to_slot(id)`; `m_save_manager` subscribes and writes via reducer path, not direct state mutation.
  - Anti-patterns: direct `_state[...] =` in save manager (V7.2 F3 grep fails), `U_ECSEventBus.publish` (use Redux dispatch per F5).
  - References: V7.2 F3, F5.

- [ ] **Commit 9** — `docs/architecture/extensions/input.md` — **core**:
  - Scope: adding input actions, virtual buttons, input profiles.
  - Governing ADRs: F15 (input profile validation).
  - Canonical example: an existing `RS_InputProfile` `.tres` with `action_mappings` + `virtual_buttons`.
  - Recipe:
    - "To add a new input action" → add to `RS_InputProfile.action_mappings`; F15 setter validates structure; wire into input manager.
    - "To add a virtual button" → add to `virtual_buttons` (F15 `_validate_virtual_buttons` enforces structure); define position + action id.
  - Anti-patterns: bare `Input.is_action_pressed(...)` outside input manager; magic string action names (use constants).
  - References: V7.2 F15.

- [ ] **Commit 10** — `docs/architecture/extensions/audio.md` — **core**:
  - Scope: adding audio channels, sound events, music tracks, audio settings.
  - Canonical example: an existing audio manager call site (pick during authoring).
  - Recipe:
    - "To add a sound event" → define event id constant; register sound resource; trigger via audio manager API (not direct `AudioStreamPlayer`).
    - "To add a channel/bus" → add to audio bus layout; expose in settings via `base_settings_simple_overlay` pattern (F12).
  - Anti-patterns: `AudioStreamPlayer.play()` directly in gameplay code (bypasses channel routing), hardcoded volume values (use settings slice).
  - References: V7.2 F5, F12.

### Secondary recipes

- [ ] **Commit 11** — `docs/architecture/extensions/objectives.md`:
  - Scope: adding objectives, objective sets, victory routing.
  - Governing ADRs: V7.2 F5 (victory routing migrated to `ACTION_TRIGGER_VICTORY_ROUTING`), F15 (cross-reference boot validation for `default_objective_set_id`).
  - Canonical example: `m_objectives_manager` post-F5 migration.
  - Recipe:
    - "To add an objective" → `RS_Objective` `.tres`; assign to an objective set; `has_objective_set()` check at boot (F15).
    - "To add victory routing" → dispatch `ACTION_TRIGGER_VICTORY_ROUTING` (not `U_ECSEventBus.publish`).
  - Anti-patterns: ECS publishes from objectives manager (F5 forbids), dangling `default_objective_set_id` (F15 boot validation catches).
  - References: V7.2 F5, F15.

- [ ] **Commit 12** — `docs/architecture/extensions/conditions_effects_rules.md`:
  - Scope: adding `I_Condition`, `I_Effect`, `RS_Rule` entries (non-AI — game logic rules).
  - Governing ADRs: V7.2 F7 (typed schema erasure), condition/rule validator pattern.
  - Canonical example: an existing `RS_Rule` `.tres` with `conditions: Array[I_Condition]` + `effects: Array[I_Effect]`.
  - Recipe:
    - "To add a new condition" → implement `I_Condition`; F7 typed arrays + `_sanitize_children()` pattern applies to composites.
    - "To add a new effect" → implement `I_Effect`; similar pattern.
    - "To add a rule" → author `RS_Rule` `.tres`; `U_RuleValidator` double-checks at load.
  - Anti-patterns: `Array[Resource]` fallback on new typed arrays (F7 eliminated this), stale "headless parser stability" comments (F7 deleted).
  - References: V7.2 F7.

- [ ] **Commit 13** — `docs/architecture/extensions/events.md`:
  - Scope: adding event types to `U_ECSEventBus` or `U_StateEventBus`.
  - Governing ADRs: V7.2 F5 (channel taxonomy), F11 (zombie prevention).
  - Canonical example: an existing ECS event subscription.
  - Recipe:
    - "To add an ECS event" → define constant; publish from ECS component/system (F5 rule: ECS-only publishers); subscribers anywhere via `subscribe`/`unsubscribe`; unsubscribe in `_exit_tree` (F11 `_pending_unsubscribes` handles reentrancy).
    - "To choose a channel" → manager → Redux only; ECS → `U_ECSEventBus`; manager↔UI → Godot signal; everything else → method call.
  - Anti-patterns: publishing ECS events from managers (F5 grep fails), using `.duplicate()` snapshot in custom bus (F11 replaced this pattern).
  - References: V7.2 F5, F11.

- [ ] **Commit 14** — `docs/architecture/extensions/debug.md`:
  - Scope: adding debug panels, perf probes, log throttles, debug overlays.
  - Governing ADRs: `0004-debug-perf-utility-extraction.md` (V8 Phase 2).
  - Canonical examples: `U_DebugLogThrottle` call sites; `U_PerfProbe` from P2.
  - Recipe:
    - "To add a debug log site" → route through `U_DebugLogThrottle`, never bare `print()`.
    - "To add a perf probe" → `U_PerfProbe.scope_begin("tag") ... scope_end("tag")`; disabled on mobile config flag.
    - "To add a debug panel" → follow `debug_ai_brain_panel.gd` pattern (F16: read `get_debug_snapshot()` from component, not raw dict).
  - Anti-patterns: bare `print` in managers/systems (P2 style enforcement forbids), raw dict access in debug panels (F16 pattern violated).
  - References: V7.2 F16, V8 Phase 2.

- [ ] **Commit 15** — `docs/architecture/extensions/display_post_process.md`:
  - Scope: adding display presets, post-process presets, window size presets.
  - Canonical example: `M_DisplayManager` preset handling + preload arrays (mobile-compat pattern documented in `DEV_PITFALLS.md`).
  - Recipe:
    - "To add a preset" → extend the `const PRESETS := [preload(...)]` array (not DirAccess scanning — mobile-breaks). Pattern documented in `DEV_PITFALLS.md`.
    - "To add a post-process effect" → add to pipeline; guard tree-dependent init in `_ensure_appliers()`.
  - Anti-patterns: runtime `DirAccess.open()` for preset discovery (breaks on mobile — documented in `DEV_PITFALLS.md`), missing `_should_defer()` guard for window ops.
  - References: `DEV_PITFALLS.md` mobile compatibility notes.

- [ ] **Commit 16** — `docs/architecture/extensions/localization.md`:
  - Scope: adding translation keys, localized strings, language entries.
  - Canonical example: the existing localization settings overlay (F12 pattern).
  - Recipe:
    - "To add a translatable string" → never use `.tr()` on Script class refs (Godot 4.6 parse error documented in `DEV_PITFALLS.md`); use `localize()` or equivalent naming.
    - "To add a language" → author translation resource; register; expose in localization settings overlay.
  - Anti-patterns: `tr` as a static method name anywhere (parse error), hardcoded English strings in gameplay code.
  - References: `DEV_PITFALLS.md` GDScript 4.6 pitfalls.

- [ ] **Commit 17** — `docs/architecture/extensions/resources.md`:
  - Scope: adding designer-facing validated resources (game config, input profile, scene registry entry, etc.).
  - Governing ADRs: V7.2 F7 (typed-schema erasure), F15 (load-time schema validation).
  - Canonical examples: `RS_GameConfig`, `RS_InputProfile`, `RS_SceneRegistryEntry` post-F15.
  - Recipe:
    - "To add a validated resource" → property setters with `push_error` fail loud at load (F15 pattern); backing-field pattern consistent with F7 `_sanitize_*` setters; include `resource_path` in error messages.
    - "To add cross-reference validation" → boot-time check in `M_RunCoordinatorManager` (F15 pattern). `_init()` runs before autoloads — use property setters for local validation, boot pass for cross-registry.
  - Anti-patterns: `_init()` for per-field validation (runs before `.tres` property assignment — silently useless), `Array[Resource]` fallback (F7 eliminated).
  - References: V7.2 F7, F15.

- [ ] **Commit 18** — `docs/architecture/extensions/tests.md`:
  - Scope: adding test suites, test fixtures, style enforcement tests.
  - Governing ADRs: V7.2 F6 (service locator scope isolation).
  - Canonical examples: `BaseTest` + `tests/unit/style/test_style_enforcement.gd`.
  - Recipe:
    - "To add a unit test" → extend `BaseTest` (auto `push_scope`/`pop_scope` per F6 + `U_StateHandoff.clear_all()`); GUT naming `test_<name>()`; one test file per production file where practical.
    - "To add a style enforcement" → add assertion to `test_style_enforcement.gd`; grep-based; one test per rule.
  - Anti-patterns: redundant `U_ServiceLocator.clear()` in `before_each` (F6 scope isolation made this unnecessary), tests that extend `GutTest` directly when `BaseTest` suffices (loses scope isolation).
  - References: V7.2 F6.

- [x] **Commit 19** — `docs/architecture/extensions/README.md`:
  - Index of all recipes with a **Feature → Recipe** routing table so an LLM landing on "add an X" finds the right recipe in one hop.
  - Example row: `"Add a new AI behavior" → ai.md`.
  - Each entry lists the governing decision ADR(s) so the reader can jump to "why" if needed.
  - Update `AGENTS.md` to route to both `docs/architecture/adr/README.md` (decisions) and `docs/architecture/extensions/README.md` (recipes).

- [x] **Commit 20** — Style enforcement: `test_extension_recipe_structure` — every file matching `docs/architecture/extensions/*.md` (except `README.md`) must contain the required sections (`When to use`, `Governing ADR(s)`, `Canonical example`, `Vocabulary`, `Recipe`, `Anti-patterns`). Catches drift.

**P3.5 Verification**:
- [ ] All 18 recipes exist with required sections (10 core + 8 secondary).
- [ ] Each recipe references a real canonical example file that currently exists in the repo (not a placeholder).
- [x] `docs/architecture/extensions/README.md` routing table covers every subsystem.
- [ ] Each recipe links to its governing ADR(s).
- [ ] Recipe structure test green.
- [x] `AGENTS.md` routes to both `docs/architecture/adr/README.md` and `docs/architecture/extensions/README.md`.
- [ ] **Dogfood check**: pick one recipe; have it drive a trivial derivative feature (e.g., "add a no-op scorer" following `ai.md`). If the recipe doesn't suffice, it's incomplete.

**Sequencing note**: recipes are authored at the tail of their owning phase, not all at once. `ai.md` after P1.10. `ecs.md` depends on V7.2 F9 being landed. Phase 3's mechanical commits are the two `README.md` files + the two structure tests. Individual recipe commits move earlier, into the tail of each owning phase.

---

## Milestone P3.6: Archive `cleanup_v8/` itself

Tail of P3, after all other P3 milestones are green. Moves this plan into `docs/history/` now that it's frozen.

- [x] **Commit 1** — `git mv docs/guides/cleanup_v8 docs/history/cleanup_v8`. Update any remaining references (V8 continuation docs, MEMORY entries if any).
  - Completion notes: archived the V8 task checklist, continuation prompt, docs inventory, and debug/perf audit under `docs/history/cleanup_v8/`; updated AGENTS and ADR references to the archived paths.

---

**P3 Verification**:
- [ ] Every pre-existing section lives somewhere new.
- [x] `AGENTS.md` under 150 lines.
- [ ] No dangling cross-references.
- [x] `CLAUDE.md` project file still points at the right entry.
- [x] `docs/architecture/adr/` contains reconciled ADR set under one numeric convention + V8 ADRs + `README.md` — specifically: 5 pre-existing/V7.2 ADRs renumbered to `0001..0005` + 5 new V8 ADRs at `0006..0010` + amendment on `0005-service-locator.md` + `README.md`.
- [x] `docs/architecture/extensions/` contains `ai.md`, `state.md`, `vcam.md`, `ecs.md`, `managers.md`, `ui.md`, `scenes.md`, `save.md`, `input.md`, `audio.md`, `objectives.md`, `conditions_effects_rules.md`, `events.md`, `debug.md`, `display_post_process.md`, `localization.md`, `resources.md`, `tests.md` + `README.md`.
- [x] `docs/guides/`, `docs/history/`, `docs/systems/` exist per P3.0 structure; legacy pre-P3 roots (`docs/general/`, top-level ADR directory) no longer exist.

**Audit note (2026-04-24)**:
- Verified `AGENTS.md` is 54 lines, `DEV_PITFALLS.md` no longer exists, and ADR files `0001..0010` are present under `docs/architecture/adr/`.
- Authored the missing `scenes.md` and `resources.md` recipes; `docs/architecture/extensions/` now contains the full required recipe set.
- Fixed the AI extension recipe's canonical wolf test path and removed stale `DEV_PITFALLS.md` references from active tests.
- Added required-recipe coverage to `test_extension_recipe_structure`, so missing expected recipes now fail style enforcement.
- Removed remaining active non-history `DEV_PITFALLS.md` mentions; historical `docs/history/**` references remain as provenance.

---

# Phase 4 — Core Template vs Demo-Specific Separation

**Goal**: Someone cloning this template should be able to `rm -rf demo/` (or equivalent) and have a clean core template to build on. Today, forest creatures, sentry/drone/prism, and various demo scenes are interleaved with core systems.

## Milestone P4.1: Classification

- [x] **Commit 1** — `docs/guides/cleanup_v8/template_vs_demo.md`: every top-level dir classified as **core** (ECS framework, state store, managers, UI kits, input, audio, debug infra) or **demo** (forest AI, sentry/drone/prism, gameplay sample scenes, sample audio/vfx assets).

**P4.1 Completion Notes (2026-04-23)**:
- Classification doc covers `scripts/`, `resources/`, `scenes/`, `assets/`, and other top-level dirs.
- Mixed-directory decomposition identifies 9 dirs needing selective migration (not whole-dir moves).
- AI framework/content boundary: generic BT nodes + 10 generic AI actions = core; 5 demo actions + creature world types + all utils/ai/ = demo.
- Style enforcement green (86/86) after doc creation.

## Milestone P4.2: Target Structure

- [x] **Commit 1** — `docs/guides/cleanup_v8/target_structure.md`: comprehensive target directory layout for `scripts/core/`, `scripts/demo/`, `resources/core/`, `resources/demo/`, `scenes/core/`, `scenes/demo/`, `assets/demo/`. Includes classification corrections (5 `utils/ai/` files reclassified as core), file-level detail for mixed directories, migration order proposal (20 commits), and import/path update implications for P4.3.

**P4.2 Completion Notes (2026-04-23)**:
- Target structure doc covers all four top-level dirs (`scripts/`, `resources/`, `scenes/`, `assets/`) with `core/` and `demo/` subtrees.
- P4.1 classification corrections: 5 `scripts/utils/ai/` files reclassified from DEMO to CORE (consumed by core BT framework); `u_ai_render_probe.gd` reclassified from CORE to DEMO; `rs_ai_action_reserve.gd` classified as DEMO.
- Proposed migration order: demo scripts first (6 commits), then core scripts (8 commits), then resources/scenes/assets splits (4 commits), then project.godot updates (1 commit) — total ~20 atomic move commits.
- `scripts/core/audio/` from the original P4.2 proposal is removed (no `scripts/audio/` directory exists; audio managers live under `scripts/core/managers/`).
- Style enforcement green (86/86) after doc creation.

**Note**: `scripts/core/u_service_locator.gd` already exists (landed in cleanup_v1 as T141b). P4 extends `scripts/core/` in place rather than creating it. The existing file stays where it is; the other subtrees below are migration targets.

**Also note**: general BT framework (per Phase 1 decisions) lives at `scripts/resources/bt/` (general composites/decorators) + `scripts/resources/ai/bt/` (AI-specific leaves/scorers/planner) + `scripts/utils/bt/u_bt_runner.gd`. Under the core/demo split, the general `scripts/resources/bt/` + `scripts/utils/bt/` trees land under `core/`; `scripts/resources/ai/bt/` is still core (BT framework AI-specific bits — shared infra, not individual creature behaviors); only creature `.tres` brains and action scripts that describe specific demo creatures live under `demo/`.

```
scripts/
├── core/                    # template — framework code
│   ├── u_service_locator.gd # already present; unchanged
│   ├── ecs/
│   ├── state/
│   ├── managers/
│   ├── ui/
│   ├── input/
│   ├── audio/
│   ├── debug/
│   ├── resources/
│   │   ├── bt/              # general BT framework
│   │   └── ai/bt/           # AI-specific BT wrappers / scorers / planner (framework)
│   └── utils/bt/            # general BT runner
└── demo/                    # everything removable
    ├── ai/                  # creature action scripts + brain resources
    │   ├── forest/
    │   ├── sentry/
    │   ├── patrol_drone/
    │   └── guide_prism/
    └── gameplay/

resources/
├── core/                    # default configs, required resources
└── demo/
    └── ai/forest/...
```

## Milestone P4.3: Move

- [x] **Commit 1** (RED) — Grep test: `scripts/core/` never imports from `scripts/demo/`. (Reverse direction is fine.)
- [x] **Commit 2+** (GREEN) — Move files per classification. One commit per logical chunk (AI forest, sentry, demo gameplay scenes, etc). Update all imports. Update `.tres` resource paths.
- [x] **Commit N** (GREEN) — Update scene references, project settings, autoload paths.

**P4.3 Progress Notes (2026-04-24)**:
- RED boundary test landed in `0dba3719` as `test_core_scripts_never_import_from_demo`.
- First GREEN move chunk moved demo gameplay/debug scripts:
  - `scripts/gameplay/inter_ai_demo_flag_zone.gd` -> `scripts/demo/gameplay/inter_ai_demo_flag_zone.gd`
  - `scripts/gameplay/inter_ai_demo_guard_barrier.gd` -> `scripts/demo/gameplay/inter_ai_demo_guard_barrier.gd`
  - `scripts/gameplay/s_demo_alarm_relay_system.gd` -> `scripts/demo/gameplay/s_demo_alarm_relay_system.gd`
  - `scripts/debug/debug_ai_brain_panel.gd` -> `scripts/demo/debug/debug_ai_brain_panel.gd`
  - `scripts/debug/debug_woods_agent_label.gd` -> `scripts/demo/debug/debug_woods_agent_label.gd`
  - `scripts/debug/debug_woods_build_site_label.gd` -> `scripts/demo/debug/debug_woods_build_site_label.gd`
  - `scripts/utils/debug/u_ai_render_probe.gd` -> `scripts/demo/debug/utils/u_ai_render_probe.gd`
- Updated scene/test/doc references for those paths and added `scripts/demo/` prefix/style scanning.
- Verification: `test_ai_showcase_scene.gd` (`18/18`), `test_ai_demo_behavior_resources.gd` (`8/8`), `test_ai_interaction_triggers.gd` (`9/9`), `test_s_demo_alarm_relay_system.gd` (`3/3`), `test_debug_ai_brain_panel.gd` (`4/4`), `test_debug_woods_build_site_label.gd` (`2/2`), `test_u_ai_render_probe.gd` (`4/4`), and style guard (`87/87`) pass.
- Second GREEN move chunk landed in `df91cc4b` and moved demo ECS scripts:
  - `scripts/ecs/components/c_ai_brain_component.gd` -> `scripts/demo/ecs/components/c_ai_brain_component.gd`
  - `scripts/ecs/components/c_detection_component.gd` -> `scripts/demo/ecs/components/c_detection_component.gd`
  - `scripts/ecs/components/c_move_target_component.gd` -> `scripts/demo/ecs/components/c_move_target_component.gd`
  - `scripts/ecs/components/c_needs_component.gd` -> `scripts/demo/ecs/components/c_needs_component.gd`
  - `scripts/ecs/components/c_inventory_component.gd` -> `scripts/demo/ecs/components/c_inventory_component.gd`
  - `scripts/ecs/components/c_build_site_component.gd` -> `scripts/demo/ecs/components/c_build_site_component.gd`
  - `scripts/ecs/components/c_resource_node_component.gd` -> `scripts/demo/ecs/components/c_resource_node_component.gd`
  - `scripts/ecs/systems/s_ai_behavior_system.gd` -> `scripts/demo/ecs/systems/s_ai_behavior_system.gd`
  - `scripts/ecs/systems/s_ai_detection_system.gd` -> `scripts/demo/ecs/systems/s_ai_detection_system.gd`
  - `scripts/ecs/systems/s_move_target_follower_system.gd` -> `scripts/demo/ecs/systems/s_move_target_follower_system.gd`
  - `scripts/ecs/systems/s_needs_system.gd` -> `scripts/demo/ecs/systems/s_needs_system.gd`
  - `scripts/ecs/systems/s_resource_regrow_system.gd` -> `scripts/demo/ecs/systems/s_resource_regrow_system.gd`
- Updated all scene/test/script preload paths for the moved ECS files and added explicit style prefix rules for `scripts/demo/ecs/components` + `scripts/demo/ecs/systems`.
- Verification: style guard (`87/87`), `test_c_ai_brain_component.gd` (`9/9`), `test_s_ai_detection_system.gd` (`8/8`), `test_s_move_target_follower_system.gd` (`5/5`), `test_s_needs_system.gd` (`3/3`), `test_s_resource_regrow_system.gd` (`1/1`), `test_s_ai_behavior_system_bt.gd` (`3/3`), `test_ai_demo_power_core.gd` (`10/10`), and `test_ai_interaction_triggers.gd` (`9/9`) pass.
- Third GREEN move chunk landed in `7a520d91` and moved demo AI action/world scripts:
  - `scripts/resources/ai/actions/rs_ai_action_build_stage.gd` -> `scripts/demo/resources/ai/actions/rs_ai_action_build_stage.gd`
  - `scripts/resources/ai/actions/rs_ai_action_drink.gd` -> `scripts/demo/resources/ai/actions/rs_ai_action_drink.gd`
  - `scripts/resources/ai/actions/rs_ai_action_feed.gd` -> `scripts/demo/resources/ai/actions/rs_ai_action_feed.gd`
  - `scripts/resources/ai/actions/rs_ai_action_harvest.gd` -> `scripts/demo/resources/ai/actions/rs_ai_action_harvest.gd`
  - `scripts/resources/ai/actions/rs_ai_action_haul_deposit.gd` -> `scripts/demo/resources/ai/actions/rs_ai_action_haul_deposit.gd`
  - `scripts/resources/ai/actions/rs_ai_action_reserve.gd` -> `scripts/demo/resources/ai/actions/rs_ai_action_reserve.gd`
  - `scripts/resources/ai/world/rs_build_site_settings.gd` -> `scripts/demo/resources/ai/world/rs_build_site_settings.gd`
  - `scripts/resources/ai/world/rs_build_stage.gd` -> `scripts/demo/resources/ai/world/rs_build_stage.gd`
  - `scripts/resources/ai/world/rs_inventory_settings.gd` -> `scripts/demo/resources/ai/world/rs_inventory_settings.gd`
  - `scripts/resources/ai/world/rs_resource_node_settings.gd` -> `scripts/demo/resources/ai/world/rs_resource_node_settings.gd`
- Updated all `.tres` ext_resource paths and script/test preloads that referenced those files; style guard now scans `scripts/demo/resources/ai/actions` for task-state literal usage and enforces prefix rules for `scripts/demo/resources/ai/{actions,world}`.
- Verification: style guard (`87/87`), `test_ai_actions_woods.gd` (`17/17`), `test_ai_action_feed.gd` (`6/6`), `test_builder_brain_bt.gd` (`11/11`), `test_c_build_site_component.gd` (`13/13`), `test_c_inventory_component.gd` (`13/13`), `test_c_resource_node_component.gd` (`10/10`), `test_s_resource_regrow_system.gd` (`1/1`), and `test_debug_woods_build_site_label.gd` (`2/2`) pass.
- Fourth GREEN move chunk landed in `f9cb6c3e` and moved demo lighting resource scripts:
  - `scripts/resources/lighting/rs_character_lighting_profile.gd` -> `scripts/demo/resources/lighting/rs_character_lighting_profile.gd`
  - `scripts/resources/lighting/rs_character_light_zone_config.gd` -> `scripts/demo/resources/lighting/rs_character_light_zone_config.gd`
- Updated lighting script preloads/ext_resources across gameplay/tests/resources/docs and added explicit style prefix rules for `scripts/demo/resources/lighting`.
- Verification: style guard (`87/87`), `test_character_lighting_manager.gd` (`11/11`), `test_inter_character_light_zone.gd` (`5/5`), and `test_character_zone_lighting_flow.gd` (`7/7`) pass.
- Fifth GREEN move chunk landed in `21470236` and moved demo AI utility scripts:
  - `scripts/utils/ai/u_ai_context_assembler.gd` -> `scripts/demo/utils/ai/u_ai_context_assembler.gd`
  - `scripts/utils/ai/u_ai_bt_task_label_resolver.gd` -> `scripts/demo/utils/ai/u_ai_bt_task_label_resolver.gd`
- Updated `S_AIBehaviorSystem` and builder-BT integration test preloads to the new demo util paths and extended style prefix enforcement/task-state key scanning for `scripts/demo/utils/ai`.
- Verification: style guard (`87/87`), `test_builder_brain_bt.gd` (`11/11`), and `test_s_ai_behavior_system_bt.gd` (`3/3`) pass.
- Sixth GREEN move chunk landed in `5b5c1e3e` and moved core root/events/scene_structure scripts into `scripts/core/**`.
- Seventh GREEN move chunk landed in `3d34de4f` and moved all interface/manager scripts into `scripts/core/interfaces/**` + `scripts/core/managers/**`, with reference/style-root updates.
- Eighth GREEN move chunk (working tree) moved all remaining `scripts/resources/**/*.gd` files into `scripts/core/resources/**`, updated script/resource/scene/test references from `res://scripts/resources/**` to `res://scripts/core/resources/**`, removed stale `scripts/resources/*.uid` leftovers, and normalized script-only `ext_resource` UID attributes in `.tres/.tscn` to avoid stale UID warnings after the path move.
- Verification (working tree): `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` passes (`87/87`), `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/resources/test_rs_ai_brain_settings_bt.gd` passes (`3/3`), and `tools/run_gut_suite.sh -gdir=res://tests/unit/resources -gdir=res://tests/unit/ai/resources -ginclude_subdirs=true` passes (`192/192`) after a headless import refresh.
- Final P4.3 chunks (2026-04-24, continued): P4.3 chunks 11–14 complete — move input/state/scene_management/ui → scripts/core/ (already committed in P4.3 chunks 9–10), then ecs/gameplay/utils/debug → scripts/core/ (chunks 11–14). Core→demo import violations fixed in s_movement_system, s_spawn_recovery_system, u_ai_world_state_builder, inter_character_light_zone. Stale path entries removed from style test; empty old dirs removed. Legacy fixture goals field restored. Full suite: 4587/4595 passing (8 headless/mobile pending, 0 failing).

## Milestone P4.4: Enforcement (Scripts)

- [x] **Commit 1** — Style enforcement: `scripts/core/**/*.gd` contains zero references to `scripts/demo/` paths. (Test `test_core_scripts_never_import_from_demo` was added in P4.3 Commit 1 and remains green throughout.)

**P4 Verification (Scripts)**:
- [x] Full test suite green after each move commit.
- [x] Deleting `scripts/demo/` and `resources/demo/` leaves a building (if non-functional-without-content) template. (Verified 2026-04-24: zero core script parse errors without demo; only demo scene resource-load failures, which are expected.)
- [x] Core import boundary enforcement green (87/87 style tests, `test_core_scripts_never_import_from_demo` passing).

## Milestone P4.5: Resources & Scenes Audit

**Goal**: Audit all `.tres` resource files and `.tscn` scene files against the classification in `template_vs_demo.md` and the target layout in `target_structure.md`. Produce a detailed migration checklist identifying: (a) files already correctly placed, (b) files needing move, (c) import/reference paths needing update. The scripts split is done; this audit covers the remaining resource and scene moves.

**Current state**: `resources/demo/` already contains 107 demo files (AI brains, demo audio, demo base_settings/gameplay, demo color gradings, demo interactions, demo lighting, demo scene_registry, demo spawn_metadata). `resources/core/` is empty — all ~170 core `.tres` files remain in flat `resources/` subdirs. `scenes/` is entirely unsplit. `assets/` is entirely unsplit.

- [x] **Commit 1** — `docs/history/cleanup_v8/resources_scenes_audit.md`: For each directory still requiring split work, enumerate:
  - **Resources core** (~170 files): Every file remaining in `resources/{audio,base_settings,display,input,interactions,localization,qb,scene_director,scene_registry,spawn_metadata,state,textures,triggers,ui,ui_screens,ui_themes,vfx}` and `resources/cfg_game_config.tres` that must move to `resources/core/`. Cross-reference with `target_structure.md` to confirm classification. Note: some `resources/audio/tracks/` files are mixed (main_menu/pause = core, alleyway/bar/etc. = demo already moved). Note: `resources/base_settings/gameplay/cfg_floating_patrol_drone_default.tres` is demo (already in `resources/demo/`).
  - **Scenes core** (~30 files): Every `.tscn` that is core per `template_vs_demo.md` (root.tscn, templates/*, gameplay_base.tscn, gameplay_interior_base.tscn, core prefabs, debug_color_grading_overlay.tscn, debug_state_overlay.tscn, all ui/*).
  - **Scenes demo** (~20 files): Every `.tscn` that is demo (gameplay_ai_showcase, ai_woods, alleyway, bar, comms_array, exterior, interior_a, interior_house, nav_nexus, power_core, demo prefabs, debug_ai_brain_panel, debug_woods_*).
  - **Assets demo** (~10 files): Demo models (mdl_new_exterior.glb, mdl_new_interior.glb), demo textures (tex_alleyway.png, tex_bar.png), demo music (mus_alleyway/bar/exterior/interior.mp3).
  - **Import/reference path impacts**: For each file move, list all `.gd`, `.tres`, `.tscn`, and `project.godot` references that must update.
  - **Commit sequence proposal**: Ordered move commits to minimize mid-migration breakage, following the pattern established in P4.3.

## Milestone P4.6: Resources Core Move

**Goal**: Move all core `.tres` resources from their flat `resources/` locations into `resources/core/`, matching the target layout from `target_structure.md`. This is the resources counterpart of P4.3 (which moved scripts). The demo resources are already in `resources/demo/`.

- [x] **Commit 1** (RED) — Grep test: `resources/core/**/*.tres` paths are referenced correctly. Add style enforcement that `resources/core/**/*.tres` files reference only `resources/core/` or `scripts/core/` paths (no `resources/demo/` or `scripts/demo/` references in core resource files).
- [x] **Commit 2+** (GREEN) — Move files per audit, one commit per logical chunk. Proposed chunks:
  - `resources/cfg_game_config.tres` → `resources/core/cfg_game_config.tres`
  - `resources/base_settings/` (audio, display, gameplay, state defaults) → `resources/core/base_settings/`
  - `resources/audio/ui/` → `resources/core/audio/ui/`; `resources/audio/tracks/` (main_menu, pause) → `resources/core/audio/tracks/`
  - `resources/display/` (presets, vcam, color_gradings/gameplay_base) → `resources/core/display/`
  - `resources/input/` → `resources/core/input/`
  - `resources/interactions/` (defaults only) → `resources/core/interactions/`
  - `resources/localization/` → `resources/core/localization/`
  - `resources/qb/` → `resources/core/qb/`
  - `resources/scene_director/` → `resources/core/scene_director/`
  - `resources/scene_registry/` (gameplay_base + 12 UI entries) → `resources/core/scene_registry/`
  - `resources/spawn_metadata/cfg_sp_base.tres` → `resources/core/spawn_metadata/`
  - `resources/state/` → `resources/core/state/`
  - `resources/textures/` → `resources/core/textures/`
  - `resources/triggers/` → `resources/core/triggers/`
  - `resources/ui/` → `resources/core/ui/`
  - `resources/ui_screens/` → `resources/core/ui_screens/`
  - `resources/ui_themes/` → `resources/core/ui_themes/`
  - `resources/vfx/` → `resources/core/vfx/`
- [x] **Commit N** — Update all `preload()`/`load()` paths in `.gd` files, all resource references in `.tres` files, all script/ext_resource references in `.tscn` files, and `project.godot` autoload paths that reference moved resources. Remove stale empty directories.

**P4.6 Completion Notes (2026-04-25)**:
- All 8 resource move chunks landed: `base_settings/` (C1), `audio/` (C2), `display/` (C3), `input/` (C4), `interactions/` (C5), `localization/`/`qb/`/`scene_director/` (C6), `scene_registry/`/`spawn_metadata/`/`state/` (C7), `textures/`/`triggers/`/`ui/`/`ui_screens/`/`ui_themes/`/`vfx/`/`cfg_game_config` (C8).
- Final cleanup commit (`7c33705b`) removed all stale empty resource subdirs; `resources/` now contains only `core/` and `demo/`.

## Milestone P4.7: Scenes Split

**Goal**: Split `scenes/` into `scenes/core/` and `scenes/demo/`, matching the target layout from `target_structure.md`.

- [x] **Commit 1** (RED) — Grep test: `scenes/core/**/*.tscn` references only `scenes/core/` and `resources/core/` paths (no `scenes/demo/` or `resources/demo/` references in core scenes).
- [x] **Commit 2+** (GREEN) — Move files per audit, one commit per logical chunk:
  - Core scenes: `root.tscn`, `templates/*`, `gameplay/gameplay_base.tscn`, `gameplay/gameplay_interior_base.tscn`, core prefabs (`prefab_character`, `prefab_player`, `prefab_player_body`, `prefab_player_ragdoll`, `prefab_checkpoint_safe_zone`, `prefab_death_zone`, `prefab_door_trigger`, `prefab_goal_zone`, `prefab_spike_trap`), `debug/debug_color_grading_overlay.tscn`, `debug/debug_state_overlay.tscn`, all `ui/*`
  - Demo scenes: `gameplay/gameplay_ai_showcase.tscn`, `gameplay_ai_woods.tscn`, `gameplay_alleyway.tscn`, `gameplay_bar.tscn`, `gameplay_comms_array.tscn`, `gameplay_exterior.tscn`, `gameplay_interior_a.tscn`, `gameplay_interior_house.tscn`, `gameplay_nav_nexus.tscn`, `gameplay_power_core.tscn`, demo prefabs (`prefab_alleyway`, `prefab_bar`, `prefab_demo_npc`, `prefab_demo_npc_body`, `prefab_woods_*`), `debug/debug_ai_brain_panel.tscn`, `debug/debug_woods_agent_label.tscn`, `debug/debug_woods_build_site_label.tscn`
- [x] **Commit N** — Update all scene references, preload paths, `project.godot` main scene entry, and remove stale empty directories.

**P4.7 Completion Notes (2026-04-25)**:
- C1 (`f66a7ce7`): moved 49 core scenes to `scenes/core/`.
- C2 (`ef5d8e07`): moved 25 demo scenes to `scenes/demo/`; `scenes/` now contains only `core/` and `demo/`.

## Milestone P4.8: Assets Demo Move

**Goal**: Move demo-only assets into `assets/demo/`. Core assets remain in their current locations (fonts, shaders, materials, button_prompts, editor_icons, video, core textures/models).

- [x] **Commit 1+** (GREEN) — Move per `template_vs_demo.md` classification:
  - `assets/models/mdl_new_exterior.glb` → `assets/demo/models/`
  - `assets/models/mdl_new_interior.glb` → `assets/demo/models/`
  - `assets/textures/tex_alleyway.png` → `assets/demo/textures/`
  - `assets/textures/tex_bar.png` → `assets/demo/textures/`
  - `assets/audio/music/mus_alleyway.mp3` → `assets/demo/audio/music/` (and bar, exterior, interior)
  - Update all `.tscn` and `.tres` references to moved assets.
  - Core assets (`assets/audio/music/mus_main_menu.mp3`, `mus_pause.mp3`, `mus_credits.mp3`, character models, core textures) stay in place.

**P4.8 Completion Notes (2026-04-25)**:
- Completed in `fece8d8c`: moved demo audio/models/textures to `assets/demo/`.

## Milestone P4.9: Resources & Scenes Enforcement

**Goal**: Enforce the core/demo boundary for resources, scenes, and assets, mirroring the P4.4 scripts enforcement.

- [x] **Commit 1** — Style enforcement: `resources/core/**/*.tres` contains zero references to `resources/demo/` or `scripts/demo/` paths. `scenes/core/**/*.tscn` contains zero references to `scenes/demo/`, `resources/demo/`, or `scripts/demo/` paths.
- [x] **Commit 2** — Add `test_core_resources_never_reference_demo` to style suite: grep all `.tres` files under `resources/core/` for `resources/demo/` and `scripts/demo/` path references. Grep all `.tscn` files under `scenes/core/` for `scenes/demo/`, `resources/demo/`, `scripts/demo/` path references.

**P4.9 Completion Notes (2026-04-25)**:
- Completed in `a85d963b`: added `test_core_resources_never_reference_demo` and `test_core_scenes_never_reference_demo` to style suite; fixed 6 core→demo import violations.

## Milestone P4.10: Assets Core Move + Final Asset Reorganization

**Goal**: Move remaining core assets into `assets/core/` and finish the assets split. After P4.8 moved demo assets to `assets/demo/`, several core asset directories (fonts, shaders, materials, button_prompts, video, editor_icons, core models/textures) still lived in the flat `assets/` root. This milestone relocates them under `assets/core/` to complete the directory split.

- [x] **Commit 1** (GREEN) — `assets/textures/prototype_grids_png/` → `assets/demo/textures/` (demo texture grid).
  - Completed in `bfc64316`.
- [x] **Commit 2** (GREEN) — `assets/editor_icons/` → `assets/core/editor_icons/`; update 276 `@icon` annotations across all `.gd` files.
  - Completed in `b8c9dd95`.
- [x] **Commit 3** (GREEN) — Remaining core dirs (`audio/`, `button_prompts/`, `fonts/`, `materials/`, `models/`, `shaders/`, `textures/`, `video/`) → `assets/core/`; update all `.tres`/`.tscn`/`.gd` references.
  - Completed in `58e4263e`.

**P4.10 Completion Notes (2026-04-25)**:
- `assets/` now contains only `core/` and `demo/`, matching the pattern established for `scripts/`, `resources/`, and `scenes/`.
- 276 `@icon` annotations in `.gd` files were updated from `res://assets/editor_icons/` to `res://assets/core/editor_icons/`.
- Style suite 89/89 after all P4.10 moves.

**P4 Full Verification**:
- [x] Full test suite green after each move commit.
- [x] Deleting `scripts/demo/`, `resources/demo/`, `scenes/demo/`, and `assets/demo/` leaves a building (if non-functional-without-content) template. Verified 2026-04-24 for scripts; resources/scenes/assets split complete 2026-04-25.
- [x] Core boundary enforcement green: `scripts/core/**/*.gd` never imports from `scripts/demo/`, `resources/core/**/*.tres` never references `resources/demo/` or `scripts/demo/`, `scenes/core/**/*.tscn` never references `scenes/demo/`, `resources/demo/`, or `scripts/demo/`. Style suite 89/89.

---

# Phase 5 — Base Scene + Temp Scene Cleanup

**Goal**: One canonical base scene; delete the rest.

**Starting state**: `scenes/templates/tmpl_base_scene.tscn` already exists with full managers + ECS systems wiring + camera template + scene-structure markers. P5 extends/refactors this file rather than creating a new `base_scene.tscn`. The `tmpl_` prefix is preserved per the template scene naming convention (see `tmpl_camera.tscn`, `tmpl_character.tscn`, `tmpl_character_ragdoll.tscn`).

## Milestone P5.1: Inventory

- [ ] **Commit 1** — `docs/guides/cleanup_v8/scene_inventory.md`: list every `.tscn` with one-line purpose, classify as **keep (base)**, **keep (demo)**, **delete (temp/fake)**. Note that `tmpl_base_scene.tscn` is the base; no new base is needed.

## Milestone P5.2: Canonical Base Scene

- [ ] **Commit 1** (RED) — Integration test: `scenes/templates/tmpl_base_scene.tscn` loads without errors, instances `scenes/root.tscn` dependencies correctly, boots through service-locator registrations, exits cleanly without leaks.
- [ ] **Commit 2** (GREEN) — Extend/refactor existing `scenes/templates/tmpl_base_scene.tscn` to match the base-scene contract: managers node tree, empty world node, camera rig, UI root layer. No demo-specific content. Any demo content that has crept into `tmpl_base_scene.tscn` migrates to demo scenes in P5.3. No new file is created.

## Milestone P5.3: Demo Scene Migration

- [ ] **Commit 1+** — Move/rebuild real demo scenes (forest, etc.) on top of `tmpl_base_scene.tscn` via `PackedScene` instancing or inheritance.

## Milestone P5.4: Deletion

- [ ] **Commit 1** — Delete every scene classified "delete (temp/fake)". One commit so the removal is atomic and revertable.

**P5 Verification**:
- [ ] Base scene test green (against `tmpl_base_scene.tscn`).
- [ ] All real demo scenes boot from `tmpl_base_scene.tscn`.
- [ ] No orphaned `.tscn` files. `scenes/` tree matches the inventory's "keep" set exactly.

---

# Phase 6 — LLM-First Fluent Builders

**Reference plan**: `~/.claude/plans/stateless-tickling-meerkat.md` (approved).

**Goal**: Replace `.tres` resource authoring with GDScript builder APIs across four systems: BT trees, scene registry, input profiles, and QB rules. An LLM can read and write a 20-line builder script in a single turn; `.tres` files require multiple turns, massive context windows, and are prone to hallucinated ExtResource IDs and syntax failures. Builder scripts produce readable git diffs, eliminate resource ID hallucination, and maintain full backward compatibility during migration.

**LOC target**: ~800 added (builders + factory methods + migration scripts), ~400 removed (deleted .tres files). Net ~400 LOC addition for significantly improved LLM turn efficiency.

**Design Decisions**:
- **RS_BTScoredNode**: New node type wrapping a child + scorer pair. Cleaner than parallel `child_scorers` arrays. `RS_BTUtilitySelector` updated to detect scored children; falls back to `child_scorers` for backward compat.
- **API style**: `U_BTBuilder` uses static factory methods (each call creates and returns a node). `U_SceneRegistryBuilder`, `U_InputProfileBuilder`, `U_QBRuleBuilder` use instance-based fluent builders (state accumulation + `build()`).
- **Typed + convenience factories**: All builder methods accept typed resources. Convenience factory methods create and configure common resource types — no string lookup registries.
- **Core/demo boundary**: BT structural builder (`U_BTBuilder`) lives in `scripts/core/utils/bt/` (no AI imports). AI-specific convenience factories (`U_AIBTFactory`) live in `scripts/core/utils/ai/`.

---

## Milestone P6.1: RS_BTScoredNode + Utility Selector Update

**Goal**: Introduce `RS_BTScoredNode` as an explicit child+scorer wrapper, update `RS_BTUtilitySelector` to use it, maintain backward compatibility with `child_scorers` array.

- [x] **Commit 1** (RED) — `tests/unit/ai/bt/test_rs_bt_scored_node.gd` (`10310f00`): 7 tests — script loads, extends RS_BTDecorator, scorer defaults null, null child → FAILURE, delegates tick to child (SUCCESS/RUNNING), scorer NOT called during tick.
- [x] **Commit 2** (GREEN) — `scripts/core/resources/bt/rs_bt_scored_node.gd` (`c2fbd06e`): 10 lines. Extends RS_BTDecorator, `@export var scorer: Resource = null`, tick() delegates to _child or returns FAILURE.
- [x] **Commit 3** (RED) — Add to `test_rs_bt_utility_selector.gd` (`0f35fe3a`): 4 new tests — uses scored node scorer, falls back to child_scorers for plain nodes, scored node overrides child_scorers at same index, pins running scored-node child.
- [x] **Commit 4** (GREEN) — Update `scripts/core/resources/bt/rs_bt_utility_selector.gd` (`dc2951ee`): `_score_child()` now checks `"scorer" in child` (duck-typing; avoids class-name parse error in headless mode for un-indexed new files). New `_score_child_via_node_scorer()` helper mirrors the resource path. Backward compat unchanged.
- [x] **Commit 5** (GREEN) — Style enforcement (`ec14181a`): `RS_BT_SCORED_NODE_MAX_LINES := 50` constant + `test_rs_bt_scored_node_stays_under_fifty_lines()` added. Style suite 90/90. Full suite 4601/4601 passing, 8 pending.

**P6.1 Verification**:
- [x] All existing BT tests green (backward compat) — full suite 4601/4601
- [x] New scored-node tests green — 7/7
- [x] Style enforcement green — 90/90

**P6.1 Completion Notes (2026-04-26)**:
- Duck-typing (`"scorer" in child`) used instead of `child is RS_BTScoredNode` in the utility selector because new .gd files created outside the editor lack UID registration in headless test mode, causing a parse-time "Could not find type" error. Duck-typing is more idiomatic GDScript and equally correct.

---

## Milestone P6.2: BT Structural Builder (U_BTBuilder)

**Goal**: Static factory class that creates every BT node type. No AI-specific imports.

- [x] **Commit 1** (RED) — `tests/unit/ai/bt/test_u_bt_builder.gd` (`a4c41434`)
- [x] **Commit 2** (GREEN) — `scripts/core/utils/bt/u_bt_builder.gd` (`9139e459`)
- [x] **Commit 3** (GREEN) — Style enforcement: LOC cap 100 lines added (`a23270b1`)

**Notes**:
- `planner()` omitted from `U_BTBuilder` — `RS_BTPlanner*` is a forbidden token in `BT_UTILS_DIR`; planner factory belongs in `U_AIBTFactory` (P6.3)
- `scored()` return type is `RS_BTDecorator` (not `RS_BTScoredNode`) — `rs_bt_scored_node.gd` lacks a UID file so the class name can't be resolved as a type annotation in headless mode
- Composite children use `_sanitize_children` + `_children` bypass — direct typed-Array property assignment silently coerces to empty in headless runs

**P6.2 Verification**:
- [x] All 16 builder tests green
- [x] Built trees produce correct behavior via `U_BTRunner`
- [x] No AI-specific imports in BT builder (style enforcement: 91/91)
- [x] Full suite green (4617/4617)

---

## Milestone P6.3: AI BT Factory (U_AIBTFactory)

**Goal**: Convenience factory methods that create `RS_BTAction` nodes wrapping specific `I_AIAction` implementations. Lives in AI utils (can import AI types).

- [x] **Commit 1** (RED) — `tests/unit/ai/bt/test_u_ai_bt_factory.gd` (`d0c1224a`)
- [x] **Commit 2** (GREEN) — `scripts/core/utils/ai/u_ai_bt_factory.gd` (`bdd135b4`)
- [x] **Commit 3** (GREEN) — Style enforcement LOC cap 200 lines (`0cd59475`)

**P6.3 Verification**:
- [x] All 21 factory tests green
- [x] wait(0.0) integration test ticks SUCCESS with U_BTRunner
- [x] Full suite 4640/4648 (8 pre-existing pending); style 92/92

---

## Milestone P6.4: Script-Backed Brain Settings (RS_AIBrainScriptSettings)

**Goal**: Allow brain settings to generate their BT root from a builder script instead of a static `.tres` resource.

- [x] **Commit 1** (RED) — `tests/unit/ai/bt/test_rs_ai_brain_script_settings.gd` (`4a1218f1`)
- [x] **Commit 2** (GREEN) — Add `get_root()` virtual to `rs_ai_brain_settings.gd` (`f0652db7`)
- [x] **Commit 3** (GREEN) — `scripts/core/resources/ai/brain/rs_ai_brain_script_settings.gd` (`25da8c65`)
- [x] **Commit 4** (GREEN) — Update callers: `s_ai_behavior_system.gd` + `u_ai_bt_task_label_resolver.gd` (`c6608c79`)

**P6.4 Verification**:
- [x] Existing `.tres`-backed brains still work (backward compat)
- [x] Script-backed brains generate and cache BT roots correctly
- [x] Full AI behavior system test green
- [x] Full suite green (4651/4659, 8 pre-existing pending)

**P6.4 Completion Notes (2026-04-26)**:
- `u_ai_bt_task_label_resolver.gd` also accessed `brain_settings.root` directly; updated alongside `s_ai_behavior_system.gd` in commit 4.
- Dynamic GDScript creation in tests (GDScript.new() + reload()) used for mock builder scripts — avoids fixture files, works in headless mode.
- `root` property serves as the cache: first call builds and stores in `root`, subsequent calls return the cached value.

---

## Milestone P6.5: BT Migration — .tres → Builder Scripts

**Goal**: Convert existing AI brain `.tres` resources to builder scripts as proof-of-concept and to validate the full builder pipeline end-to-end.

- [x] **Commit 1** (RED) — Integration test: for each creature brain (patrol_drone, guide_prism, sentry, wolf, rabbit, builder), a builder script produces a BT root that is structurally equivalent to the existing `.tres`-authored root. (`6e9e7b6a`)
- [x] **Commit 2** (GREEN) — Create builder scripts for each creature brain under `scripts/demo/ai/trees/`: (`0c0bdd55`)
  - `patrol_drone_behavior.gd`, `guide_prism_behavior.gd`, `sentry_behavior.gd`, `wolf_behavior.gd`, `rabbit_behavior.gd`, `builder_behavior.gd`
  - Each extends `RefCounted`, has `build() -> RS_BTNode` using `U_BTBuilder` + `U_AIBTFactory`
- [x] **Commit 3** (GREEN) — Create `RS_AIBrainScriptSettings` `.tres` resources for all 6 creatures. (`8ea13211`)
- [x] **Commit 4** (GREEN) — Rewire demo scenes and tests to script-backed brain `.tres` files. (`d1d2ab4b`)
- [x] **Commit 5** (GREEN) — Delete 6 original creature BT `.tres` files; redirect all remaining test references to `_script.tres`. (`e28d0c30`)
  - wolf + rabbit `brain_bt` tests deleted (duplicated by behavior tests); patrol/sentry/guide/builder `brain_bt` tests updated to use `get_root()`.
  - `patrol_drone_behavior.gd` sets `root.resource_name = "patrol_drone_bt_root"` for `active_goal_id` parity in `test_ai_demo_power_core.gd`.
- [x] **Gap-patch** (`5a176f9a`..`b29e3618`) — `guide_showcase_behavior.gd` builder + `cfg_guide_showcase_brain_script.tres` migration; rewires `gameplay_ai_showcase` scene + integration test. Brings creature builder count to 7.

**P6.5 Verification**:
- [x] Builder script tests green
- [x] Full suite green (4679/4687, 8 pre-existing pending). Style: 92/92.
- [x] No orphaned `.tres` references

---

## Milestone P6.6: Scene Registry Builder (U_SceneRegistryBuilder) — COMPLETE

**Commits**: `f3806172` (RED), `fb576449` (GREEN).

**Goal**: Fluent builder for programmatic scene registration as an alternative to `.tres` entry files. Allows LLMs to add a scene registration in one line of code rather than generating a whole `.tres` file.

- [x] **Commit 1** (RED) — `tests/unit/scene_management/test_u_scene_registry_builder.gd`:
  - `register(scene_id, path)` adds entry with defaults (GAMEPLAY type, "fade" transition, priority 0)
  - `.with_type(scene_type)` sets scene type on last entry
  - `.with_transition(transition)` sets transition on last entry
  - `.with_preload(priority)` sets preload priority on last entry
  - Fluent chaining works: all methods return `self`
  - `.build()` returns `Dictionary` mapping `StringName → Dictionary` (same shape as `U_SceneRegistry` entries)
- [x] **Commit 2** (GREEN) — `scripts/core/utils/scene/u_scene_registry_builder.gd`:
  - `class_name U_SceneRegistryBuilder`, extends `RefCounted`
  - Instance-based fluent API (methods return `self`)
  - `register()`, `with_type()`, `with_transition()`, `with_preload()`, `build()`
  - 34 lines total

**P6.6 Verification**:
- [x] 10/10 builder tests green
- [x] Style suite 92/92
- [x] `build()` returns same-shape entries as `U_SceneRegistry._scenes`

---

## Milestone P6.7: Scene Registry Migration — .tres → Builder Script

**Goal**: Convert existing scene registry `.tres` entry files to a builder script manifest, validating the scene registry builder pipeline end-to-end.

- [x] **Commit 1** (RED) — Integration test: builder script produces registry entries equivalent to existing `.tres` entries.
  - Test loads the builder manifest script and compares produced entries against the current `U_SceneRegistry` state
  - Each entry matches: scene_id, path, scene_type, default_transition, preload_priority
- [x] **Commit 2** (GREEN) — Create `scripts/core/scene_management/u_scene_manifest.gd`:
  - Uses `U_SceneRegistryBuilder` to register all demo scenes
  - Replaces the 21 `PRELOADED_SCENE_REGISTRY_ENTRIES` const preloads in `U_SceneRegistryLoader`
  - Each `register()` call matches an existing `.tres` entry
  - Path note: lives in `scripts/core/scene_management/` (the loader's home), not `scripts/demo/` — intentional, since the manifest is loaded by the core scene-registry loader and includes core scenes (`gameplay_base`) alongside demo scenes
  - Uses `U_SceneRegistry.SceneType.{GAMEPLAY,UI,END_GAME}` constants (not magic numbers) for readable LLM diffs
- [x] **Commit 3** (GREEN) — Wire `u_scene_manifest.gd` into `U_SceneRegistryLoader.load_resource_entries()`:
  - Loader calls the manifest script's build/apply during initialization
  - Mobile-compatible: manifest script replaces DirAccess scanning, not const preloads
- [x] **Commit 4** (GREEN) — Delete original `.tres` scene registry entries once manifest is verified
  - One commit so the removal is atomic and revertable
  - Update `PRELOADED_SCENE_REGISTRY_ENTRIES` in loader

**P6.7 Verification**:
- [x] All scenes load identically to pre-migration
- [x] Builder manifest test green
- [x] Full suite green
- [x] No orphaned `.tres` references

---

## Milestone P6.8: Input Profile Builder (U_InputProfileBuilder)

**Goal**: Fluent builder for programmatic input profile construction.

- [x] **Commit 1** (RED) — `tests/unit/input/test_u_input_profile_builder.gd`:
  - `create(name, device_type)` initializes builder with profile name and device type
  - `.bind_key(action, keycode)` adds `InputEventKey` to action
  - `.bind_mouse_button(action, button_index)` adds `InputEventMouseButton` to action
  - `.bind_gamepad_button(action, button_index)` adds `InputEventJoypadButton` to action
  - `.bind_gamepad_axis(action, axis, axis_value)` adds `InputEventJoypadMotion` to action
  - `.with_accessibility(jump_buffer, sprint_toggle, interact_hold)` sets accessibility fields
  - `.with_touchscreen(virtual_buttons, joystick_pos)` sets touchscreen fields
  - `.build()` returns configured `RS_InputProfile`
  - Built profile passes `RS_InputProfile` validation (non-empty name, non-empty action_mappings)
- [x] **Commit 2** (GREEN) — `scripts/core/utils/input/u_input_profile_builder.gd`:
  - `class_name U_InputProfileBuilder`, extends `RefCounted`
  - Instance-based fluent API
  - Creates `InputEvent` objects and configures `RS_InputProfile.action_mappings`
  - Path note: shipped under `core/utils/input/` (not `core/managers/helpers/` as originally drafted) to align with sibling builders (`U_BTBuilder`, `U_QBRuleBuilder`, `U_SceneRegistryBuilder`) that all live under `scripts/core/utils/<domain>/`.
- [x] **Commit 3** (GREEN) — Style enforcement: add line-count guard (max 150 lines).

**P6.8 Verification**:
- [x] Builder tests green
- [x] Built profiles accepted by `M_InputProfileManager`
- [x] Existing `.tres` profiles unaffected
- [x] Full suite green

---

## Milestone P6.9: Input Profile Migration — .tres → Builder Scripts

**Goal**: Convert existing input profile `.tres` files to builder scripts, validating the input profile builder pipeline end-to-end.

- [x] **Commit 1** (RED) — Integration test: builder scripts produce profiles equivalent to existing `.tres` profiles.
  - Test loads each builder script and compares produced profile against the corresponding `.tres` resource
  - Action mappings match: same actions, same key bindings, same device types
- [x] **Commit 2** (GREEN) — Create builder scripts under `scripts/core/resources/input/profiles/`:
  - `rs_default_keyboard_profile.gd` — replaces `cfg_default_keyboard.tres`
  - `rs_alternate_keyboard_profile.gd` — replaces `cfg_alternate_keyboard.tres`
  - `rs_accessibility_keyboard_profile.gd` — replaces `cfg_accessibility_keyboard.tres`
  - `rs_default_gamepad_profile.gd` — replaces `cfg_default_gamepad.tres`
  - `rs_accessibility_gamepad_profile.gd` — replaces `cfg_accessibility_gamepad.tres`
  - `rs_default_touchscreen_profile.gd` — replaces `cfg_default_touchscreen.tres`
  - Each script extends `RefCounted`, has `build() -> RS_InputProfile` using `U_InputProfileBuilder`.
  - Path/prefix note: profiles live in `core/resources/input/profiles/` with `rs_` prefix (the directory's existing prefix rule from `SCRIPT_PREFIX_RULES`). They are builder scripts, not `Resource` subclasses — the `rs_` prefix is locally consistent with directory convention but diverges from sibling builder conventions (BT brains use no prefix, QB rules use `br_`). Decision deferred to follow-up.
- [x] **Commit 3** — `U_InputProfileLoader.load_available_profiles()` loads via `rs_manifest.gd` aggregator (one extra layer of indirection compared to BT/scene-registry/QB chains):
  - Manifest preloads each profile builder and calls `build()` to assemble the profile dictionary.
  - Loader instantiates the manifest and copies its result into the available-profile map.
- [x] **Commit 4** — Delete original `.tres` input profile files once builder scripts are verified
  - One commit so the removal is atomic and revertable

**P6.9 Verification**:
- [x] All input profiles load and function identically to pre-migration
- [x] Builder script tests green
- [x] Full suite green
- [x] No orphaned `.tres` references

---

## Milestone P6.10: QB Rule Builder (U_QBRuleBuilder)

**Goal**: Fluent builder for programmatic QB rule construction.

- [x] **Commit 1** (RED) — `tests/unit/qb/test_u_qb_rule_builder.gd` (~500 lines, 30 tests):
  - `rule(rule_id, conditions, effects, config)` returns `RS_Rule` directly
  - Condition factories: `event_name`, `event_payload`, `component_field`, `redux_field`, `entity_tag`, `context_field`, `constant`, `composite_all`, `composite_any`
  - Effect factories: `publish_event`, `set_field`, `set_context`, `dispatch_action`
  - `set_field` and `set_context` detect value type at runtime (`float`, `int`, `bool`, `String`, `StringName`, `Vector2`, `Vector3`)
  - Built rules pass `U_RuleValidator` validation
  - Parity tests for `camera_shake`, `victory_forward`, `pause_gate_paused`, `landing_impact`
- [x] **Commit 2** (GREEN) — `scripts/core/utils/qb/u_qb_rule_builder.gd` (199 lines as shipped; original draft estimated ~141 lines, grew with `_sanitize_*` helpers + private effect-value setters):
  - `class_name U_QBRuleBuilder`, extends `RefCounted`, all static methods
  - Static factory API matching `U_BTBuilder` / `U_AIBTFactory` conventions
  - Preload consts for all condition/effect/resource scripts (headless-safe)
  - `_sanitize_conditions` / `_sanitize_effects` bypass for typed `Array[I_Condition]` / `Array[I_Effect]` headless pitfall (same pattern as `U_BTBuilder`)
  - `_sanitize_children` bypass for `RS_ConditionComposite` (same pattern as `composite_all`/`composite_any` in `U_AIBTFactory`)
  - `_set_effect_value` and `_set_context_effect_value` private helpers mirror `U_AIBTFactory.set_field()` type detection
  - Effect config keys: `operation`, `use_context_value`, `context_value_path`, `scale_by_rule_score`, `rule_score_context_path`, `use_clamp`, `clamp_min`, `clamp_max`
  - Rule config keys: `trigger_mode`, `score_threshold`, `decision_group`, `priority`, `cooldown`, `one_shot`, `requires_rising_edge`, `description`

**P6.10 Verification**:
- [x] Builder tests green (30/30 passing, 218 asserts)
- [x] Built rules pass `U_RuleValidator` validation
- [x] Built rules work with `U_RuleEvaluator` pipeline
- [x] Full suite green (4755/4763, 8 pre-existing pending, 0 failures)

---

## Milestone P6.11: QB Rule Migration — .tres → Builder Scripts

**Goal**: Convert existing QB rule `.tres` files to builder scripts, validating the QB rule builder pipeline end-to-end.

- [x] **Commit 1** (RED) — Integration test: builder scripts produce rules equivalent to existing `.tres` rules.
  - Test loads each builder script and compares produced rule against the corresponding `.tres` resource
  - Conditions, effects, trigger mode, cooldown, one-shot, decision group all match
- [x] **Commit 2** (GREEN) — Create builder scripts under `scripts/core/qb/rules/` (note: `br_` prefix — builder rule category):
  - `br_death_sync_rule.gd` — replaces `cfg_death_sync_rule.tres`
  - `br_spawn_freeze_rule.gd` — replaces `cfg_spawn_freeze_rule.tres`
  - `br_pause_gate_shell_rule.gd` — replaces `cfg_pause_gate_shell.tres`
  - `br_pause_gate_paused_rule.gd` — replaces `cfg_pause_gate_paused.tres`
  - `br_pause_gate_transitioning_rule.gd` — replaces `cfg_pause_gate_transitioning.tres`
  - `br_camera_zone_fov_rule.gd` — replaces `cfg_camera_zone_fov_rule.tres`
  - `br_camera_speed_fov_rule.gd` — replaces `cfg_camera_speed_fov_rule.tres`
  - `br_camera_landing_impact_rule.gd` — replaces `cfg_camera_landing_impact_rule.tres`
  - `br_camera_shake_rule.gd` — replaces `cfg_camera_shake_rule.tres`
  - `br_checkpoint_forward_rule.gd` — replaces `cfg_checkpoint_rule.tres`
  - `br_victory_forward_rule.gd` — replaces `cfg_victory_rule.tres`
  - Each script extends `RefCounted`, has `build() -> RS_Rule` using `U_QBRuleBuilder`
- [x] **Commit 3** — Update ECS systems that preload rule `.tres` files to load from builder scripts instead:
  - `S_CharacterStateSystem`, `S_CameraStateSystem`, `S_GameEventSystem`
  - Replace `preload("res://resources/qb/.../cfg_*.tres")` with builder script instantiation + `_build_rules_from_scripts()` pattern
- [x] **Commit 4** — Delete original `.tres` rule files once builder scripts are verified
  - One commit so the removal is atomic and revertable

**P6.11 Verification**:
- [x] All QB rules function identically to pre-migration
- [x] Builder script tests green (14/14)
- [x] Full suite green (4769/4777, 8 pre-existing pending, 0 failures)
- [x] No orphaned `.tres` references
- [x] Style suite passes (92/92, `br_` prefix added to SCRIPT_PREFIX_RULES)

---

## Milestone P6.12: ADR + Extension Recipes — COMPLETE

**Goal**: Document the fluent builder pattern decision and provide extension recipes.

- [x] **Commit 1** (`1148e2f5`) — ADR: `docs/architecture/adr/0011-builder-pattern-taxonomy.md`:
  - Accepted. Documents three recognized patterns (static builder, declarative/fluent builder, helper).
  - Consequences: naming split (`Builder` vs `Helper`), Phase 7/8 room to land without collision.
- [x] **Commit 1** (`1148e2f5`) — Extension recipe: `docs/architecture/extensions/builders.md`:
  - Covers all builder categories: BT structural, AI factory, scene registry, input profile, QB rules, editor prefab/blockout.
  - Sections: When to use, Governing ADR, Canonical examples, Vocabulary, Recipe, Anti-patterns, Out of scope.
  - Updated `README.md` routing table to include `builders.md`.
  - Updated `ai.md` to reference `builders.md` for builder-specific authoring.
  - Added `builders.md` to `test_extension_recipe_structure` expected list.

**P6.12 Completion Notes (2026-04-27)**:
- Commit `1148e2f5` landed: ADR 0011 (52 lines), extension recipe `builders.md` (190 lines), `ai.md` canonical-example update, `extensions/README.md` routing-table addition, style enforcement update adding `builders.md` to expected recipe list.
- Style suite passes (92/92, pre-existing).
- Full suite pre-existing pass (4769/4777, 8 pending, 0 failures).

**P6.12 Verification**:
- [x] ADR passes `test_adr_structure` style test
- [x] Extension recipe passes `test_extension_recipe_structure` style test
- [x] Full suite green

---

## Milestone P6.13: Gap Patches & Constant Migrations — COMPLETE

**Goal**: Clean up remaining gaps from P6 migrations and replace magic numbers with named constants.

- [x] **Commit P6.13a** (`64210f85`) — Rewrite backfill tests: assert manifest is source of truth for non-critical scenes.
- [x] **Commit P6.13b** (`085dedd0`) — Gap patch: input profile manifest parity.
- [x] **Commit P6.13c** (`64a4ef68`) — Replace composite magic numbers with `RS_ConditionComposite.CompositeMode` constants.
- [x] **Commit P6.13d** — Remove backfill call; add `TRIGGER`/`OP`/`MATCH` constants; swap call sites (absorbed into P6.13b-e).
- [x] **Commit P6.13e** (`6430709b`, `279fcc33`) — Add `RS_EffectSetField.OP_SET/OP_ADD` constants; swap call sites; add `TRIGGER`/`OP`/`MATCH` constants to rules + AI behaviors.

**P6.13 Verification**:
- [x] Backfill tests assert manifest is source of truth
- [x] All magic number call sites replaced with named constants
- [x] Full suite green

---

## Dependency Graph

```
Phase 1 (AI BT rewrite) — COMPLETE
   ├── Phase 2 (debug/perf) — COMPLETE
   ├── Phase 3 (docs split) — COMPLETE
   ├── Phase 4 (template/demo split) — COMPLETE
      └── Phase 5 (scenes) — NOT STARTED (deferred to last)
   └── Phase 6 (fluent builders) — COMPLETE (P6.1–P6.13)
      ├── P6.1 → P6.2 → P6.3 → P6.4 → P6.5 (BT chain) — COMPLETE
      ├── P6.6 → P6.7 (scene registry chain) — COMPLETE
      ├── P6.8 → P6.9 (input profile chain) — COMPLETE
      ├── P6.10 → P6.11 (QB rule chain) — COMPLETE
      └── P6.12 → P6.13 (ADR + gap patches) — COMPLETE
   └── Phase 7 (editor/prefab builders) — COMPLETE (P7.1–P7.8)
   └── Phase 8 (UI menu builders) — IN PROGRESS (through P8.4)
      ├── P8.1 → P8.2 → P8.3 (catalog → tab builder → display migration)
      ├── P8.4 (audio migration, independent after P8.2)
      ├── P8.5 (VFX migration, independent after P8.2)
      ├── P8.6 → P8.7 (menu builder → main/pause migration)
      ├── P8.8 (remaining menu migrations, independent after P8.6)
      ├── P8.9 (input overlays, independent after P8.2)
      ├── P8.10 (remaining overlays, independent after P8.2)
      ├── P8.11 (consolidation + enforcement, after all migrations)
      └── P8.12 (ADR + docs, after P8.11)
```

---

## Preserve Compatibility

- Keep `I_*` interface contracts and `M_*Manager` public APIs stable across phases.
- Phase 1 is the only phase with intentional behavior changes (AI rewrite); parity with existing demo behavior is the acceptance bar.
- Phase 4 changes paths — every `.tres`, scene, and autoload reference must be updated in the same commit that moves the file.
- Phase 6: `RS_BTScoredNode` is additive — existing `child_scorers` array still works during transition. `RS_AIBrainSettings.get_root()` is a virtual method returning `root` by default — no breaking change. During migration, `.tres` and builder scripts coexist until final deletion commit.

---

## TDD Discipline (Reminder)

1. Write the test first.
2. Verify it fails for the expected reason.
3. Implement minimum to pass.
4. Run full suite — no regressions.
5. Run `tests/unit/style/test_style_enforcement.gd` after any new/renamed file.
6. Commit with RED / GREEN marker in the message.

---

## Critical Notes

- **Phase 1 branch**: proceed on existing `cleanup-v8` (off `main`). Phase 1 rewrites a core system; keep unrelated work off this branch to keep the diff isolated.
- **Manual demo check is mandatory** at end of P1.9 before P1.10 deletions.
- **Phase 4 is high-churn**: every move commit should be reviewable in isolation; don't bundle unrelated moves.
- **Phase 5 is last**: easier once code is organized.
- **Phase 6 migration is destructive**: each `.tres` deletion commit is atomic and revertable. Run full suite + visual parity check before deleting.
- **Update `DEV_PITFALLS.md` / `AGENTS.md` after each phase** if entries reference deleted or moved files.
- **Phase 7 builder classes are RefCounted**: `U_EditorPrefabBuilder` and `U_EditorBlockoutBuilder` extend `RefCounted` (not `EditorScript`) for headless GUT testability. EditorScript wrappers in `scripts/demo/editors/` are thin adapters.
- **Phase 7 core/demo boundary**: Builder infrastructure in `scripts/core/utils/editors/`. Demo recipes in `scripts/demo/editors/`. Tests in `tests/unit/editors/`.
- **Phase 7 migration is destructive**: each `.tscn` deletion commit is atomic and revertable. Run full suite + visual parity check before deleting.

---

# Phase 7 — EditorScript + PackedScene Builders

**Reference plan**: `~/.claude/plans/lets-add-a-new-humming-kay.md`.

**Goal**: Replace hand-authored `.tscn` creation with programmatic GDScript builder APIs. Two `RefCounted` builders (`U_EditorPrefabBuilder`, `U_EditorBlockoutBuilder`) provide fluent APIs. Thin `@tool extends EditorScript` wrappers invoke them and call `save()`. All 12 demo prefabs migrate from `.tscn` to builder scripts.

**Depends on**: Phase 6 complete.

---

## Milestone P7.1: U_EditorPrefabBuilder — Root Creation & Fluent API

**Goal**: Core `create_root()`, `inherit_from()`, entity metadata, `build()`.

- [x] **Commit 1 (RED)** — `tests/unit/editors/test_u_editor_prefab_builder.gd`:
  - `create_root("Node3D", "TestRoot")` produces Node3D named "TestRoot"
  - `create_root("StaticBody3D", "TestStatic")` produces StaticBody3D
  - `inherit_from(tmpl_character_path)` produces instanced scene with inherited children
  - `set_entity_id(&"wolf")` and `set_tags([&"predator"])` set metadata on root
  - Fluent API: each method returns `self`
  - `build()` returns root node
  - Error: `build()` before `create_root()` or `inherit_from()` returns null
  - Committed: `1cc1e11c`

- [x] **Commit 2 (GREEN)** — Create `scripts/core/utils/editors/u_editor_prefab_builder.gd`:
  - `U_EditorPrefabBuilder` extends RefCounted
  - `create_root(node_type, name)` — creates node by class name
  - `inherit_from(scene_path)` — loads PackedScene, instantiates with `GEN_EDIT_STATE_MAIN`
  - `set_entity_id(id)`, `set_tags(tags)` — sets metadata on root
  - `build() -> Node` — returns root
  - `_ensure_components_container()` — finds or creates "Components" node
  - Committed: `a309ff3a`

**P7.1 Verification**:
- [x] All new tests green (9/9 passing, 41 asserts).
- [x] Existing test suite green (no regressions).
- [x] Style enforcement green (92/92).

---

## Milestone P7.2: U_EditorPrefabBuilder — ECS Component Wiring

**Goal**: `add_ecs_component()` and `add_ecs_component_by_path()`.

- [x] **Commit 3 (RED)** — `tests/unit/editors/test_u_editor_prefab_builder.gd`: ECS component wiring tests.
- [x] **Commit 4 (GREEN)** — Implement `add_ecs_component()` and `add_ecs_component_by_path()`. Committed: `2bf624ba`.

**P7.2 Verification**:
- [x] All new tests green (14/14, 75 asserts).
- [x] Existing test suite green (no regressions).
- [x] Style enforcement green (92/92).

---

## Milestone P7.3: U_EditorPrefabBuilder — Visuals, Collision & Children

**Goal**: Visual mesh, CSG, collision shapes, markers, child scenes, property overrides.

- [x] **Commit 5 (RED+GREEN)** — Add tests and implement visual, collision, marker, child-scene methods. Committed: `761d5a0d`.

**P7.3 Verification**:
- [x] All new tests green (19/19, 99 asserts).
- [x] Existing test suite green (no regressions).
- [x] Style enforcement green (92/92).

---

## Milestone P7.4: U_EditorPrefabBuilder — Save & EditorScript Adapter

**Goal**: `save()` method and a working wolf prefab EditorScript.

- [x] **Commit 7 (RED+GREEN)** — Implement `save()` with owner propagation. Committed: `fe595fc6`.
- [x] **Builder extension** — `add_child_to` + `add_child_scene_to` added. Committed: `bb6c88aa`.

**P7.4 Verification**:
- [x] All new tests green.
- [x] Existing test suite green.
- [x] Wolf prefab generated in editor matches original visually.

---

## Milestone P7.5: U_EditorBlockoutBuilder — Core CSG API

**Goal**: Blockout builder with CSG primitives, spawn points, markers.

- [x] **Commit 9 (RED+GREEN)** — `U_EditorBlockoutBuilder` with CSG primitives, spawn points, markers, `execute_custom`, `build()`, `save()`. Committed: `9a792b43`.

**P7.5 Verification**:
- [x] All new tests green.
- [x] Existing test suite green.
- [x] Style enforcement green.

---

## Milestone P7.6: U_EditorBlockoutBuilder — Materials, Environment & Save

**Goal**: Material helpers, environment nodes, save, demo blockout.

- [x] **Commit 11 (RED+GREEN)** — Material helper, `add_directional_light()`, `add_world_environment()`, `use_collision`, `save()`, arena blockout demo. Committed: `6c340624`.

**P7.6 Verification**:
- [x] All new tests green.
- [x] Existing test suite green.
- [x] Arena blockout generated in editor looks correct.

---

## Milestone P7.7: Prefab Migration — Demo Prefabs → Builder Scripts

**Goal**: All demo prefabs migrated to builder scripts (21 total).

- [x] **Commits 13–15 (GREEN)** — For each prefab, builder script created under `scripts/demo/editors/`, verified parity, `.tscn` kept as generated artifact.

Character prefabs (inherit from `tmpl_character.tscn`):
- [x] `prefab_woods_wolf.tscn` → `build_prefab_woods_wolf.gd`
- [x] `prefab_woods_rabbit.tscn` → `build_prefab_woods_rabbit.gd`
- [x] `prefab_woods_builder.tscn` → `build_prefab_woods_builder.gd`
- [x] `prefab_demo_npc.tscn` → `build_prefab_demo_npc.gd`

Static object prefabs (fresh root):
- [x] `prefab_woods_water.tscn` → `build_prefab_woods_water.gd`
- [x] `prefab_woods_stone.tscn` → `build_prefab_woods_stone.gd`
- [x] `prefab_woods_stockpile.tscn` → `build_prefab_woods_stockpile.gd`
- [x] `prefab_woods_construction_site.tscn` → `build_prefab_woods_construction_site.gd`

Core gameplay prefabs (fresh root):
- [x] `prefab_woods_tree.tscn` → `build_prefab_woods_tree.gd`
- [x] `prefab_checkpoint_safe_zone.tscn` → `build_prefab_checkpoint_safe_zone.gd`
- [x] `prefab_death_zone.tscn` → `build_prefab_death_zone.gd`
- [x] `prefab_door_trigger.tscn` → `build_prefab_door_trigger.gd`
- [x] `prefab_goal_zone.tscn` → `build_prefab_goal_zone.gd`
- [x] `prefab_spike_trap.tscn` → `build_prefab_spike_trap.gd`
- [x] `prefab_character.tscn` → `build_prefab_character.gd`

Player prefabs:
- [x] `prefab_player.tscn` → `build_prefab_player.gd`
- [x] `prefab_player_body.tscn` → `build_prefab_player_body.gd`
- [x] `prefab_player_ragdoll.tscn` → `build_prefab_player_ragdoll.gd`

Sub-prefab:
- [x] `prefab_demo_npc_body.tscn` → `build_prefab_demo_npc_body.gd`

Scene prefabs:
- [x] `prefab_alleyway.tscn`
- [x] `prefab_bar.tscn`

**P7.7 Verification**:
- [x] All generated scenes visually match originals.
- [x] Full test suite green after each migration.

---

## Milestone P7.8: Style Compliance, ADR & Cleanup

- [x] **Builder extension** — `add_child_to` + `add_child_scene_to` added to `U_EditorPrefabBuilder`.
- [x] **Builder scripts** — All **21** prefabs have builder scripts under `scripts/demo/editors/`.
- [x] **Style suite** passes with new files (94/94).
- [x] **Full suite** passes (8 pending, 0 failures).
- [x] **LOC cap** — `U_EditorPrefabBuilder` refactored to 193 lines (extracted shape methods into `U_EditorShapeFactory`; verified by style test `test_u_editor_prefab_builder_stays_under_two_hundred_lines` **GREEN**).
- [x] **ADR-0012** — Editor Builder Pattern documented at `docs/architecture/adr/0012-editor-builder-pattern.md`.
- [x] **Fix commits** — Godot 3.x Transform3D constructor syntax (`5c7f1fce`), int literal + Unicode arrow fixes (`94cf9f0e`).

**P7.8 Verification**:
- [x] Style suite passes (94/94).
- [x] Full suite green (8 pending, 0 failures).
- [x] ADR-0012 documents architecture decisions.

---

# Phase 8 — LLM-First UI Menu Builders

**Goal**: Replace ~1,000 lines of `@onready` declarations, null-guarded theme application, manual signal wiring, per-control localization, and focus configuration across 5 settings screens (and eventually all UI menus) with programmatic GDScript builder APIs. This applies the same philosophy from Phase 6 (fluent builders replacing `.tres` resources) and Phase 7 (builders replacing `.tscn` scenes) to UI layout, theming, localization, focus, and signal wiring.

**Why**: Settings tabs and menu screens currently use a pattern hostile to LLM co-pilots: 102 `@onready` variables across 5 scripts (~408 null-guard checks), ~220 lines of `_apply_theme_tokens()` doing per-control `add_theme_*_override()`, ~129 lines of `_localize_labels()` calling `U_LOCALIZATION_UTILS.localize(key)` per label, ~113 lines of manual signal wiring (with inconsistent method names), ~146 lines of `_configure_focus_neighbors()`, and 3 duplicate copies of `_localize_with_fallback()`. Adding a single setting means modifying a `.tscn` file, adding an `@onready` var, writing a signal connection, and updating 4 separate arrays. A builder lets an LLM add a setting in one line of code.

**Depends on**: Phase 6 (fluent builder precedent + core/demo directory split).

**Design approach**: Two builders following the Phase 6 fluent pattern:

1. **`U_SettingsTabBuilder`** — builds vertical settings panels (headings, sections, dropdowns, toggles, sliders, action buttons) with automatic theme token application, localization, focus chain configuration, and signal wiring. `build()` creates the node tree, wires all signals, and returns the parent tab.
2. **`U_UIMenuBuilder`** — builds general menu screens (title, button grid, back button) with automatic theme, localization, and focus configuration.
3. **`U_UISettingsCatalog`** — centralizes dropdown/slider option data (window sizes, window modes, vsync options, quality levels, audio bus names, volume ranges, VFX toggle specs) so builders can populate OptionButtons from a single source of truth instead of each tab hand-rolling `_populate_option_buttons()`.

**Current boilerplate inventory** (5 settings scripts):

| File | Lines | @onready | `_apply_theme_tokens` | `_localize_labels` | Signal wiring | `_configure_focus_neighbors` | `_configure_tooltips` | `_localize_with_fallback` |
|---|---|---|---|---|---|---|---|---|
| `ui_display_settings_tab.gd` | 873 | 35 | 60 | 54 | 46 | 42 | 21 | 5 |
| `ui_audio_settings_tab.gd` | 644 | 27 | 65 | 30 | 30 | 39 | 26 | 4 |
| `ui_vfx_settings_overlay.gd` | 430 | 23 | 59 | 23 | 17 | 40 | 26 | 5 |
| `ui_settings_menu.gd` | 339 | 15 | 19 | 22 | 20 | 25 | — | — |
| `ui_localization_settings_tab.gd` | ~300 | 15 | ~30 | ~20 | ~15 | ~25 | ~15 | — |
| **Totals** | ~2,586 | **115** | **~233** | **~149** | **~128** | **~171** | **~88** | **14** |

These ~780 lines of boilerplate collapse to ~80 lines of declarative builder chains.

**LOC target**: ~600 added (builders + catalog + tests), ~780 removed (boilerplate in migrated scripts). Net ~180 LOC reduction. Per-script reductions: display ~873→400, audio ~644→300, VFX ~430→250, settings menu ~339→180.

---

## Milestone P8.1: U_UISettingsCatalog

**Goal**: A data utility that centralizes the dropdown/slider option data currently scattered across `_populate_option_buttons()` in each settings tab. Single source of truth for valid display, audio, and VFX options.

- [x] **Commit 1** (RED) — `tests/unit/ui/helpers/test_u_ui_settings_catalog.gd`:
  - Display options: `get_window_sizes()` returns `Array[Dictionary]` with `id`/`label_key`/`value` entries; `get_window_modes()` returns mode entries; `get_vsync_options()` returns vsync entries; `get_quality_presets()` returns quality entries; `get_ui_scale_range()` returns `{min, max, step, default}`.
  - Audio options: `get_audio_bus_names()` returns bus name array; `get_volume_range()` returns `{min, max, step}`; `get_default_volume()` returns float; `get_spatial_audio_default()` returns bool.
  - VFX options: `get_toggle_options()` returns `{key, label_key, tooltip_key, default}` entries for shake/intensity/flash/particles/silhouette; `get_intensity_range()` returns `{min, max, step, default}`.
  - Localization keys are `StringName` constants (not bare strings).
  - All methods return fresh arrays (not shared mutable state).
- [x] **Commit 2** (GREEN) — `scripts/core/ui/helpers/u_ui_settings_catalog.gd`:
  - `class_name U_UISettingsCatalog`, extends `RefCounted`
  - Static methods returning typed arrays of option dictionaries
  - Localization keys use `&"settings.display.*"` / `&"settings.audio.*"` / `&"settings.vfx.*"` patterns matching existing project keys
  - Option dictionaries follow `{id: StringName, label_key: StringName, value: Variant}` shape

**P8.1 Verification**:
- [x] Catalog tests green
- [x] Style enforcement green

---

## Milestone P8.2: U_SettingsTabBuilder — Core API

**Goal**: Fluent builder that constructs a vertical settings tab programmatically, replacing @onready declarations, manual theme application, localization, focus chains, and signal wiring. The builder produces node trees and wires everything in `build()`.

- [x] **Commit 1** (RED) — `tests/unit/ui/helpers/test_u_settings_tab_builder.gd`:
  - `U_SettingsTabBuilder.new(tab)` initializes with parent tab Control.
  - `set_heading(&"settings.display.title")` creates a heading label and applies `config.heading` font_size.
  - `begin_section(&"settings.display.section.graphics")` creates a section header label and applies `config.section_header` font_size + `config.section_header_color`.
  - `.add_dropdown(key, options, callback)` creates Label + OptionButton row; populates from options array; connects `item_selected` to callback; applies `config.body_small` font_size to label + `config.text_secondary` color; applies `config.section_header` font_size to OptionButton.
  - `.add_toggle(key, callback)` creates Label + CheckBox row; connects `toggled` to callback; applies theme tokens.
  - `.add_slider(key, min_val, max_val, step, callback, value_label_key)` creates Label + HSlider + percentage Label row; connects `value_changed` to callback; applies theme tokens; percentage label gets `config.body_small` + `config.text_secondary`.
  - `.end_section()` closes current section.
  - `.add_action_buttons(apply_callback, cancel_callback, reset_callback)` creates HBoxContainer with 3 Buttons; applies `config.section_header` font_size to each; connects `pressed` signals; uses `config.separation_compact`.
  - `.build()` adds all nodes to the parent tab, calls `U_FocusConfigurator.configure_vertical_focus()` on focusable controls, applies theme tokens from `U_UI_THEME_BUILDER.active_config`, localizes all labels, returns the parent tab.
  - `localize_labels()` re-applies all localization keys via `U_LOCALIZATION_UTILS.localize(key)`.
  - `apply_theme_tokens(config)` re-applies all theme overrides from a given config.
  - Fluent chaining: every method returns `self` except `build()` which returns the parent tab.
- [x] **Commit 2** (GREEN) — `scripts/core/ui/helpers/u_settings_tab_builder.gd`:
  - `class_name U_SettingsTabBuilder`, extends `RefCounted`
  - Instance-based fluent API (methods return `self`)
  - Internal state: `_tab: Control`, `_controls: Array[Control]`, `_label_keys: Dictionary`, `_theme_map: Array[Dictionary]`, `_focusable_controls: Array[Control]`
  - `build()` creates nodes, wires signals, applies theme tokens from `U_UI_THEME_BUILDER.active_config`, calls `U_FocusConfigurator.configure_vertical_focus()` on `_focusable_controls`, localizes all labels
  - `localize_labels()` re-applies all localization keys
  - `apply_theme_tokens(config)` re-applies all theme overrides
  - Internal `_localize(key, fallback)` replaces per-script `_localize_with_fallback()`
- [x] **Commit 3** (GREEN) — Style enforcement: LOC cap 300 lines for `u_settings_tab_builder.gd`.

**P8.2 Verification**:
- [x] Builder tests green
- [ ] Built tabs render correctly in editor (manual check with display settings)
- [x] Style enforcement green

---

## Milestone P8.3: Settings Tab Migration — Display Settings

**Goal**: Convert `ui_display_settings_tab.gd` from 873 lines / 35 @onready vars to a builder-driven implementation. Proof-of-concept and validation of the full builder pipeline end-to-end.

- [x] **Commit 1** (RED) — Integration test: `tests/unit/ui/settings/test_ui_display_settings_tab_builder.gd`:
  - Builder script produces a tab with all display settings controls equivalent to the existing `.tscn`-authored tab.
  - All OptionButtons populated from `U_UISettingsCatalog`.
  - All signal callbacks fire correctly (window size, window mode, vsync, quality, etc.).
  - Focus chain covers all interactive controls in correct order.
  - Theme tokens applied correctly to all controls.
  - Localization keys resolve to current locale strings.
- [x] **Commit 2** (GREEN) — Refactor `ui_display_settings_tab.gd`:
  - Replace 35 @onready vars with builder-constructed nodes
  - Replace `_apply_theme_tokens()` (60 lines) with `builder.apply_theme_tokens(config)`
  - Replace `_localize_labels()` (54 lines) with `builder.localize_labels()`
  - Replace `_connect_signals()` (46 lines) with builder-internal signal wiring
  - Replace `_configure_focus_neighbors()` (42 lines) with `builder.build()` auto-configuration
  - Replace `_populate_option_buttons()` (26 lines) with `U_UISettingsCatalog` data
  - Replace `_configure_tooltips()` (21 lines) with builder-internal tooltip configuration
  - Keep `_on_state_changed()`, `_on_reset_pressed()`, `_on_apply_pressed()`, `_on_cancel_pressed()`, window confirmation dialog logic, and `_dispatch_display_settings()` — these are behavior, not boilerplate
  - Target: tab script shrinks from ~873 lines to ~400 lines (behavior + builder config)
- [ ] **Commit 3** (GREEN) — Remove corresponding `.tscn` inline theme overrides and @onready node references if the scene structure changes. Update any test references.

**P8.3 Verification**:
- [ ] Display settings tab functions identically to pre-migration
- [x] All theme tokens applied correctly
- [x] Localization refresh works on locale change
- [ ] Focus chain navigable by gamepad
- [x] Full suite green
- [x] No orphaned scene references

---

## Milestone P8.4: Settings Tab Migration — Audio Settings

- [x] **Commit 1** (RED) — Integration test for audio settings tab builder equivalence (`tests/unit/ui/settings/test_ui_audio_settings_tab_builder.gd`).
- [x] **Commit 2** (GREEN) — Refactor `ui_audio_settings_tab.gd`:
  - 27 @onready vars → builder-constructed nodes
  - ~65 lines `_apply_theme_tokens()` → builder-managed
  - ~30 lines `_localize_labels()` → builder-managed
  - ~30 lines `_connect_signals()` → builder-internal
  - ~39 lines `_configure_focus_neighbors()` → builder-internal
  - ~26 lines `_configure_tooltips()` → builder-internal
  - Custom `_input()` slider-to-mute navigation preserved as behavior
  - Target: ~644 → ~300 lines

**P8.4 Verification**:
- [x] Audio settings tab parity (targeted unit + localization + theme suites green)
- [ ] Full suite green

---

## Milestone P8.5: Settings Tab Migration — VFX Settings

- [x] **Commit 1** (RED) — Integration test for VFX settings overlay builder equivalence (`tests/unit/ui/settings/test_ui_vfx_settings_overlay_builder.gd`).
- [x] **Commit 2** (GREEN) — Refactor `ui_vfx_settings_overlay.gd`:
  - 23 @onready vars → builder-constructed nodes
  - ~59 lines `_apply_theme_tokens()` → builder-managed
  - ~23 lines `_localize_labels()` → builder-managed
  - ~17 lines `_connect_control_signals()` → builder-internal
  - ~40 lines `_configure_focus_neighbors()` → builder-internal
  - ~26 lines `_configure_tooltips()` → builder-internal
  - Apply/Cancel/Reset logic preserved as behavior
  - Target: ~430 → ~250 lines

**P8.5 Verification**:
- [x] VFX settings overlay parity (unit localization + integration suites green)
- [ ] Full suite green

---

## Milestone P8.6: U_UIMenuBuilder — Core API

**Goal**: Fluent builder for general menu screens (main menu, pause menu, language selector, credits, game over, victory). Creates title, button grid, back button, with automatic theme, localization, and focus configuration.

- [ ] **Commit 1** (RED) — `tests/unit/ui/helpers/test_u_ui_menu_builder.gd`:
  - `U_UIMenuBuilder.new(menu)` initializes with parent menu Control.
  - `set_title(&"menu.main.title")` creates heading label with `config.heading`.
  - `.add_button(&"menu.main.continue", callback)` creates Button, connects `pressed`, applies `config.section_header` font_size.
  - `.add_button_group(buttons: Array)` creates vertical button list.
  - `.set_back_button(&"common.back", callback)` creates back/cancel button at bottom.
  - `.set_background_dim(color)` sets dim ColorRect.
  - `.build()` adds nodes, calls `U_FocusConfigurator.configure_vertical_focus()`, localizes labels, applies theme tokens, returns parent menu.
  - `localize_labels()` / `apply_theme_tokens(config)` refresh methods.
  - Fluent chaining throughout.
- [ ] **Commit 2** (GREEN) — `scripts/core/ui/helpers/u_ui_menu_builder.gd`:
  - `class_name U_UIMenuBuilder`, extends `RefCounted`
  - Instance-based fluent API
  - LOC cap 200 lines
- [ ] **Commit 3** (GREEN) — Style enforcement for both builders.

**P8.6 Verification**:
- [ ] Menu builder tests green
- [ ] Style enforcement green

---

## Milestone P8.7: Menu Screen Migration — Main Menu + Pause Menu

- [ ] **Commit 1** (RED) — Integration tests for main menu and pause menu builder equivalence.
- [ ] **Commit 2** (GREEN) — Refactor `ui_main_menu.gd`:
  - 10 @onready vars → builder-constructed nodes
  - ~19 lines `_apply_theme_tokens()` → builder-managed
  - ~22 lines `_localize_labels()` → builder-managed
  - Signal wiring from `_on_panel_ready()` → builder-internal
  - Target: ~339 → ~180 lines
- [ ] **Commit 3** (GREEN) — Refactor `ui_pause_menu.gd`:
  - 9 @onready vars → builder-constructed nodes
  - Theme/localize/focus → builder-managed
  - Target: ~280 → ~150 lines

**P8.7 Verification**:
- [ ] Main menu and pause menu parity
- [ ] Full suite green

---

## Milestone P8.8: Menu Screen Migration — Language Selector, Credits, Game Over, Victory, Settings Menu

- [ ] **Commit 1** (GREEN) — Refactor `ui_language_selector.gd` (12 @onready → builder). Grid focus configuration preserved via `U_FocusConfigurator.configure_grid_focus()` call after `build()`.
- [ ] **Commit 2** (GREEN) — Refactor `ui_credits.gd` (12 @onready → builder). Auto-scroll behavior preserved.
- [ ] **Commit 3** (GREEN) — Refactor `ui_game_over.gd` (7 @onready → builder).
- [ ] **Commit 4** (GREEN) — Refactor `ui_victory.gd` (8 @onready → builder).
- [ ] **Commit 5** (GREEN) — Refactor `ui_settings_menu.gd` (15 @onready → builder).

**P8.8 Verification**:
- [ ] All menu screen parity
- [ ] Full suite green

---

## Milestone P8.9: Settings Overlay Migration — Input Overlays

- [ ] **Commit 1** (GREEN) — Refactor `ui_gamepad_settings_overlay.gd` (32 @onready → builder). Deadzone preview preserved as builder-external behavior.
- [ ] **Commit 2** (GREEN) — Refactor `ui_keyboard_mouse_settings_overlay.gd` (20 @onready → builder).
- [ ] **Commit 3** (GREEN) — Refactor `ui_touchscreen_settings_overlay.gd` (35 @onready → builder — highest count). Touchscreen preview integration with `U_TouchscreenPreviewBuilder` preserved.

**P8.9 Verification**:
- [ ] All input overlay parity
- [ ] Touchscreen preview builder integration still works
- [ ] Full suite green

---

## Milestone P8.10: Remaining Overlay Migrations

- [ ] **Commit 1** (GREEN) — Refactor `ui_localization_settings_tab.gd` (15 @onready → builder). Language dropdown populated from `U_UISettingsCatalog`; confirm dialog preserved as behavior.
- [ ] **Commit 2** (GREEN) — Refactor `ui_input_profile_selector.gd` (15 @onready → builder). Profile cycling preserved as behavior.
- [ ] **Commit 3** (GREEN) — Refactor `ui_save_load_menu.gd` (12 @onready → builder). Slot list preserved as behavior.
- [ ] **Commit 4** (GREEN) — Refactor `ui_input_rebinding_overlay.gd` (14 @onready → builder). Note: this already uses `U_RebindActionListBuilder`, so `U_UIMenuBuilder` handles the outer chrome (title, buttons) while `U_RebindActionListBuilder` continues handling action rows.

**P8.10 Verification**:
- [ ] All overlay parity
- [ ] Full suite green

---

## Milestone P8.11: Consolidate BaseSettingsSimpleOverlay + Style Enforcement

- [ ] **Commit 1** (GREEN) — Update `base_settings_simple_overlay.gd` to use `U_SettingsTabBuilder` internally for its 2 @onready vars and 17-line `_apply_theme_tokens()`, since all subclasses now use the builder.
- [ ] **Commit 2** (GREEN) — Extract `_localize_with_fallback()` from the 3 duplicate copies (display, audio, VFX settings) into `U_LOCALIZATION_UTILS.localize_with_fallback(key, fallback)`. Remove the private copies.
- [ ] **Commit 3** (GREEN) — Style enforcement:
  - `scripts/core/ui/helpers/u_settings_tab_builder.gd` under 300 lines
  - `scripts/core/ui/helpers/u_ui_menu_builder.gd` under 200 lines
  - `scripts/core/ui/helpers/u_ui_settings_catalog.gd` under 150 lines
  - Settings scripts under `scripts/core/ui/settings/` must not contain `_localize_with_fallback()` (consolidated into utils)
  - No new `_apply_theme_tokens()` method in any builder-migrated settings/menu script (builder handles it)
  - No new `@onready` declarations in builder-migrated settings/menu scripts for theme-able controls (builder constructs them)

**P8.11 Verification**:
- [ ] Base class simplified
- [ ] `_localize_with_fallback()` deduplicated
- [ ] Style enforcement green
- [ ] Full suite green

---

## Milestone P8.12: ADR + Extension Recipe Update

- [ ] **Commit 1** — ADR: `docs/architecture/adr/0012-llm-first-ui-menu-builders.md`:
  - Status: Proposed
  - Context: UI settings screens and menu overlays use ~780 lines of repetitive boilerplate across 5 scripts (102 `@onready` vars, ~220 lines of per-control theme application, ~129 lines of per-control localization, ~113 lines of manual signal wiring, ~146 lines of focus configuration, 3 copies of `_localize_with_fallback()`). Adding a single setting requires modifying a `.tscn` file, adding an `@onready` var, writing a signal connection, and updating theme/localize/focus code — exactly the LLM-hostile pattern that Phases 6–7 eliminated for data resources and scene authoring.
  - Decision: Replace @onready-heavy `.tscn` UI authoring with fluent GDScript builders (`U_SettingsTabBuilder`, `U_UIMenuBuilder`) for LLM turn efficiency, readable diffs, and auto-wired theme/localize/focus/signal boilerplate. A `U_UISettingsCatalog` utility centralizes dropdown option data.
  - Alternatives: keep `.tscn`-only (LLM-hostile, high boilerplate), hybrid builder/scene approach (partial improvement, still requires `.tscn` coordination), code-generated `.tscn` (still hostile to diffs).
  - Consequences: LLM-friendly single-file authoring; eliminates ~780 lines of boilerplate; readable git diffs; backward compat maintained via `BasePanel`/`BaseMenuScreen`/`BaseOverlay` inheritance; behavior logic stays in tab scripts.
  - References: Phase 6 ADR (`0011-llm-first-fluent-builders.md`), existing `U_RebindActionListBuilder` precedent, `U_UIThemeBuilder` token pipeline.
- [ ] **Commit 2** — Update `docs/architecture/extensions/ui.md` recipe:
  - Add "To add a settings tab" → `U_SettingsTabBuilder.new(tab).set_heading(…).begin_section(…).add_dropdown(…).build()`
  - Add "To add a menu screen" → `U_UIMenuBuilder.new(menu).set_title(…).add_button(…).build()`
  - Add "To add a dropdown option catalog" → extend `U_UISettingsCatalog`
  - Reference ADR 0012

**P8.12 Verification**:
- [ ] ADR passes `test_adr_structure`
- [ ] Extension recipe update passes `test_extension_recipe_structure`
- [ ] Full suite green

---

**Phase 8 Critical Notes**:

- **Builder scripts produce live node trees, not `.tscn` files**: Unlike P6/P7 where builder output replaces static resources, P8 builders construct Godot nodes at runtime via `_ready()`. The `.tscn` scene files for settings tabs still exist but contain minimal structure (the parent Control/VBoxContainer) — all child controls are built programmatically.
- **Behavior stays in tab scripts**: `_on_state_changed()`, `_on_reset_pressed()`, `_on_apply_pressed()`, `_on_cancel_pressed()`, and state-sync logic remain in the tab/overlay scripts. The builder only handles construction, theming, localization, focus chains, and signal wiring.
- **Backward compatibility**: `BaseMenuScreen`, `BasePanel`, and `BaseOverlay` base classes are unchanged. Builder-constructed content is added as children to the existing scene root. `_on_locale_changed()` still calls `builder.localize_labels()` — the builder exposes refresh methods.
- **Loc dependency**: P8.1 `U_UISettingsCatalog` must match existing localization keys in `resources/core/localization/`. If keys change, catalog constants must update in lock-step.
- **TDD discipline**: RED test first, then GREEN implementation, per Phase 1–7 precedent.
- **Phase 8 migration is destructive**: each `.tscn` simplification commit is atomic and revertable. Run full suite + visual parity check before committing simplifications.
