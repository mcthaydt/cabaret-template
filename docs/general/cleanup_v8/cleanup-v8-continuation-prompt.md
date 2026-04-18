# Cross-System Cleanup V8 — Continuation Prompt

## Overview

Implements `docs/general/cleanup_v8/cleanup-v8-tasks.md` in phase order with TDD discipline. V8 is the follow-up to V7.2, addressing structural/organizational debt rather than internal architectural issues.

**Branch**: `cleanup-v8` (off `main`, after `GOAP-AI` merged via PR #16). Phase 1 proceeds on this branch; subsequent phases can branch from `main` after Phase 1 merges, or continue on `cleanup-v8` if preferred.
**Status**: Phase 1 in progress. P1.1–P1.6 complete; P1.6b in progress (Commit 1 RED `a98fd907`, Commit 2 GREEN `08f2aaf4`, Commit 3 RED `0c196e7d`, Commit 4 GREEN `3dda0fd5`, Commit 5 RED `0128edd0`, Commit 6 GREEN `78d73d09`, Commit 7 RED `8b2198c6`, Commit 8 GREEN `97252380`, Commit 9 RED `0ad8c49d`, Commit 10 GREEN `90ce7243`, follow-up GREEN fix `07ba856a`). P1.6 commits: `f46f1fa3`, `5967661e`.
**Next Task**: P1.6b Commit 11 (GREEN) — wire planner debug snapshot into `C_AIBrainComponent.get_debug_snapshot()` and `debug_ai_brain_panel.gd`.
**Prerequisite**: V7.2 is complete (commit `e015aff2 "cleanup-v7.2 complete"` landed the F10 verification test). No blockers.

---

## Scope Summary

Five independent phases bundled for a single goal: make the template LLM-friendly, modular, and ship-ready as a reusable base.

1. **Phase 1 — AI Rewrite (utility-scored BTs).** Replace GOAP + HTN with behavior trees. Source plan: `~/.claude/plans/whats-a-better-approach-snoopy-candle.md`. Net ~300 LOC reduction (~689 removed vs ~400 added). Parity with existing forest demo is the acceptance bar.
2. **Phase 2 — Debug/Perf Extraction.** Route inline `print`, perf probes, and debug draws through existing shared utilities (`U_DebugLogThrottle`, `U_PerfProbe`). `U_PerfProbe` already exists and is adopted in 7 files; Phase 2 extends coverage and enforces no bare `print()` in managers/systems.
3. **Phase 3 — Docs Split.** Break `AGENTS.md` + `DEV_PITFALLS.md` into focused, topic-scoped files. `AGENTS.md` becomes a routing index (<150 lines). Phase 3 doc creation requires per-recipe user authorization; the V8 commit is not a blanket yes.
4. **Phase 4 — Template vs Demo Split.** Reorganize `scripts/` and `resources/` into `core/` (template) and `demo/` (examples). `scripts/core/u_service_locator.gd` already exists; P4 extends `scripts/core/` in place rather than creating it. Consumers can delete `demo/` without breaking the template.
5. **Phase 5 — Base Scene.** `scenes/templates/tmpl_base_scene.tscn` already exists; P5 extends/refactors it to serve as the canonical base. Migrate real demo content onto it; delete temp/fake scenes.

---

## Current Status

- **Phase 1**: IN PROGRESS.
  - **P1.1** complete (RED/GREEN/GREEN commits landed):
    - `(RED) P1.1 add RS_BTNode base contract test`
    - `(GREEN) P1.1 add BT node/composite/decorator resources`
    - `(GREEN) P1.1 enforce BT resource size and dependency boundaries`
  - **P1.2** complete:
    - `(RED) P1.2 add RS_BTSequence contract test` (`b5962d32`)
    - `(GREEN) P1.2 implement RS_BTSequence composite` (`e07a933a`)
    - `(RED) P1.2 add RS_BTSelector contract test` (`a70032dd`)
    - `(GREEN) P1.2 implement RS_BTSelector composite` (`784aede9`)
    - `(RED) P1.2 add RS_BTUtilitySelector contract test` (`e84e2890`)
    - `(GREEN) P1.2 implement RS_BTUtilitySelector composite` (`79344746`)
  - **P1.3** complete:
    - `(RED) P1.3 add RS_BTCondition contract test` (`8c163ae0`)
    - `(GREEN) P1.3 implement RS_BTCondition leaf` (`5051a2c4`)
    - `(RED) P1.3 add RS_BTAction contract test` (`fa7fc071`)
    - `(GREEN) P1.3 implement RS_BTAction leaf` (`aa083186`)
    - `(VERIFY) P1.3 prove all 10 RS_AIAction scripts run under BT unmodified` (`7a3e936f`)
  - **P1.4** complete:
    - `(RED) P1.4 add AI scorer contract test` (`6ad6e79c`)
    - `(GREEN) P1.4 implement AI scorer resources` (`677003b4`)
    - `(GREEN) P1.4 wire BT utility selector to scorer resources` (`b5eafe91`)
  - **P1.5** complete:
    - `(RED) P1.5 add RS_BTCooldown contract test` (`488807d2`)
    - `(GREEN) P1.5 implement RS_BTCooldown decorator` (`cf80eb4f`)
    - `(RED) P1.5 add RS_BTOnce contract test` (`4069c08a`)
    - `(GREEN) P1.5 implement RS_BTOnce decorator` (`165d93c4`)
    - `(RED) P1.5 add RS_BTRisingEdge contract test` (`4ea75032`)
    - `(GREEN) P1.5 implement RS_BTRisingEdge decorator` (`5e3bdf5e`)
    - `(RED+GREEN) P1.5 add RS_BTInverter decorator` (`a2c54f7b`)
  - **P1.6** complete:
    - `(RED) P1.6 add U_BTRunner contract test` (`f46f1fa3`)
    - `(GREEN) P1.6 implement U_BTRunner` (`5967661e`)
  - **P1.6b** in progress:
    - `(RED) P1.6b add RS_WorldStateEffect contract test` (`a98fd907`)
    - `(GREEN) P1.6b implement RS_WorldStateEffect` (`08f2aaf4`)
    - `(RED) P1.6b add AI world-state builder contract test` (`0c196e7d`)
    - `(GREEN) P1.6b implement AI world-state builder` (`3dda0fd5`)
    - `(RED) P1.6b add RS_BTPlannerAction contract test` (`0128edd0`)
    - `(GREEN) P1.6b implement RS_BTPlannerAction` (`78d73d09`)
    - `(RED) P1.6b add U_BTPlannerSearch contract test` (`8b2198c6`)
    - `(GREEN) P1.6b implement U_BTPlannerSearch` (`97252380`)
    - `(RED) P1.6b add RS_BTPlanner contract test` (`0ad8c49d`)
    - `(GREEN) P1.6b implement RS_BTPlanner` (`90ce7243`)
    - `(GREEN) P1.6b tighten no-plan diagnostics + trim planner search` (`07ba856a`)
  - **Verification state**:
    - New P1.1 tests are green (`tests/unit/ai/bt/test_rs_bt_node_base.gd`).
    - New P1.2 sequence tests are green (`tests/unit/ai/bt/test_rs_bt_sequence.gd`).
    - New P1.2 selector tests are green (`tests/unit/ai/bt/test_rs_bt_selector.gd`).
    - New P1.2 utility-selector tests are green (`tests/unit/ai/bt/test_rs_bt_utility_selector.gd`).
    - New P1.3 condition tests are green (`tests/unit/ai/bt/test_rs_bt_condition.gd`).
    - New P1.3 action tests are green (`tests/unit/ai/bt/test_rs_bt_action.gd`).
    - New P1.4 scorer tests are green (`tests/unit/ai/bt/test_rs_ai_scorer.gd`).
    - New P1.5 once tests are green (`tests/unit/ai/bt/test_rs_bt_once.gd`).
    - New P1.5 rising-edge tests are green (`tests/unit/ai/bt/test_rs_bt_rising_edge.gd`).
    - New P1.5 inverter tests are green (`tests/unit/ai/bt/test_rs_bt_inverter.gd`).
    - New P1.6 runner tests are green (`tests/unit/ai/bt/test_u_bt_runner.gd`).
    - New P1.6b world-state-effect contract tests are green (`tests/unit/ai/bt/test_rs_world_state_effect.gd`).
    - New P1.6b world-state-builder contract tests are green (`tests/unit/ai/bt/test_u_ai_world_state_builder.gd`).
    - New P1.6b planner-action contract tests are green (`tests/unit/ai/bt/test_rs_bt_planner_action.gd`).
    - New P1.6b planner-search contract tests are green (`tests/unit/ai/bt/test_u_bt_planner_search.gd`).
    - New P1.6b planner contract tests are green (`tests/unit/ai/bt/test_rs_bt_planner.gd`).
    - P1.4 utility-selector scorer integration test is green (`tests/unit/ai/bt/test_rs_bt_utility_selector.gd`).
    - New BT style checks run and pass inside `tests/unit/style/test_style_enforcement.gd`.
    - Full suite is green on `cleanup-v8` (`tools/run_gut_suite.sh`: 4549 passing / 8 pending / 0 failing).
- **Phase 2**: NOT STARTED. 4 milestones.
- **Phase 3**: NOT STARTED. 3 milestones.
- **Phase 4**: NOT STARTED. 4 milestones.
- **Phase 5**: NOT STARTED. 4 milestones.

### Baseline Verification (2026-04-17, post-P1.4 completion)

- Previously listed baseline red tests now pass when run directly:
  - `tests/integration/scene_manager/test_endgame_flows.gd`
  - `tests/unit/ui/test_main_menu.gd`
  - `tests/unit/style/test_style_enforcement.gd`
- Full suite check: `tools/run_gut_suite.sh` completed with no failing tests (8 expected pending/headless skips).
- Post-P1.2 Commit 2 recheck: `tools/run_gut_suite.sh` completed with no failing tests (8 expected pending/headless skips).
- Post-P1.2 Commit 6 recheck: `tools/run_gut_suite.sh` completed with no failing tests (`4478` passing / `8` pending).
- Post-P1.3 Commit 4 recheck: `tools/run_gut_suite.sh` completed with no failing tests (`4486` passing / `8` pending).
- Post-P1.4 Commit 3 recheck: `tools/run_gut_suite.sh` completed with no failing tests (`4492` passing / `8` pending).
- Post-P1.6 Commit 2 recheck: `tools/run_gut_suite.sh` completed with no failing tests (`4518` passing / `8` pending).
- P1.6b Commit 1 RED check: `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/bt/test_rs_world_state_effect.gd` fails for expected reason (`res://scripts/resources/ai/bt/rs_world_state_effect.gd` missing).
- P1.6b Commit 1 style check: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` passes (`60/60`).
- P1.6b Commit 2 GREEN check: `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/bt/test_rs_world_state_effect.gd` passes (`4/4`).
- Post-P1.6b Commit 2 recheck: `tools/run_gut_suite.sh` completed with no failing tests (`4522` passing / `8` pending).
- P1.6b Commit 3 RED check: `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/bt/test_u_ai_world_state_builder.gd` fails for expected reason (`res://scripts/utils/ai/u_ai_world_state_builder.gd` missing).
- P1.6b Commit 3 style check: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` passes (`60/60`).
- P1.6b Commit 4 GREEN check: `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/bt/test_u_ai_world_state_builder.gd` passes (`3/3`).
- Post-P1.6b Commit 4 recheck: `tools/run_gut_suite.sh` completed with no failing tests (`4525` passing / `8` pending).
- P1.6b Commit 5 RED check: `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/bt/test_rs_bt_planner_action.gd` fails for expected reason (`res://scripts/resources/ai/bt/rs_bt_planner_action.gd` missing).
- P1.6b Commit 5 style check: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` passes (`60/60`).
- P1.6b Commit 6 GREEN check: `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/bt/test_rs_bt_planner_action.gd` passes (`6/6`).
- P1.6b Commit 6 style check: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` passes (`60/60`).
- Post-P1.6b Commit 6 recheck: `tools/run_gut_suite.sh` completed with no failing tests (`4531` passing / `8` pending).
- P1.6b Commit 7 RED check: `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/bt/test_u_bt_planner_search.gd` fails for expected reason (`res://scripts/utils/ai/u_bt_planner_search.gd` missing).
- P1.6b Commit 7 style check: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` passes (`60/60`).
- P1.6b Commit 8 GREEN check: `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/bt/test_u_bt_planner_search.gd` passes (`8/8`).
- P1.6b Commit 8 planner-action compatibility recheck: `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/bt/test_rs_bt_planner_action.gd` passes (`6/6`).
- P1.6b Commit 8 style check: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` passes (`60/60`).
- Post-P1.6b Commit 8 recheck: `tools/run_gut_suite.sh` completed with no failing tests (`4539` passing / `8` pending).
- P1.6b Commit 9 RED check landed in `0ad8c49d` (`tests/unit/ai/bt/test_rs_bt_planner.gd`).
- P1.6b Commit 10 GREEN check landed in `90ce7243` (`scripts/resources/ai/bt/rs_bt_planner.gd`).
- P1.6b follow-up GREEN fix `07ba856a`: tightened `U_BTPlannerSearch` no-plan diagnostics and reduced file size to 113 LOC.
- Current planner check: `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/bt/test_rs_bt_planner.gd` passes (`9/9`).
- Current style check: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` passes (`60/60`).
- Current full suite check: `tools/run_gut_suite.sh` completed with no failing tests (`4549` passing / `8` pending).

---

## Sequencing

```
Phase 1 ──┬── Phase 2 (independent, after P1)
          ├── Phase 3 (independent, docs-only, can run parallel to P2)
          └── Phase 4 ── Phase 5
```

- Phase 1 first and alone on its branch — large rewrite.
- Phase 2 + Phase 3 can run in parallel after P1 merges.
- Phase 4 depends on Phase 1 (the AI split is the largest classification decision).
- Phase 5 last (scene cleanup is easier after code is organized).

---

## TDD Discipline

For every milestone:

1. Write the test first (unit or integration).
2. Run the test and verify it fails for the expected reason.
3. Implement the minimum to make it pass.
4. Run the full test suite and verify no regressions.
5. Run `tests/unit/style/test_style_enforcement.gd` after any file creation, rename, or move.
6. Commit with a focused message marked `(RED)` or `(GREEN)`.

Test command: `tools/run_gut_suite.sh` (or `-gtest=res://tests/unit/ai/bt/` for targeted suites).

---

## Preserve Compatibility

- Keep `I_*` interfaces and `M_*Manager` public APIs stable across V8.
- Phase 1 is the one phase with intentional behavior changes (AI rewrite). Parity with the existing forest demo (wolf/deer/rabbit behavior, sentry/patrol_drone/guide_prism) is the acceptance bar. Manual demo check before P1.10 legacy deletion.
- Phase 4 changes paths — every `.tres`, scene, and autoload reference must move in the same commit as the file.

---

## Phase 1 — AI Rewrite Key Decisions

(From approved plan `~/.claude/plans/whats-a-better-approach-snoopy-candle.md`; paths refined by the V8 gap-patch Q&A.)

- **Architecture**: utility-scored behavior trees. Each creature = one BT `.tres` readable top-to-bottom.
- **Framework location split.** General BT framework (node/composite/decorator/sequence/selector/utility_selector + cooldown/once/rising_edge/inverter decorators) lives under `scripts/resources/bt/`. AI-specific pieces (condition + action leaves that wrap `I_Condition`/`I_AIAction`, scorers, planner) live under `scripts/resources/ai/bt/`. General runtime driver at `scripts/utils/bt/u_bt_runner.gd`. AI-specific planner search at `scripts/utils/ai/u_bt_planner_search.gd`.
- **Scoring replaces goal-selector priority arbitration.** `RS_BTUtilitySelector` picks highest-scoring viable child each tick.
- **Decorators replace goal-selector features.** Cooldown, one-shot, rising-edge become `RS_BTCooldown`, `RS_BTOnce`, `RS_BTRisingEdge` nodes wrapping subtrees.
- **Conditions reuse `I_Condition`.** No new `I_AICondition` interface. BT condition leaf wraps the existing implementations under `scripts/resources/qb/conditions/` that the goal selector already consumes via `U_RuleScorer`.
- **Actions reused unchanged.** All 10 `I_AIAction` resources and their `.tres` files carry over. `u_ai_task_state_keys.gd` is retained after P1.10 legacy deletion (used by `RS_BTAction`).
- **Context dictionary unchanged.** `S_AIBehaviorSystem`'s context construction is preserved.
- **No ABORT status.** Three values only: `RUNNING`, `SUCCESS`, `FAILURE`. Parent re-ticking replaces abort semantics.
- **State bag keyed by `node.get_instance_id()`.** Per-node running state stored on the brain component, not the node resource (resources are shared, instance state is not).
- **`push_error` stubs on base classes** (F16 pattern): `RS_BTNode.tick` virtual must be overridden or fails loud.
- **Typed arrays with coerce setters** (F7 pattern): `RS_BTComposite.children: Array[RS_BTNode]` with `_coerce_children()`.
- **QB rule infra retained.** `U_RuleScorer`/`RS_Rule`/`U_RuleSelector`/`U_RuleStateTracker`/`U_RuleValidator` under `scripts/{utils,resources}/qb/` stay as the non-AI game-logic rules framework (per P3.5 Commit 12's `conditions_effects_rules.md` recipe). Only the AI-specific consumers are deleted in P1.10.

---

## Phase 1 — Milestone Summary

| # | Milestone | Content |
|---|---|---|
| P1.1 | BT Framework Scaffolding | `RS_BTNode`, `RS_BTComposite`, `RS_BTDecorator` |
| P1.2 | Composites | Sequence, Selector, UtilitySelector |
| P1.3 | Leaves | Condition, Action |
| P1.4 | Scorers | Constant, Condition, ContextField |
| P1.5 | Decorators | Cooldown, Once, RisingEdge, Inverter |
| P1.6 | Runtime Driver | `scripts/utils/bt/u_bt_runner.gd` (general) — replaces goal selector + planner + task runner |
| P1.6b | Planning (opt-in) | `RS_BTPlanner` + `RS_BTPlannerAction` + `RS_WorldStateEffect` + `U_BTPlannerSearch` (A*). Scoped to one node; rest of BT unchanged. |
| P1.7 | Brain Component + Settings | State bag field, `root: RS_BTNode` |
| P1.8 | System Integration | `S_AIBehaviorSystem` cutover + debug panel |
| P1.9 | Content Migration | Wolf, deer, rabbit, sentry, patrol_drone, guide_prism |
| P1.10 | Legacy Deletion | Delete HTN planner, goal selector, replanner, task runner, task framework |

---

## Phases 2–5 Notes

**Phase 2 (Debug/Perf)**: Start with audit commit (`debug_perf_audit.md`) — catalog both pollution (bare `print()` sites) and the existing consolidation baseline (`U_PerfProbe`/`U_DebugLogThrottle` call sites). P2.2 is a test backfill for the existing `U_PerfProbe`, not a rewrite. Migration commits are per-file to stay reviewable. Style enforcement at the end forbids bare `print()` in managers/systems.

**Phase 3 (Docs Split)**: P3.0 reconciles ADR conventions + reshapes the `docs/` tree first. Inventory commit (P3.1), then one move commit per destination file (P3.3). `AGENTS.md` ends as a routing index (<150 lines). `DEV_PITFALLS.md` deleted when fully redistributed. **Extension recipes + decision ADRs require per-recipe user authorization** — they're authored at the tail of each owning phase, not batched in Phase 3.

**Phase 4 (Template/Demo)**: Classification doc first. `scripts/core/u_service_locator.gd` already exists — P4 extends `scripts/core/` in place. Each move commit updates imports + scene refs + `.tres` paths atomically. Final enforcement grep: `scripts/core/**` never imports from `scripts/demo/**`.

**Phase 5 (Base Scene)**: Scene inventory first. `scenes/templates/tmpl_base_scene.tscn` already exists — P5.2 extends/refactors it to match the base-scene contract (managers node tree, empty world node, camera rig, UI root layer). No new `base_scene.tscn` file is created. Migrate real demo scenes onto it. Delete temp/fake scenes last.

---

## Critical Notes

- **No Autoloads**: Follow existing pattern. Managers live under the `Managers` node and register via `U_ServiceLocator`.
- **Style & Organization**: Follow `docs/general/STYLE_GUIDE.md` and prefix conventions (`S_`, `C_`, `RS_`, `U_`, `I_`, `E_`, `M_`). New BT resources follow `RS_BT*` / `U_BT*` naming.
- **Update Docs After Each Milestone**: Mandatory. Update `cleanup-v8-tasks.md` completion notes and this continuation prompt after each milestone. Commit doc updates separately from implementation.
- **Manual forest-demo parity check** at end of P1.9 is non-negotiable before P1.10 deletes the legacy stack.
- **V7.2 is complete** (commit `e015aff2 "cleanup-v7.2 complete"` landed F10's verification test). No V7.2 prerequisite blocks V8.
- **`DEV_PITFALLS.md` / `AGENTS.md` updates** after Phase 1 and Phase 4 — entries referencing deleted/moved files become stale.
- **Phase 3 doc authorization**: Extension recipes + decision ADRs need per-commit user sign-off (per `CLAUDE.md` standing rule). The V8 plan commit is not a blanket authorization.

---

## Next Steps

1. Already on branch `cleanup-v8` (off `main`, with `GOAP-AI` merged via PR #16). No additional branch creation needed.
2. Implement **P1.6b Commit 11 (GREEN)** — wire planner debug snapshot into `C_AIBrainComponent.get_debug_snapshot()` and `debug_ai_brain_panel.gd`.
3. Implement **P1.6b Commit 12 (GREEN)** — style-enforcement follow-through for planner boundaries/LOC caps.
4. Proceed through P1.7 → P1.10 in order.
5. Merge Phase 1 to main.
6. Branch for Phase 2 (or Phase 3 in parallel).
7. Sequence through remaining phases per dependency graph.
