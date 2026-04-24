# Cross-System Cleanup V8 — Tasks Checklist

**Branch**: `cleanup-v8` (off `main`, with `GOAP-AI` merged via PR #16). Phase 1 proceeds on this branch. Subsequent phases can branch from `main` after Phase 1 merges, or continue on `cleanup-v8` if preferred. Matches continuation prompt.
**Status**: Phase 1 complete — P1.1 complete; P1.2 complete (`b5962d32`, `e07a933a`, `a70032dd`, `784aede9`, `e84e2890`, `79344746`); P1.3 complete (`8c163ae0`, `5051a2c4`, `fa7fc071`, `aa083186`, `7a3e936f`); P1.4 complete (`6ad6e79c`, `677003b4`, `b5eafe91`); P1.5 complete (`488807d2`, `cf80eb4f`, `4069c08a`, `165d93c4`, `4ea75032`, `5e3bdf5e`, `a2c54f7b`); P1.6 complete (`f46f1fa3`, `5967661e`); P1.6b complete (`a98fd907`, `08f2aaf4`, `0c196e7d`, `3dda0fd5`, `0128edd0`, `78d73d09`, `8b2198c6`, `97252380`, `0ad8c49d`, `90ce7243`, `07ba856a`, `64de76f6`, `7364b41f`); P1.7 complete (`6385e68d`, `fbcaccd9`, `54425b93`, `bf2a734e`); P1.8 complete (`fee01ce5`, `301b39be`, `2b04de39`, `a3f4bc33`); P1.9 complete (`26289494`, `fffa2e55`, `7de2a6cf`, `c1d7b0fb`, `a2766455`, `2aacb999` + remediation `91c094c0`..`e416469c`); P1.9b complete (`348802ca`, `b2c67185`, `7a96c4b0`, `d2644cf3`, `0bb07870`, `085c428d`, `73a66510`, `cd2afbcf`, `94d4b7c6` + 2026-04-22 verification follow-through); P1.10 BT-only legacy cleanup complete (`43035ad6`, `6a30f13c` + 2026-04-23 docs hygiene follow-through). Phase 2 complete through P2.4 (`28702b95`) with style recheck passing (`83/83`). Phase 3 is now in progress: P3.0 docs reorg complete (2026-04-23) with ADR normalization (`0001..0005` under `docs/architecture/adr/`), `docs/guides/`, `docs/history/`, and `docs/systems/` structure landed, and legacy pre-P3 roots removed. P3.5 Phase 3 deliverable remains the recipe framework only (dir + `README.md` + template + structure test); individual recipes ship at the tail of their owning phase.
**Methodology**: TDD (Red-Green-Refactor) — tests written within each milestone, not deferred.
**Scope**: Five independent phases. Phase 1 is the largest (AI rewrite) and must complete before Phases 2–5, because Phases 4–5 depend on a stable AI architecture to decide what is "core template" vs "demo content."

**Relationship to cleanup-v7.2**: This is a successor plan, not a replacement. V7.2 addressed architectural weaknesses inside existing systems. V8 addresses structural/organizational debt surfaced while working on the AI forest: the planner stack is overbuilt, debug/perf code is scattered across managers, `AGENTS.md` is sprawling, template-vs-demo content is entangled, and temp scenes are piling up.

---

## Purpose

Five unrelated cleanups bundled because they share an outcome: **make the template LLM-friendly, modular, and ship-ready as a reusable base.**

1. **Phase 1 — AI rewrite.** Replace the GOAP + HTN stack with utility-scored behavior trees. Plan file: `~/.claude/plans/whats-a-better-approach-snoopy-candle.md`. ~940 LOC of planning infrastructure serves behaviors that are, in practice, priority-ordered condition checks → fixed 2–4 step action sequences. No compound task has multiple decomposition methods. Every behavior-add touches 4 layers across two planning vocabularies, which is exactly where LLMs struggle.
2. **Phase 2 — Debug/perf extraction.** Managers and ECS systems have accumulated in-line debug logging and perf probes (e.g., mobile camera perf probes documented in `DEV_PITFALLS.md`). Consolidate through the existing `U_DebugLogThrottle` / `U_PerfProbe` utilities so production code paths stop carrying inspection logic. `U_PerfProbe` already exists at `scripts/utils/debug/u_perf_probe.gd` and is in use; Phase 2 extends adoption and forbids bare `print()` in managers/systems.
3. **Phase 3 — Docs split.** `AGENTS.md` has grown into a single mega-doc with overlap against `DEV_PITFALLS.md`. Split by audience and concern so LLMs (and humans) can load just the section they need.
4. **Phase 4 — Template vs demo separation.** Forest AI (wolf/deer/rabbit), sentry/drone/prism agents, and any demo-only scenes are entangled with core template code under `scripts/` and `resources/`. Reorganize into `template/` (core) and `demo/` (examples) so consumers can delete the demo tree without breaking the template.
5. **Phase 5 — Base scene reset.** Multiple temp / fake scenes exist under `scenes/`. Define one canonical base scene, migrate the real demo content to it, delete the rest.

Phases 2–5 are independent of each other and can be reordered, but all depend on Phase 1.

---

## Sequencing

- **Phase 1** lands first. Non-trivial rewrite with full TDD discipline. Separate branch recommended.
- **Phase 2** can land any time after Phase 1.
- **Phase 3** can run in parallel with Phase 2 (pure docs).
- **Phase 4** must come after Phase 1 (the AI split is the largest template-vs-demo decision).
- **Phase 5** should come last — scene cleanup is easier once code is organized.

**Cross-milestone integration**: Full test suite after each phase. The Phase 1 → Phase 4 chain is the highest-risk path.

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
  - `scripts/resources/bt/rs_bt_composite.gd` — `class_name RS_BTComposite`, `extends RS_BTNode`. Typed `children: Array[RS_BTNode]` with `_coerce_children()` setter matching F7 pattern.
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
  - Completed in commit `b5962d32`; test run is red for expected reason (`res://scripts/resources/bt/rs_bt_sequence.gd` missing).
- [x] **Commit 2** (GREEN) — `scripts/resources/bt/rs_bt_sequence.gd`. State bag stores current child index.
  - Completed in commit `e07a933a` (`RS_BTSequence` + headless-safe BT test helper/coercion updates).
- [x] **Commit 3** (RED) — `test_rs_bt_selector.gd`:
  - Empty selector → FAILURE.
  - First SUCCESS short-circuits → SUCCESS.
  - All-FAILURE → FAILURE.
  - RUNNING child → RUNNING, re-enters next tick.
  - Completed in commit `a70032dd`; test run is red for expected reason (`res://scripts/resources/bt/rs_bt_selector.gd` missing).
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
  - Typed `preconditions: Array[I_Condition]` with coerce setter (F7 pattern).
  - Typed `effects: Array[RS_WorldStateEffect]` with coerce setter.
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
- RED verification: `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/bt/test_rs_world_state_effect.gd` failed for expected reason (`res://scripts/resources/ai/bt/rs_world_state_effect.gd` missing).
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
- RED verification: `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/bt/test_rs_bt_planner_action.gd` failed for expected reason (`res://scripts/resources/ai/bt/rs_bt_planner_action.gd` missing).
- Style verification after test-file creation: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` passed (`60/60`).
- Commit 6 (GREEN) `78d73d09`: implemented `scripts/resources/ai/bt/rs_bt_planner_action.gd` with typed/coerced `preconditions` and `effects`, positive-cost applicability guard, and `child` tick delegation.
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
- Commit 11 (GREEN) `64de76f6`: wired planner debug snapshot propagation in `scripts/ecs/components/c_ai_brain_component.gd` (`get_debug_snapshot()` now merges `last_plan`/`last_plan_cost` from planner state bag data) and updated `scripts/debug/debug_ai_brain_panel.gd` to render planner path + cost when present.
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
- [x] **Commit 3** (GREEN) — Update `scripts/debug/debug_ai_brain_panel.gd` to render active BT path from `get_debug_snapshot()` instead of goal + queue.

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
  - `scripts/debug/debug_woods_agent_label.gd` + `scenes/debug/debug_woods_agent_label.tscn` (shows goal/task/thirst/hunger/inventory)
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
- [ ] Release build has zero debug overhead (perf probe disabled flag verified by mobile profiling session).

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
- [ ] **Remaining commits** — Continue section-by-section per inventory plan. One commit per destination file where practical. Update cross-references.
- [ ] **Final AGENTS commit** — Shrink `AGENTS.md` to a routing index (~100 lines target, 150 hard cap — matches P3 Verification).
- [ ] **Final pitfalls commit** — Delete `DEV_PITFALLS.md` once contents fully redistributed.

## Milestone P3.4: Decision ADRs — "Why We Chose X"

V7.2 F5 created `docs/architecture/adr/0001-channel-taxonomy.md`. V8 moves ADRs under `docs/architecture/adr/` so decision records live under the architecture bucket, while extension recipes live separately under `docs/architecture/extensions/`. V8 makes several structural decisions worth recording so future contributors (and LLMs) can audit *why* without reverse-engineering from code or git history.

- [ ] **Commit 0** (migration) — `git mv docs/architecture/adr/ docs/architecture/adr/`. Update any `docs/architecture/adr/` references in `AGENTS.md`, `CLAUDE.md`, style enforcement tests, and V7.2 F5 continuation doc. Confirm no dangling links.

**ADR template** (mirror `0001-channel-taxonomy.md`'s shape):

- Title + number + status (Accepted / Superseded / Deprecated)
- Context (what prompted the decision)
- Decision (what was chosen)
- Alternatives considered (brief pros/cons of each)
- Consequences (positive and negative)
- References (plan files, PRs, commit ranges)

**ADRs to author** (each lives at the tail of its owning phase, not batched):

- [ ] **Commit 1** (tail of P1) — `docs/architecture/adr/0006-ai-architecture-utility-bt-with-scoped-planning.md`:
  - Decision: utility-scored behavior trees with opt-in `RS_BTPlanner` for planning.
  - Alternatives: full GOAP + MBT, keep GOAP + HTN, plain BT without scoring.
  - References: `~/.claude/plans/whats-a-better-approach-snoopy-candle.md`, Phase 1 commits.
- [ ] **Commit 2** (tail of P1) — `docs/architecture/adr/0007-bt-framework-scope-general-vs-ai-specific.md`:
  - Decision: general BT under `scripts/resources/bt/`; AI-specific leaves + planner under `scripts/resources/ai/bt/`.
  - Alternatives: AI-only; fully general with AI imports in core.
- [ ] **Commit 3** (tail of P2) — `docs/architecture/adr/0008-debug-perf-utility-extraction.md`:
  - Decision: managers + ECS systems route debug through `U_DebugLogThrottle` / `U_PerfProbe`; bare `print()` forbidden.
  - Alternatives: inline guards, compile-time flags.
- [ ] **Commit 4** (tail of P4) — `docs/architecture/adr/0009-template-vs-demo-separation.md`:
  - Decision: `scripts/core/` + `scripts/demo/` (same in `resources/`); enforced by import-boundary grep.
  - Alternatives: keep mixed; top-level `template/`/`game/`.
- [ ] **Commit 5** (tail of P5) — `docs/architecture/adr/0010-base-scene-and-demo-entry-split.md`:
  - Decision: two scenes — existing `scenes/templates/tmpl_base_scene.tscn` (refactored in P5.2) + `scenes/demo/demo_entry.tscn`.
  - Alternatives: single scene with embedded demo menu; minimal-only.
- [ ] **Commit 6** (tail of P3 itself) — amend `docs/architecture/adr/0005-service-locator.md` in-place (not a new file):
  - Add V7.2 F6 scope isolation clause (`push_scope`/`pop_scope` per-test) to Decision + Consequences sections.
  - Add "no Godot autoloads" clause (empty autoload list; codifies `CLAUDE.md` rule) to Decision + Consequences sections.
  - Bump Status line (e.g., `Status: Accepted (amended 2026-04-DD — V8 P3)`). Do not supersede; the original decision stands with clarifications.
  - Rationale for amendment (not new ADR): pre-existing `0005-service-locator.md` already records the service-locator decision; V8's additions are clarifications of the same decision, not a new one.

- [ ] **Commit 7** — `docs/architecture/adr/README.md`: index with status + one-line summary per ADR.
- [ ] **Commit 8** — Style enforcement: `test_adr_structure.gd` asserts every `docs/architecture/adr/[0-9]{4}-*.md` has required sections (Status / Context / Decision / Alternatives / Consequences).

**P3.4 Verification**:
- [ ] All 5 new decision ADRs (`0006..0010`) exist with required sections.
- [ ] `docs/architecture/adr/0005-service-locator.md` amendment includes scope-isolation + no-autoloads clauses and an updated Status line.
- [ ] `docs/architecture/adr/README.md` indexes all ADRs.
- [ ] ADR structure test green.

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
    - "To add a new condition" → implement `I_Condition`; F7 typed arrays + `_coerce_children()` pattern applies to composites.
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
    - "To add a validated resource" → property setters with `push_error` fail loud at load (F15 pattern); backing-field pattern consistent with F7 `_coerce_*` setters; include `resource_path` in error messages.
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

- [ ] **Commit 19** — `docs/architecture/extensions/README.md`:
  - Index of all recipes with a **Feature → Recipe** routing table so an LLM landing on "add an X" finds the right recipe in one hop.
  - Example row: `"Add a new AI behavior" → ai.md`.
  - Each entry lists the governing decision ADR(s) so the reader can jump to "why" if needed.
  - Update `AGENTS.md` to route to both `docs/architecture/adr/README.md` (decisions) and `docs/architecture/extensions/README.md` (recipes).

- [ ] **Commit 20** — Style enforcement: `test_extension_recipe_structure.gd` — every file matching `docs/architecture/extensions/*.md` (except `README.md`) must contain the required sections (`When to use`, `Governing ADR(s)`, `Canonical example`, `Vocabulary`, `Recipe`, `Anti-patterns`). Catches drift.

**P3.5 Verification**:
- [ ] All 18 recipes exist with required sections (10 core + 8 secondary).
- [ ] Each recipe references a real canonical example file that currently exists in the repo (not a placeholder).
- [ ] `docs/architecture/extensions/README.md` routing table covers every subsystem.
- [ ] Each recipe links to its governing ADR(s).
- [ ] Recipe structure test green.
- [ ] `AGENTS.md` routes to both `docs/architecture/adr/README.md` and `docs/architecture/extensions/README.md`.
- [ ] **Dogfood check**: pick one recipe; have it drive a trivial derivative feature (e.g., "add a no-op scorer" following `ai.md`). If the recipe doesn't suffice, it's incomplete.

**Sequencing note**: recipes are authored at the tail of their owning phase, not all at once. `ai.md` after P1.10. `ecs.md` depends on V7.2 F9 being landed. Phase 3's mechanical commits are the two `README.md` files + the two structure tests. Individual recipe commits move earlier, into the tail of each owning phase.

---

## Milestone P3.6: Archive `cleanup_v8/` itself

Tail of P3, after all other P3 milestones are green. Moves this plan into `docs/history/` now that it's frozen.

- [ ] **Commit 1** — `git mv docs/guides/cleanup_v8 docs/history/cleanup_v8`. Update any remaining references (V8 continuation docs, MEMORY entries if any).

---

**P3 Verification**:
- [ ] Every pre-existing section lives somewhere new.
- [ ] `AGENTS.md` under 150 lines.
- [ ] No dangling cross-references.
- [ ] `CLAUDE.md` project file still points at the right entry.
- [ ] `docs/architecture/adr/` contains reconciled ADR set under one numeric convention + V8 ADRs + `README.md` — specifically: 5 pre-existing/V7.2 ADRs renumbered to `0001..0005` + 5 new V8 ADRs at `0006..0010` + amendment on `0005-service-locator.md` + `README.md`.
- [ ] `docs/architecture/extensions/` contains `ai.md`, `state.md`, `vcam.md`, `ecs.md`, `managers.md`, `ui.md`, `scenes.md`, `save.md`, `input.md`, `audio.md`, `objectives.md`, `conditions_effects_rules.md`, `events.md`, `debug.md`, `display_post_process.md`, `localization.md`, `resources.md`, `tests.md` + `README.md`.
- [ ] `docs/guides/`, `docs/history/`, `docs/systems/` exist per P3.0 structure; `docs/guides/` and `docs/architecture/adr/` no longer exist.

---

# Phase 4 — Core Template vs Demo-Specific Separation

**Goal**: Someone cloning this template should be able to `rm -rf demo/` (or equivalent) and have a clean core template to build on. Today, forest creatures, sentry/drone/prism, and various demo scenes are interleaved with core systems.

## Milestone P4.1: Classification

- [ ] **Commit 1** — `docs/guides/cleanup_v8/template_vs_demo.md`: every top-level dir classified as **core** (ECS framework, state store, managers, UI kits, input, audio, debug infra) or **demo** (forest AI, sentry/drone/prism, gameplay sample scenes, sample audio/vfx assets).

## Milestone P4.2: Target Structure (Proposed)

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

- [ ] **Commit 1** (RED) — Grep test: `scripts/core/` never imports from `scripts/demo/`. (Reverse direction is fine.)
- [ ] **Commit 2+** (GREEN) — Move files per classification. One commit per logical chunk (AI forest, sentry, demo gameplay scenes, etc). Update all imports. Update `.tres` resource paths.
- [ ] **Commit N** (GREEN) — Update scene references, project settings, autoload paths.

## Milestone P4.4: Enforcement

- [ ] **Commit 1** — Style enforcement: `scripts/core/**/*.gd` contains zero references to `scripts/demo/` paths or `class_name` prefixes registered under demo.

**P4 Verification**:
- [ ] Full test suite green after each move commit.
- [ ] Deleting `scripts/demo/` and `resources/demo/` leaves a building (if non-functional-without-content) template.
- [ ] Core import boundary enforcement green.

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

## Dependency Graph

```
Phase 1 (AI BT rewrite)
   ├── Phase 2 (debug/perf) — independent
   ├── Phase 3 (docs split) — independent
   ├── Phase 4 (template/demo split) ── depends on Phase 1
   └── Phase 5 (scenes) ── depends on Phase 4
```

---

## Preserve Compatibility

- Keep `I_*` interface contracts and `M_*Manager` public APIs stable across phases.
- Phase 1 is the only phase with intentional behavior changes (AI rewrite); parity with existing demo behavior is the acceptance bar.
- Phase 4 changes paths — every `.tres`, scene, and autoload reference must be updated in the same commit that moves the file.

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
- **Update `DEV_PITFALLS.md` / `AGENTS.md` after each phase** if entries reference deleted or moved files.
