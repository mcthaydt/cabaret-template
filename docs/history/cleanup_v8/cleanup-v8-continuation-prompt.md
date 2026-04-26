# Cross-System Cleanup V8 — Continuation Prompt

## Overview

Implements `docs/history/cleanup_v8/cleanup-v8-tasks.md` in phase order with TDD discipline. V8 is the follow-up to V7.2, addressing structural/organizational debt rather than internal architectural issues.

**Branch**: `cleanup-v8` (off `main`, after `GOAP-AI` merged via PR #16).
**Status**: Phases 1–4 complete. Phase 5 not started (deferred to last per sequencing plan). Phase 6 in progress — P6.1 next.
**Next Task**: P6.1 — `RS_BTScoredNode` + Utility Selector Update (5 commits: RED scored-node test → GREEN scored-node impl → RED utility-selector scored-node tests → GREEN utility-selector update → GREEN style enforcement).
**Prerequisite**: V7.2 complete (`e015aff2`). Phase 4 complete (`cbf0fd61` — P4.10 final assets reorganization). All 18 P3.5 extension recipes complete (including `scenes.md` + `resources.md`, shipped in `b0c5b1cd`).

---

## Scope Summary

Six phases bundled for one goal: make the template LLM-friendly, modular, and ship-ready as a reusable base.

1. **Phase 1 — AI Rewrite (utility-scored BTs).** COMPLETE. Replace GOAP + HTN with behavior trees. Net ~300 LOC reduction.
2. **Phase 2 — Debug/Perf Extraction.** COMPLETE through P2.4. No bare `print()` in managers/systems enforced.
3. **Phase 3 — Docs Split.** COMPLETE. `AGENTS.md` is a 58-line routing index. All 18 extension recipes shipped. ADR structure in place.
4. **Phase 4 — Template vs Demo Split.** COMPLETE (P4.1–P4.10). Scripts, resources, scenes, and assets all split into `core/` and `demo/`. Style suite 89/89.
5. **Phase 5 — Base Scene.** NOT STARTED. Deferred to last (easiest once code is organized).
6. **Phase 6 — LLM-First Fluent Builders.** IN PROGRESS. Replace `.tres` resource authoring with GDScript builder APIs across BT trees, scene registry, input profiles, and QB rules. Reference plan: `~/.claude/plans/stateless-tickling-meerkat.md`.

---

## Current Status

- **Phase 1**: COMPLETE (P1.1–P1.10). Full BT framework, planner, brain component refactor, all 6 creature BTs migrated, legacy GOAP/HTN deleted.
- **Phase 2**: COMPLETE through P2.4 (`28702b95`). Style recheck 83/83.
- **Phase 3**: COMPLETE. P3.0–P3.6 landed. All 18 extension recipes shipped. `AGENTS.md` is routing index. `DEV_PITFALLS.md` deleted and redistributed into pitfall topic files. ADRs at `docs/architecture/adr/`.
- **Phase 4**: COMPLETE (P4.1–P4.10, `cbf0fd61`).
  - P4.1–P4.4: Scripts split. All scripts in `scripts/core/` or `scripts/demo/`. Core-never-imports-demo enforced.
  - P4.5: Resources & scenes audit (`72272902`).
  - P4.6: ~170 core `.tres` → `resources/core/` (`2f753915`–`7c33705b`).
  - P4.7: Core scenes → `scenes/core/`, demo scenes → `scenes/demo/` (`f66a7ce7`–`ef5d8e07`).
  - P4.8: Demo audio/models/textures → `assets/demo/` (`fece8d8c`).
  - P4.9: Core-never-references-demo enforcement tests; 6 violations fixed (`a85d963b`).
  - P4.10: `prototype_grids_png` → `assets/demo/textures/`; `editor_icons` → `assets/core/`; remaining core dirs → `assets/core/` (`bfc64316`–`58e4263e`).
  - Style suite: **89/89** after P4.10.
- **Phase 5**: NOT STARTED. Deferred to last.
- **Phase 6**: NOT STARTED (P6.1 is first task).

---

## Phase 6 Milestone Summary

| # | Milestone | Content |
|---|---|---|
| P6.1 | RS_BTScoredNode + Utility Selector Update | New decorator wrapping child+scorer; utility selector detects scored nodes |
| P6.2 | BT Structural Builder (`U_BTBuilder`) | Static factory class for all BT node types; no AI imports |
| P6.3 | AI BT Factory (`U_AIBTFactory`) | AI-specific convenience factories (creatures, scorers, conditions) |
| P6.4 | Script-Backed Brain Settings (`RS_AIBrainScriptSettings`) | Brain settings that return a root built by a GDScript factory |
| P6.5 | BT Migration — `.tres` → Builder Scripts | Replace all creature BT `.tres` files with builder scripts |
| P6.6 | Scene Registry Builder (`U_SceneRegistryBuilder`) | Fluent builder for scene registry configuration |
| P6.7 | Scene Registry Migration | Replace scene registry `.tres` with builder script |
| P6.8 | Input Profile Builder (`U_InputProfileBuilder`) | Fluent builder for input profiles |
| P6.9 | Input Profile Migration | Replace input profile `.tres` files with builder scripts |
| P6.10 | QB Rule Builder (`U_QBRuleBuilder`) | Fluent builder for QB rules and conditions |
| P6.11 | QB Rule Migration | Replace QB rule `.tres` files with builder scripts |
| P6.12 | ADR + Extension Recipes | ADR for builder pattern; P6 extension recipe |

---

## P6.1 Detail — RS_BTScoredNode + Utility Selector Update

**Commit sequence:**

1. **(RED)** `tests/unit/ai/bt/test_rs_bt_scored_node.gd` — 7 test cases: script loads, extends RS_BTDecorator, has `scorer` export (defaults null), without child → FAILURE, delegates tick to child (SUCCESS/RUNNING), scorer not called during tick.
2. **(GREEN)** `scripts/core/resources/bt/rs_bt_scored_node.gd` — extends RS_BTDecorator, `@export var scorer: Resource = null`, tick() delegates to `_child` or returns FAILURE. Target ≤ 15 lines.
3. **(RED)** Add 4 tests to `test_rs_bt_utility_selector.gd`: scored-node scorer used; fallback to child_scorers for plain nodes; scored node overrides child_scorers at same index; running scored-node child is pinned.
4. **(GREEN)** Update `scripts/core/resources/bt/rs_bt_utility_selector.gd` — `_score_child()` checks `child is RS_BTScoredNode` first; add `_score_child_via_scored_node()` helper. No other changes; pinning logic unchanged.
5. **(GREEN)** Style enforcement — add `RS_BT_SCORED_NODE_MAX_LINES := 50` constant and `test_rs_bt_scored_node_stays_under_fifty_lines()` to `test_style_enforcement.gd`.

**Boundary**: `RS_BTScoredNode` lives in `scripts/core/resources/bt/` (general BT dir) with no AI-specific imports — passes `test_bt_general_resources_do_not_reference_ai_specific_types`. `RS_BTUtilitySelector` can reference `RS_BTScoredNode` (same dir, not in forbidden tokens list).

**After P6.1**: style suite 90/90; all existing BT tests green; 4 new utility-selector tests + 7 new scored-node tests green.

---

## Sequencing

```
Phase 1 ──┬── Phase 2 (independent, complete)
          ├── Phase 3 (independent, docs-only, complete)
          └── Phase 4 ── Phase 5 (not started, deferred to last)
                     └── Phase 6 (in progress: P6.1 → P6.2 → ... → P6.12)
```

---

## TDD Discipline

For every milestone:

1. Write the test first (unit or integration).
2. Run the test and verify it fails for the expected reason.
3. Implement the minimum to make it pass.
4. Run the full test suite and verify no regressions.
5. Run `tests/unit/style/test_style_enforcement.gd` after any file creation, rename, or move.
6. Commit with a focused message marked `(RED)` or `(GREEN)`.

Test command: `tools/run_gut_suite.sh` (or `-gtest=<path>` for targeted runs).

---

## Critical Notes

- **No Autoloads**: Managers live under the `Managers` node and register via `U_ServiceLocator`.
- **Style & Organization**: Follow `docs/guides/STYLE_GUIDE.md` and prefix conventions. New BT resources follow `RS_BT*` / `U_BT*` naming.
- **Update Docs After Each Milestone**: Update `cleanup-v8-tasks.md` completion notes and this continuation prompt after each milestone. Commit doc updates separately from implementation.
- **Phase 3 doc authorization**: Extension recipes + decision ADRs need per-commit user sign-off.
- **Phase 5 is last**: Base scene cleanup is easiest once all code is organized. Do not start until Phase 6 is complete or user explicitly requests it.
- **Phase 6 migration is destructive**: Each `.tres` deletion commit is atomic and revertable. Run full suite + visual parity check before deleting.
- **Core/demo boundary in Phase 6**: BT structural builder (`U_BTBuilder`) lives in `scripts/core/utils/bt/` (no AI imports). AI-specific factories (`U_AIBTFactory`) live in `scripts/core/utils/ai/`.

---

## Next Steps

1. **P6.1 Commit 1 (RED)** — Write `tests/unit/ai/bt/test_rs_bt_scored_node.gd`, verify it fails for expected missing-script reason.
2. **P6.1 Commit 2 (GREEN)** — Implement `scripts/core/resources/bt/rs_bt_scored_node.gd`.
3. **P6.1 Commit 3 (RED)** — Add 4 scored-node tests to `test_rs_bt_utility_selector.gd`.
4. **P6.1 Commit 4 (GREEN)** — Update `rs_bt_utility_selector.gd` with scored-node scoring path.
5. **P6.1 Commit 5 (GREEN)** — Add 50-line style guard for `rs_bt_scored_node.gd` in style enforcement.
6. After P6.1: proceed to P6.2 — `U_BTBuilder` static factory class.
7. Keep docs/history references archived; new evergreen guidance belongs under `docs/guides/` or `docs/systems/`.
