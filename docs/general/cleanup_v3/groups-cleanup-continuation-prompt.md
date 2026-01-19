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
- Phase 1 complete: added main camera registration helpers to `M_CameraManager`, `_find_camera_in_scene()` honors the registered camera, and camera unit/integration suites are green.
- Phase 2 complete: migrated camera-related tests off `add_to_group("main_camera")`, added ServiceLocator fallback in `U_ECSUtils.get_active_camera()`, cleared ServiceLocator in camera suites, and switched `i_scene_contract.gd` to type-based camera validation. Camera unit/integration suites are green.
- Phase 3 complete: Scene manager and spawn manager now rely on camera manager main-camera APIs (no `main_camera` group lookups), `tmpl_camera` no longer declares the group tag, and scene manager integration suites pass (warnings only for intentionally missing managers/overlays in tests).
- Phase 4 complete: Manager-centric tests now register via ServiceLocator (state_store, input_profile_manager, scene_manager, spawn_manager, save_manager). MockSaveManager only registers when unregistered to avoid duplicate warnings. UI suite is green plus gameplay/spawn integration suites validated.

---

## Execution Rules

- Run the targeted tests listed per phase in `groups-cleanup-tasks.md` (and full suite when specified) **before** advancing.
- After every phase, update:
  - `docs/general/cleanup_v3/groups-cleanup-tasks.md` (checkboxes/notes)
  - This continuation prompt (progress + next steps)
- Commit documentation updates separately from implementation commits.

---

## Next Step

- Phase 5: migrate production manager code off group lookups (`u_scene_manager_node_finder.gd`, `ui_input_rebinding_overlay.gd`, `ui_button_prompt.gd`) to ServiceLocator/typed checks, then run full suite.
- Targeted tests:
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit`
