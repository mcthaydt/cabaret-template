# cleanup_v6 Continuation Prompt

## Current Status

- Phase: Phase 3A complete (`RuleStateTracker` → `U_RuleStateTracker`); next: Phase 3B manager suffix renames.
- Branch: `cleanup-v6` (9 commits ahead of main; Phase 3A docs update pending commit).
- Working tree: implementation committed (`85c50057`), docs currently modified for Phase 3A status updates.

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

## Baseline Results (2026-02-26)

- Style baseline (`tests/unit/style`): 11/12 passed; 1 failure in `test_production_paths_have_no_spaces` from orphan `* 2.gd.uid` files (tracked in Phase 1A task list).
- QB baseline (`tests/unit/qb`): 151/151 passed.
- Scene Director baseline:
  - Unit (`tests/unit/scene_director`): 97/97 passed.
  - Integration (`tests/integration/scene_director`): 4/4 passed.
- Display baseline:
  - Unit managers (`tests/unit/managers`): 378/378 passed.
  - Integration (`tests/integration/display`): 40/41 passed with 1 pending (`UIOverlayStack` unavailable in test environment), no failures.
- Known non-failing environment warning: `get_system_ca_certificates` appears at suite startup on macOS.

## Phase 1 Results (2026-02-26)

- Removed all 11 orphaned `* 2.gd.uid` files from the working tree.
- Moved `u_post_process_layer.gd` to `scripts/managers/helpers/display/` and updated preload references.
- Renamed debug helper to `scripts/debug/debug_extract_touchscreen_settings.gd`.
- Implementation commit: `bf3df98` (`refactor(cleanup-v6): move misplaced helper and debug scripts`).
- Validation:
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import` (pass; non-failing ObjectDB leak warning at exit)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` (12/12 passed)

## Phase 2A Results (2026-02-26)

- Typed Scene Director runner state:
  - `m_scene_director.gd`: `_beat_runner` is now `U_BeatRunner` (removed runner `has_method(...)` checks).
  - `u_beat_runner.gd`: `_parallel_runners` is now `Array[U_BeatRunner]` (removed runner `has_method(...)` checks in signal/parallel update paths).
- Remaining `has_method(...)` calls are intentional polymorphism guards for condition/effect resources (`evaluate`/`execute`) on `Array[Resource]` contracts.
- Implementation commit: `c6f2085` (`refactor(scene-director): remove runner duck typing guards`).
- Validation:
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_director -ginclude_subdirs=true` (97/97 passed)
  - `tools/run_gut_suite.sh -gdir=res://tests/integration/scene_director -ginclude_subdirs=true` (4/4 passed)

## Phase 2B Results (2026-02-26)

- Added interfaces:
  - `scripts/interfaces/i_objectives_manager.gd`
  - `scripts/interfaces/i_scene_director.gd`
  - `scripts/interfaces/i_run_coordinator.gd`
- Updated managers to extend interfaces (`M_ObjectivesManager`, `M_SceneDirector`, `M_RunCoordinator`).
- Removed `has_method("reset_for_new_run")` guard from `M_RunCoordinator` and switched to typed `I_ObjectivesManager` lookup before invoking `reset_for_new_run(...)`.
- Updated run coordinator unit-test stub to implement `I_ObjectivesManager`.
- Implementation commit: `13c65f2` (`refactor(scene-director): add manager interfaces and typed objectives lookup`).
- Validation:
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import` (pass; required after adding interface `class_name` scripts)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` (12/12 passed)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_director -ginclude_subdirs=true` (97/97 passed)
  - `tools/run_gut_suite.sh -gdir=res://tests/integration/scene_director -ginclude_subdirs=true` (4/4 passed)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/qb -ginclude_subdirs=true` (151/151 passed)

## Phase 3A Results (2026-02-26)

- Renamed `class_name RuleStateTracker` → `U_RuleStateTracker` in `scripts/utils/qb/u_rule_state_tracker.gd`.
- Updated all three consumers: `s_camera_state_system.gd`, `s_character_state_system.gd`, `s_game_event_system.gd`.
- Updated two stale AGENTS.md references (QB v2 patterns section).
- Implementation commit: `85c50057` (`refactor(qb): rename RuleStateTracker class to U_RuleStateTracker`).
- No headless import required (no file moves or new `class_name` scripts added, only class_name value changed).

## Notes / Pitfalls

- After moving `.tscn` or `class_name` scripts, run a headless import to refresh UID/script caches:
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import`
- `RuleStateTracker` class name in `u_rule_state_tracker.gd` — confirmed: rename to `U_RuleStateTracker` and update AGENTS.md.
- Hardcoded game-specific IDs (`"bar_complete"`, `"final_complete"`, `"alleyway"`, `"bar"`) exist in template managers — flag for extraction but may be deferred if game-specific config system is not yet designed.
- `rs_display_initial_state.gd` has `@export_enum("bayer", "blue_noise")` but catalog uses ID `"noise"` — potential mismatch to verify.
- Missing initial state `.tres` for objectives and scene director slices — other slices all have wired resources in `root.tscn`, these two fall through to `== null` code path.
- `scripts/core/` exists and is tested but not listed in STYLE_GUIDE.md directory tree.
- `tmpl_*.tscn` prefix is established but not in STYLE_GUIDE.md scene naming table.
