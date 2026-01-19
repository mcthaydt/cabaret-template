# Groups Cleanup Continuation Prompt

Use this prompt to resume the groups cleanup effort (cleanup_v3).

---

## Context

- Goal: remove `add_to_group()` / `is_in_group()` / `get_nodes_in_group()` usage in favor of ServiceLocator, explicit registration helpers, and typed references.
- Fallback chain already exists (exports → ServiceLocator → group); migration will remove the final group tier after consumers/tests move to ServiceLocator.
- Camera/HUD/mobile controls/effects containers will gain explicit registration APIs in their managers as part of this work.

---

## Read First

- `docs/general/DEV_PITFALLS.md`
- `docs/general/STYLE_GUIDE.md`
- `docs/general/cleanup_v3/groups-cleanup-tasks.md`

---

## Current Progress

- Phase 0 marked complete in tasks doc (centralized registrations decided; audio manager added to `main.gd`; fallbacks kept).
- Baseline full-suite run from Phase 0 checklist is still unchecked (see tasks doc).
- Phase 1 complete: added main camera registration helpers to `M_CameraManager`, `_find_camera_in_scene()` now honors the registered camera before falling back to group search, and camera unit/integration suites are green.

---

## Execution Rules

- Run the targeted tests listed per phase in `groups-cleanup-tasks.md` (and full suite when specified) **before** advancing.
- After every phase, update:
  - `docs/general/cleanup_v3/groups-cleanup-tasks.md` (checkboxes/notes)
  - This continuation prompt (progress + next steps)
- Commit documentation updates separately from implementation commits.

---

## Next Step

- Phase 2: migrate camera tests off `add_to_group("main_camera")` to `register_main_camera()` and keep camera suites green.
- Verify via camera suites:
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/camera_system -gdir=res://tests/integration/camera_system -gexit`
