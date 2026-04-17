# Cross-System Cleanup V8 — Continuation Prompt

## Overview

Implements `docs/general/cleanup_v8/cleanup-v8-tasks.md` in phase order with TDD discipline. V8 is the follow-up to V7.2, addressing structural/organizational debt rather than internal architectural issues.

**Branch**: `cleanup-v8-p1-ai-bt` recommended for Phase 1 (isolate large diff). Subsequent phases can branch from `main` after Phase 1 merges.
**Status**: Not started.
**Next Task**: Phase 1, Milestone P1.1 (BT framework scaffolding).
**Prerequisite**: V7.2 F10 verification checkpoint can land whenever; does not block V8.

---

## Scope Summary

Five independent phases bundled for a single goal: make the template LLM-friendly, modular, and ship-ready as a reusable base.

1. **Phase 1 — AI Rewrite (utility-scored BTs).** Replace GOAP + HTN with behavior trees. Plan: `~/.claude/plans/whats-a-better-approach-snoopy-candle.md`. ~500 LOC net reduction. Parity with existing forest demo is the acceptance bar.
2. **Phase 2 — Debug/Perf Extraction.** Move inline `print`, perf probes, and debug draws out of managers/systems into shared utilities (`U_DebugLogThrottle`, `U_PerfProbe`).
3. **Phase 3 — Docs Split.** Break `AGENTS.md` + `DEV_PITFALLS.md` into focused, topic-scoped files. `AGENTS.md` becomes a routing index (<150 lines).
4. **Phase 4 — Template vs Demo Split.** Reorganize `scripts/` and `resources/` into `core/` (template) and `demo/` (examples). Consumers can delete `demo/` without breaking the template.
5. **Phase 5 — Base Scene.** Define one canonical base scene, migrate real demo content onto it, delete temp/fake scenes.

---

## Current Status

- **Phase 1**: NOT STARTED. 10 milestones (P1.1–P1.10).
- **Phase 2**: NOT STARTED. 4 milestones.
- **Phase 3**: NOT STARTED. 3 milestones.
- **Phase 4**: NOT STARTED. 4 milestones.
- **Phase 5**: NOT STARTED. 4 milestones.

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

(From approved plan `~/.claude/plans/whats-a-better-approach-snoopy-candle.md`.)

- **Architecture**: utility-scored behavior trees. Each creature = one BT `.tres` readable top-to-bottom.
- **Scoring replaces goal-selector priority arbitration.** `RS_BTUtilitySelector` picks highest-scoring viable child each tick.
- **Decorators replace goal-selector features.** Cooldown, one-shot, rising-edge become `RS_BTCooldown`, `RS_BTOnce`, `RS_BTRisingEdge` nodes wrapping subtrees.
- **Actions reused unchanged.** All 10 `I_AIAction` resources and their `.tres` files carry over.
- **Context dictionary unchanged.** `S_AIBehaviorSystem`'s context construction is preserved.
- **No ABORT status.** Three values only: `RUNNING`, `SUCCESS`, `FAILURE`. Parent re-ticking replaces abort semantics.
- **State bag keyed by `node.get_instance_id()`.** Per-node running state stored on the brain component, not the node resource (resources are shared, instance state is not).
- **`push_error` stubs on base classes** (F16 pattern): `RS_BTNode.tick` virtual must be overridden or fails loud.
- **Typed arrays with coerce setters** (F7 pattern): `RS_BTComposite.children: Array[RS_BTNode]` with `_coerce_children()`.

---

## Phase 1 — Milestone Summary

| # | Milestone | Content |
|---|---|---|
| P1.1 | BT Framework Scaffolding | `RS_BTNode`, `RS_BTComposite`, `RS_BTDecorator` |
| P1.2 | Composites | Sequence, Selector, UtilitySelector |
| P1.3 | Leaves | Condition, Action |
| P1.4 | Scorers | Constant, Condition, ContextField |
| P1.5 | Decorators | Cooldown, Once, RisingEdge, Inverter |
| P1.6 | Runtime Driver | `U_BTRunner` — replaces goal selector + planner + task runner |
| P1.6b | Planning (opt-in) | `RS_BTPlanner` + `RS_BTPlannerAction` + `RS_WorldStateEffect` + `U_BTPlannerSearch` (A*). Scoped to one node; rest of BT unchanged. |
| P1.7 | Brain Component + Settings | State bag field, `root: RS_BTNode` |
| P1.8 | System Integration | `S_AIBehaviorSystem` cutover + debug panel |
| P1.9 | Content Migration | Wolf, deer, rabbit, sentry, patrol_drone, guide_prism |
| P1.10 | Legacy Deletion | Delete HTN planner, goal selector, replanner, task runner, task framework |

---

## Phases 2–5 Notes

**Phase 2 (Debug/Perf)**: Start with audit commit (`debug_perf_audit.md`). Migration commits are per-file to stay reviewable. Style enforcement at the end forbids bare `print()` in managers/systems.

**Phase 3 (Docs Split)**: Inventory commit first, then one move commit per destination file. `AGENTS.md` ends as a routing index. `DEV_PITFALLS.md` deleted when fully redistributed.

**Phase 4 (Template/Demo)**: Classification doc first. Each move commit updates imports + scene refs + `.tres` paths atomically. Final enforcement grep: `scripts/core/**` never imports from `scripts/demo/**`.

**Phase 5 (Base Scene)**: Scene inventory first. Build `scenes/templates/base_scene.tscn` with minimum infrastructure. Migrate real demo scenes onto it. Delete temp/fake scenes last.

---

## Critical Notes

- **No Autoloads**: Follow existing pattern. Managers live under the `Managers` node and register via `U_ServiceLocator`.
- **Style & Organization**: Follow `docs/general/STYLE_GUIDE.md` and prefix conventions (`S_`, `C_`, `RS_`, `U_`, `I_`, `E_`, `M_`). New BT resources follow `RS_BT*` / `U_BT*` naming.
- **Update Docs After Each Milestone**: Mandatory. Update `cleanup-v8-tasks.md` completion notes and this continuation prompt after each milestone. Commit doc updates separately from implementation.
- **Manual forest-demo parity check** at end of P1.9 is non-negotiable before P1.10 deletes the legacy stack.
- **V7.2 F10 is unblocked** and can land independently of V8.
- **`MEMORY.md` updates** after Phase 1 and Phase 4 — entries referencing deleted/moved files become stale.

---

## Next Steps

1. Create branch `cleanup-v8-p1-ai-bt` off current `GOAP-AI`.
2. Begin **P1.1 Commit 1 (RED)** — write `test_rs_bt_node_base.gd`.
3. Proceed through P1.1 → P1.10 in order.
4. Merge Phase 1 to main.
5. Branch for Phase 2 (or Phase 3 in parallel).
6. Sequence through remaining phases per dependency graph.
