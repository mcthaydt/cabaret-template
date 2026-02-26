# cleanup_v6 Continuation Prompt

## Current Status

- Phase: Pre-Phase 0 (documents created, no implementation yet).
- Branch: `cleanup-v6` (1 commit ahead of main: `57783b5 fix(gdscript): resolve INCOMPATIBLE_TERNARY and SHADOWED_GLOBAL_IDENTIFIER warnings`)
- Working tree: clean.

## Context

After cleanup_v5 (filesystem hygiene + display module refactor), ~409 commits landed on main introducing two major feature systems and several smaller features:

**Major features:**
- **QB v2** — Complete rewrite of the query-based rule engine (scorer, selector, state tracker, validator, character/game/camera rule migration, composite conditions).
- **Scene Director** — Objectives manager, beat runner, beat graph with branching/fork-join, victory/completion flow, scene director manager integration, run coordinator.

**Smaller features:**
- Cinema grading (per-scene color grading post-process)
- Color blind palettes + UI filter
- Post-processing presets (resource-based)
- Global settings persistence
- Display settings UI improvements

All of this code needs to be brought up to the quality bar established by cleanups v1–v5.

## Goals

- Eliminate new `has_method()` duck typing introduced by QB v2 and Scene Director code.
- Add missing interfaces for new managers (`M_ObjectivesManager`, `M_SceneDirector`, `M_RunCoordinator`).
- Fix naming/prefix violations and class name inconsistencies.
- Remove dead code, debug cruft, and orphaned files.
- Extract duplicated helpers into shared utilities.
- Extend style enforcement tests to cover new directories.
- Fix `String(value)` → `str(value)` across display module files.
- Move misplaced files (`u_post_process_layer.gd`, `extract_touchscreen_settings.gd`).
- Create missing initial state `.tres` resources for objectives and scene director slices.
- Document undocumented STYLE_GUIDE.md gaps (`tmpl_*.tscn`, `scripts/core/`).
- Clean up stale documentation.
- Fill cinema grading test coverage gap.

## Required Readings (Do Not Skip)

- `AGENTS.md` — project conventions, testing, and update rules.
- `docs/general/DEV_PITFALLS.md` — known gotchas (imports, class cache, UI pitfalls).
- `docs/general/STYLE_GUIDE.md` — naming, formatting, prefix rules.
- `docs/general/cleanup_v6/cleanup-v6-tasks.md` — the task checklist.
- `docs/general/cleanup_v5/cleanup-v5-continuation-prompt.md` — prior cleanup patterns.

## Process for Completion (Every Phase)

1. Start with the next unchecked task list section.
2. Plan the smallest safe batch of changes; verify references before executing.
3. Execute changes → update references → run headless import if scenes/scripts moved or renamed.
4. Run relevant tests (style suite mandatory after any moves/renames).
5. Update task checklist with [x] and completion notes (commit hash, tests run, deviations).
6. Update this continuation prompt with status, tests run, and next step.
7. Update `AGENTS.md` and/or `DEV_PITFALLS.md` if new patterns or pitfalls emerged.
8. Commit with a clear message; commit documentation updates separately from implementation.

## Test / Document / Commit Checklist

- **Test**: Run the smallest relevant suite first; expand to integration/regression as needed.
- **Document**: Update task checklist + this prompt; update `AGENTS.md`/`DEV_PITFALLS.md` when required.
- **Commit**: Keep code and docs in separate commits and include the commit hash in task notes.

## Tests To Run

- Style suite (always after moves/renames):
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true`
- QB / Scene Director suites:
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/qb -ginclude_subdirs=true`
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_director -ginclude_subdirs=true`
  - `tools/run_gut_suite.sh -gdir=res://tests/integration/scene_director -ginclude_subdirs=true`
- Display suites:
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/managers -ginclude_subdirs=true`
  - `tools/run_gut_suite.sh -gdir=res://tests/integration/display -ginclude_subdirs=true`
- State suites:
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/state -ginclude_subdirs=true`

## Notes / Pitfalls

- After moving `.tscn` or `class_name` scripts, run a headless import to refresh UID/script caches:
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import`
- `RuleStateTracker` class name in `u_rule_state_tracker.gd` — confirmed: rename to `U_RuleStateTracker` and update AGENTS.md.
- `_beat_runner` in `m_scene_director.gd` is typed as `Variant` but is always `U_BeatRunner` — retyping removes 4 `has_method()` calls.
- Hardcoded game-specific IDs (`"bar_complete"`, `"final_complete"`, `"alleyway"`, `"bar"`) exist in template managers — flag for extraction but may be deferred if game-specific config system is not yet designed.
- `rs_display_initial_state.gd` has `@export_enum("bayer", "blue_noise")` but catalog uses ID `"noise"` — potential mismatch to verify.
- `scripts/debug/extract_touchscreen_settings.gd` needs `debug_` prefix to match sibling files in that directory.
- Missing initial state `.tres` for objectives and scene director slices — other slices all have wired resources in `root.tscn`, these two fall through to `== null` code path.
- `scripts/core/` exists and is tested but not listed in STYLE_GUIDE.md directory tree.
- `tmpl_*.tscn` prefix is established but not in STYLE_GUIDE.md scene naming table.
