# Cross-System Cleanup V8 — Continuation Prompt

## Overview

Implements `docs/history/cleanup_v8/cleanup-v8-tasks.md` in phase order with TDD discipline. V8 is the follow-up to V7.2, addressing structural/organizational debt rather than internal architectural issues.

**Branch**: `cleanup-v8` (off `main`, after `GOAP-AI` merged via PR #16).
**Status**: Phases 1–4 complete. Phase 5 not started (deferred to last per sequencing plan). Phase 6 **COMPLETE** (P6.1–P6.13). Phase 7 **COMPLETE** (P7.1–P7.8). Phase 8 **COMPLETE** (P8.1–P8.12).
**Next Task**: Phase 5 — Builder-backed base scene + 2.5D demo entry cleanup.
**Prerequisite**: V7.2 complete (`e015aff2`). Phase 4 complete (`cbf0fd61`). All 18 P3.5 extension recipes complete (`b0c5b1cd`).

---

## Scope Summary

Seven phases bundled for one goal: make the template LLM-friendly, modular, and ship-ready as a reusable base.

1. **Phase 1 — AI Rewrite (utility-scored BTs).** COMPLETE. Replace GOAP + HTN with behavior trees. Net ~300 LOC reduction.
2. **Phase 2 — Debug/Perf Extraction.** COMPLETE through P2.4. No bare `print()` in managers/systems enforced.
3. **Phase 3 — Docs Split.** COMPLETE. `AGENTS.md` is a 58-line routing index. All 18 extension recipes shipped. ADR structure in place.
4. **Phase 4 — Template vs Demo Split.** COMPLETE (P4.1–P4.10). Scripts, resources, scenes, and assets all split into `core/` and `demo/`. Style suite 89/89.
5. **Phase 5 — Base Scene.** NOT STARTED. Deferred to last (easiest once code is organized).
6. **Phase 6 — LLM-First Fluent Builders.** COMPLETE (P6.1–P6.13). Replace `.tres` resource authoring with GDScript builder APIs across BT trees, scene registry, input profiles, and QB rules. P6.13 gap-patch backfill removal + constant migrations (`64210f85`–`279fcc33`). Reference plan: `~/.claude/plans/stateless-tickling-meerkat.md`.
7. **Phase 7 — EditorScript + PackedScene Builders.** COMPLETE (P7.1–P7.8). Hand-authored `.tscn` creation replaced with programmatic GDScript builder APIs (`U_EditorPrefabBuilder`, `U_EditorBlockoutBuilder`, `U_EditorShapeFactory`). 21 builder scripts under `scripts/demo/editors/`. ADR-0012 (Editor Builder Pattern). Style suite 94/94. Reference plan: `~/.claude/plans/lets-add-a-new-humming-kay.md`.
8. **Phase 8 — LLM-First UI Menu Builders.** COMPLETE (P8.1–P8.12). Display integration tests fixed (3 failures → 17/17 passing), localization unit + builder tests fixed (7 failures → 25/25 passing), VFX overlay duplicate theming removed (38/38 passing), 13-script builder migration deferred (builder already wired; inline overrides supplemental), and TSCN cleanup verified (only structural nodes remain in the 3 simplified tabs).

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
- **Phase 6**: COMPLETE (P6.1–P6.13). P6.1 complete (`10310f00`–`ec14181a`). P6.2 complete (`a4c41434`–`a23270b1`). P6.3 complete (`d0c1224a`–`0cd59475`). P6.4 complete (`4a1218f1`–`c6608c79`). P6.5 complete (`6e9e7b6a`–`e28d0c30`, gap-patched `5a176f9a`–`b29e3618`). P6.6 complete (`f3806172`–`fb576449`). P6.7 complete (`a33d1153`–`0b69200f`). P6.8 complete (`4d680390`–`deac3004`). P6.9 complete (`df1deff5`–`cfdd907a`, loader tests `a16b0783`). P6.10 complete (`eb7f37c0`–`20e28d54`). P6.11 complete (`7dc8a7aa`–`8a21f645`). P6.12 complete (`1148e2f5`): ADR 0011 Builder Pattern Taxonomy + builders.md extension recipe + style enforcement update. P6.13 complete (`64210f85`–`279fcc33`): backfill removal, `RS_ConditionComposite.CompositeMode` constants, `RS_EffectSetField.OP_SET/OP_ADD` constants, `TRIGGER`/`OP`/`MATCH` constant swaps in rules + AI behaviors.
- **Phase 7**: COMPLETE (P7.1–P7.8). P7.1 complete (`1cc1e11c`, `a309ff3a`) — builder root creation + fluent API. P7.2 complete (`2bf624ba`) — ECS component wiring. P7.3 complete (`761d5a0d`) — visuals, collision & children. P7.4 complete (`fe595fc6`) — save & EditorScript adapter. P7.5 complete (`9a792b43`) — blockout builder core CSG API. P7.6 complete (`6c340624`) — blockout builder materials, environment & save. P7.7 complete (`b3e81551`–`0be92548`) — all 21 prefab builder scripts. P7.8 complete (`e26cc256`, `5c7f1fce`, `3bb5a0fa`) — `U_EditorShapeFactory` extraction (251→193 LOC), 7 additional builder scripts, ADR-0012, style suite 94/94.
- **Phase 8**: COMPLETE (P8.1–P8.12). Verification snapshot (2026-04-29): style enforcement 98/98 passing; full suite 4859/4860 passing with 1 pre-existing flaky save manager test unrelated to UI migration.

---
