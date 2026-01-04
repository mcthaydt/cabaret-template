# Cleanup V2 Tasks (Architecture + Organization)

**Scope:** Reduce maintenance risk (large orchestrators, weak type validation), tighten style/org enforcement, and clean minor naming/structure inconsistencies.  
**Non-goals:** New gameplay features, redesigning ECS/Redux/Scene Manager architecture, or changing user-facing behavior (unless explicitly called out).

**Test Philosophy:** TDD for every behavior/contract change (Red → Green → Refactor). Pure refactors still require “no behavior change” verification via existing suites.

**Always Run (when touching scripts/scenes/resources):**
- Style/scene org: `tools/run_gut_suite.sh -gdir=res://tests/unit/style`
- Targeted unit tests for the area you touched (then broader suite if needed).

---

## Decisions Locked (So This Plan Is Executable Later)

These are intentionally explicit so the work can proceed without ambiguity:

1. **Action validation:** Do **not** rewrite existing action shapes to “payload-only”. Instead, extend `U_ActionRegistry` to support validating **root action keys** (needed for `U_NavigationActions`, which stores fields at the root).
2. **Input sources naming:** Keep current source filenames under `scripts/input/sources/` and enforce via a **suffix rule**: `*_source.gd`.
3. **UI overlay foldering:** Remove the one-off `scenes/ui/settings/` folder by moving `ui_vfx_settings_overlay.tscn` into `scenes/ui/`.

---

## Phase 0: Setup & Baseline (Docs + Current State)

**Exit Criteria:** Docs exist, baseline test runs recorded, and scope decisions captured.

- [x] **Task 0.1**: Create this tasks document
- [x] **Task 0.2**: Create continuation prompt (`docs/general/cleanup_v2/cleanup-v2-continuation-prompt.md`)
- [x] **Task 0.3**: Baseline test run + record results in this doc
  - Run: `tools/run_gut_suite.sh -gdir=res://tests/unit/style`
  - Run: `tools/run_gut_suite.sh -gdir=res://tests/unit`
  - Record pass/fail + notable warnings in “Notes / Baseline Results” below
- [x] **Task 0.4**: Baseline “hotspot” inventory (no code changes)
  - Capture current largest scripts list (top 15) and paste results into this doc:
    - `rg --files scripts --glob '*.gd' | rg -v '\\.uid$' | xargs wc -l | sort -nr | head -n 20`
    - Results (2026-01-04):
      ```text
         31373 total
          1039 scripts/managers/m_scene_manager.gd
           633 scripts/managers/m_save_manager.gd
           604 scripts/managers/m_ecs_manager.gd
           555 scripts/state/m_state_store.gd
           521 scripts/ui/ui_save_load_menu.gd
           506 scripts/state/reducers/u_input_reducer.gd
           467 scripts/ui/ui_input_profile_selector.gd
           449 scripts/ui/ui_input_rebinding_overlay.gd
           435 scripts/managers/m_input_profile_manager.gd
           428 scripts/ui/helpers/u_rebind_action_list_builder.gd
           398 scripts/ui/ui_touchscreen_settings_overlay.gd
           394 scripts/ecs/components/c_scene_trigger_component.gd
           385 scripts/managers/m_camera_manager.gd
           380 scripts/ui/ui_mobile_controls.gd
           375 scripts/scene_management/transitions/trans_loading_screen.gd
           356 scripts/managers/m_input_device_manager.gd
           350 scripts/ui/u_button_prompt_registry.gd
           350 scripts/state/reducers/u_navigation_reducer.gd
           346 scripts/state/reducers/u_gameplay_reducer.gd
      ```
  - Confirm any UX TODOs and paste file:line hits:
    - `rg -n \"TODO:\" scripts/ui | head -n 50`
    - Results (2026-01-04):
      ```text
      scripts/ui/ui_save_load_menu.gd:399:		# TODO: Show error toast or inline message
      scripts/ui/ui_save_load_menu.gd:420:		# TODO: Show error toast in gameplay (overlay already closed)
      scripts/ui/ui_save_load_menu.gd:431:		# TODO: Show error toast or inline message
      scripts/ui/ui_main_menu.gd:181:	# TODO: Add confirmation dialog if saves exist
      ```
  - Confirm whether the placeholder scene is referenced anywhere:
    - `rg -n \"tmp_invalid_gameplay\" -S .`
    - Results (2026-01-04):
      ```text
      ./tests/integration/scene_manager/test_scene_contract_invocation.gd:77:    if U_SceneRegistry._scenes.has(StringName("tmp_invalid_gameplay")):
      ./tests/integration/scene_manager/test_scene_contract_invocation.gd:78:        U_SceneRegistry._scenes.erase(StringName("tmp_invalid_gameplay"))
      ./tests/integration/scene_manager/test_scene_contract_invocation.gd:86:        StringName("tmp_invalid_gameplay"),
      ./tests/integration/scene_manager/test_scene_contract_invocation.gd:87:        "res://scenes/tmp_invalid_gameplay.tscn",
      ./tests/integration/scene_manager/test_scene_contract_invocation.gd:94:    _manager.transition_to_scene(StringName("tmp_invalid_gameplay"), "instant")
      ./tests/integration/scene_manager/test_scene_contract_invocation.gd:99:    assert_eq(scene_state.get("current_scene_id", StringName(\"\")), StringName(\"tmp_invalid_gameplay\"))
      ./tests/unit/scene_manager/test_scene_registry_resources.gd:28:    entry.scene_path = "res://scenes/tmp_invalid_gameplay.tscn"  # existing test scene path
      ./tests/unit/scene_manager/test_scene_registry_resources.gd:46:    entry.scene_path = "res://scenes/tmp_invalid_gameplay.tscn"
      ./docs/general/cleanup_v1/style-scene-cleanup-tasks.md:549:- [SKIP] T059 Delete orphaned temporary file `scenes/tmp_invalid_gameplay.tscn`:
      ./docs/general/cleanup_v2/cleanup-v2-tasks.md:40:    - `rg -n \"tmp_invalid_gameplay\" -S .`
      ./docs/general/cleanup_v2/cleanup-v2-tasks.md:216:  - Candidate: `scenes/tmp_invalid_gameplay.tscn`
      ./docs/general/cleanup_v2/cleanup-v2-tasks.md:218:    - `rg -n \"tmp_invalid_gameplay\" -S .`
      ```

---

## Phase 1: Enforcement Tightening (Prevent Drift)

**Exit Criteria:** Style enforcement covers all production script dirs and scene naming checks recurse into subfolders.

- [x] **Task 1.1 (Red)**: Expand indentation scanning to missing script dirs
  - File: `tests/unit/style/test_style_enforcement.gd`
  - Add to `GD_DIRECTORIES`:
    - `res://scripts/core`
    - `res://scripts/interfaces`
    - `res://scripts/utils`
    - `res://scripts/input`
    - `res://scripts/scene_management`
    - `res://scripts/events`
  - Expected: style suite may fail until prefix/suffix rules are updated (Tasks 1.2–1.4).

- [x] **Task 1.2 (Red)**: Expand prefix rules for newly-covered dirs
  - File: `tests/unit/style/test_style_enforcement.gd`
  - Add to `SCRIPT_PREFIX_RULES`:
    - `res://scripts/core`: `["u_"]`
    - `res://scripts/interfaces`: `["i_"]`
    - `res://scripts/utils`: `["u_"]`
    - `res://scripts/input`: `["u_", "i_"]`
    - `res://scripts/input/sources`: **do not** validate by prefix (validated by suffix in Task 1.3)
  - Add to `SCRIPT_FILENAME_EXCEPTIONS` only if truly necessary (keep exception list small).

- [x] **Task 1.3 (Green)**: Enforce input source filenames by suffix rule
  - Files:
    - `tests/unit/style/test_style_enforcement.gd`
    - `docs/general/STYLE_GUIDE.md`
  - Implement in the style test:
    - For `res://scripts/input/sources/`, require filename ends with `_source.gd`
  - Document in style guide:
    - **Input Sources** (new category)
    - Location: `scripts/input/sources/`
    - File pattern: `*_source.gd`
    - Class pattern (informational): `*Source`

- [x] **Task 1.4 (Green)**: Make scene naming checks recurse into subdirectories
  - File: `tests/unit/style/test_style_enforcement.gd`
  - Update `_check_scene_directory(...)` to recurse so `scenes/ui/settings/` is validated.
  - Confirm `scenes/ui/**` (including subfolders) still enforces `ui_` prefix for `.tscn`.

- [x] **Task 1.5 (Green)**: Style suite is green with the new enforcement
  - Run: `tools/run_gut_suite.sh -gdir=res://tests/unit/style`
  - If the suite forces a legitimate exception, document it in `docs/general/STYLE_GUIDE.md` and encode it explicitly in the test.

---

## Phase 2: Action Payload Schemas (Type/Shape Safety)

**Exit Criteria:** Malformed “high-risk” actions are rejected early (before reducers) and tests cover both payload and root-field schema rules.

### Schema rules (explicit)
- `required_fields`: required keys inside `action.payload` when payload is a `Dictionary`
- `required_root_fields`: required keys at the root of the action dictionary
- For required keys:
  - Key must exist
  - If value is `StringName` or `String`, it must not be empty

- [x] **Task 2.1 (Red)**: Add ActionRegistry tests for `required_root_fields`
  - File: `tests/unit/state/test_action_registry.gd`
  - Add tests:
    - missing required root field → `validate_action()` returns false + `push_error`
    - empty `StringName` required root field → `validate_action()` returns false + `push_error`
    - present required root field → passes

- [x] **Task 2.2 (Green)**: Implement `required_root_fields` support
  - File: `scripts/state/utils/u_action_registry.gd`
  - Preserve existing schema behavior (`required_fields` continues to validate payload dicts).

- [x] **Task 2.3 (Red)**: Add store-level test for schema failure propagation
  - File: `tests/unit/state/test_m_state_store.gd`
  - Add a test that dispatching an action failing schema:
    - emits `validation_failed` with a stable message
    - does not emit `action_dispatched`

- [x] **Task 2.4 (Green)**: Apply schemas to the “high-risk” action set (no action-shape changes)
  - Files:
    - `scripts/state/actions/u_scene_actions.gd`
    - `scripts/state/actions/u_navigation_actions.gd`
    - `scripts/state/actions/u_input_actions.gd`
  - Schema mapping to implement:
    - Scene actions (payload dict)
      - `scene/transition_started`: `required_fields = ["target_scene_id", "transition_type"]`
      - `scene/transition_completed`: `required_fields = ["scene_id"]`
      - `scene/push_overlay`: `required_fields = ["scene_id"]`
    - Navigation actions (root fields)
      - `navigation/set_shell`: `required_root_fields = ["shell", "base_scene_id"]`
      - `navigation/open_overlay`: `required_root_fields = ["screen_id"]`
      - `navigation/set_menu_panel`: `required_root_fields = ["panel_id"]`
      - `navigation/navigate_to_ui_screen`: `required_root_fields = ["scene_id"]`
      - `navigation/set_save_load_mode`: `required_root_fields = ["mode"]`
    - Input actions (payload dict)
      - `input/update_move_input`: `required_fields = ["move_vector"]`
      - `input/update_look_input`: `required_fields = ["look_delta"]`
      - `input/update_jump_state`: `required_fields = ["pressed", "just_pressed"]`
      - `input/update_sprint_state`: `required_fields = ["pressed"]`
      - `input/device_changed`: `required_fields = ["device_type", "device_id", "timestamp"]`
      - `input/gamepad_connected`: `required_fields = ["device_id"]`
      - `input/gamepad_disconnected`: `required_fields = ["device_id"]`
      - `input/profile_switched`: `required_fields = ["profile_id"]`
      - `input/rebind_action`: `required_fields = ["action", "mode"]`
      - `input/update_gamepad_deadzone`: `required_fields = ["stick", "deadzone"]`
      - `input/toggle_vibration`: `required_fields = ["enabled"]`
      - `input/set_vibration_intensity`: `required_fields = ["intensity"]`
      - `input/update_mouse_sensitivity`: `required_fields = ["sensitivity"]`
      - `input/update_accessibility`: `required_fields = ["field", "value"]`
      - `input/remove_action_bindings`: `required_fields = ["action"]`
      - `input/remove_event_from_action`: `required_fields = ["action", "event"]`
      - `input/update_touchscreen_settings`: `required_fields = ["settings"]`
      - `input/save_virtual_control_position`: `required_fields = ["control_name", "position"]`

- [x] **Task 2.5 (Green)**: Verify state + style suites
  - Run: `tools/run_gut_suite.sh -gdir=res://tests/unit/state`
  - Run: `tools/run_gut_suite.sh -gdir=res://tests/unit/style`

---

## Phase 3: “Big Orchestrator” Decomposition (Reduce Change Risk)

**Exit Criteria:** No behavior changes (tests remain green), and duplicated responsibilities are removed from orchestrator files.

### 3A) Scene Manager (`scripts/managers/m_scene_manager.gd`)
- [x] **Task 3.1 (Baseline)**: Record current size + duplicated seams
  - Record line count: `scripts/managers/m_scene_manager.gd`
    - 1039 lines (2026-01-04)
  - Confirm which of these remain implemented inside the manager and can be removed:
    - caching + background preload (helper: `scripts/scene_management/helpers/u_scene_cache.gd`)
      - Still has manager wrapper methods: `_is_scene_cached`, `_get_cached_scene`, `_evict_cache_lru`, `_preload_critical_scenes`
    - scene load/unload + contract validation (helper: `scripts/scene_management/helpers/u_scene_loader.gd`)
      - Still has manager wrapper methods: `_remove_current_scene`, `_load_scene`, `_load_scene_async`, `_validate_scene_contract`
    - transition orchestration (helper: `scripts/scene_management/u_transition_orchestrator.gd`)
      - Already delegated via `_transition_orchestrator.execute_transition_effect(...)` in `_perform_transition(...)`
    - overlay stack operations (helper: `scripts/scene_management/helpers/u_overlay_stack_manager.gd`)
      - Helper currently reads manager internals directly (`manager._ui_overlay_stack`, `manager._store`, `manager._load_scene`, etc.) and calls manager methods for focus/particles; Task 3.4 removes this coupling.

- [x] **Task 3.2 (Green)**: Delete manager-local cache duplicates (if unused) and route through `U_SceneCache`
  - Validate by search: `rg -n \"_is_scene_cached|_get_cached_scene|_evict_cache_lru|_preload_critical_scenes\" scripts/managers/m_scene_manager.gd`
  - Run: `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_manager`

- [x] **Task 3.3 (Green)**: Delete manager-local loader duplicates (if unused) and route through `U_SceneLoader`
  - Validate by search: `rg -n \"func _load_scene\\(|func _load_scene_async\\(|func _remove_current_scene\\(\" scripts/managers/m_scene_manager.gd`
  - Run: `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_manager`

- [x] **Task 3.4 (Refactor)**: Reduce hidden coupling in overlay helper
  - Refactor target: `scripts/scene_management/helpers/u_overlay_stack_manager.gd`
  - Goal: helper should not read `manager._private_fields` (e.g., `_ui_overlay_stack`, `_store`) directly.
  - Replace with explicit parameters (Callable + nodes) and update `M_SceneManager` call sites.

### 3B) State Store (`scripts/state/m_state_store.gd`)
- [x] **Task 3.5 (Baseline)**: Record current size + extraction candidates
  - Record line count: `scripts/state/m_state_store.gd`
    - 555 lines (2026-01-04)
  - Identify action history + perf metrics code blocks and extraction seams.
    - Action history: `_action_history` + `_record_action_in_history()` + `get_action_history()` + `get_last_n_actions()` (approx lines 66-68, 266-268, 392-438)
    - Perf metrics: `_perf_*` fields + tracking in `dispatch()` + `_flush_signal_batcher()` + `get_performance_metrics()`/`reset_performance_metrics()` (approx lines 73-76, 142, 240, 294-297, 529-555)

- [x] **Task 3.6 (Red)**: Add characterization tests for batching cadence (if missing)
  - File: `tests/unit/state/test_m_state_store.gd`
  - Protect:
    - `slice_updated` batching behavior
    - `"immediate": true` flush behavior
  - Already covered by:
    - `test_multiple_dispatches_emit_single_slice_updated_signal_per_frame`
    - `test_immediate_actions_flush_slice_updated_signal`

- [x] **Task 3.7 (Green)**: Extract action history buffer
  - Create helper: `scripts/state/utils/u_action_history_buffer.gd`
  - Move: history storage + helpers (`_record_action_in_history`, `get_action_history`, `get_last_n_actions`)
  - Keep `M_StateStore` API unchanged.

- [x] **Task 3.8 (Green)**: Extract perf metrics bookkeeping
  - Create helper: `scripts/state/utils/u_store_performance_metrics.gd`
  - Move: perf storage + helpers (`get_performance_metrics`, `reset_performance_metrics`)
  - Keep `M_StateStore` API unchanged.

---

## Phase 4: Organization & Naming Cleanups (Low Risk)

**Exit Criteria:** Project structure is more consistent; style tests updated if policy changes.

- [x] **Task 4.1**: Remove placeholder gameplay scene (if unused)
  - Candidate: `scenes/tmp_invalid_gameplay.tscn`
  - Verify no references:
    - `rg -n \"tmp_invalid_gameplay\" -S .`
  - Still referenced by tests (`tests/integration/scene_manager/test_scene_contract_invocation.gd`, `tests/unit/scene_manager/test_scene_registry_resources.gd`), so do not delete.

- [x] **Task 4.2**: Normalize VFX settings overlay scene location (remove `scenes/ui/settings/`)
  - Move:
    - `scenes/ui/settings/ui_vfx_settings_overlay.tscn` → `scenes/ui/ui_vfx_settings_overlay.tscn`
  - Update SceneRegistry backfill path:
    - `scripts/scene_management/helpers/u_scene_registry_loader.gd` (scene_id `vfx_settings`)
  - Update any other references:
    - `rg -n \"scenes/ui/settings/ui_vfx_settings_overlay\\.tscn\" -S .`

- [x] **Task 4.3**: (Optional) Reorder gameplay Entities subtree for scanability
  - Prefer `SpawnPoints` first under `Entities` across gameplay scenes
  - Completed (2026-01-04): Reordered in `scenes/gameplay/gameplay_base.tscn`, `scenes/gameplay/gameplay_exterior.tscn`, and `scenes/gameplay/gameplay_interior_house.tscn`.
- [x] **Task 4.4**: Plan + execute relocation of input-ish RS_* scripts currently under ECS
  - Moved to `scripts/input/resources/`:
    - `scripts/input/resources/rs_gamepad_settings.gd`
    - `scripts/input/resources/rs_input_profile.gd`
    - `scripts/input/resources/rs_rebind_settings.gd`
    - `scripts/input/resources/rs_touchscreen_settings.gd`
  - Updated all references (scripts, tests, and `.tres` script paths).
  - Updated style enforcement rules:
    - `tests/unit/style/test_style_enforcement.gd` includes `res://scripts/input/resources`: `["rs_"]`
  - Verification:
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/style`
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/resources`
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/input_manager`
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/managers`
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/ui`
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/utils`
  - Notes (2026-01-04):
    - Headless runs can require a local `.godot` UID/class-cache refresh after moving `class_name` scripts (see `docs/general/DEV_PITFALLS.md`).

- [x] **Task 4.5**: Normalize objective container placement in gameplay scenes
  - Fix drift from `docs/general/SCENE_ORGANIZATION_GUIDE.md`: objective entities belong under `Entities/Objectives`.
  - Completed (2026-01-04): moved `E_FinalGoal` under `Entities/Objectives` in `scenes/gameplay/gameplay_exterior.tscn`.

- [x] **Task 4.6**: Remove special-case spawn container prefix
  - Standardize containers: spawn container is `SpawnPoints` (no `SP_` prefix), matching `Hazards`/`Objectives`.
  - Updated:
    - Gameplay scenes + templates + spawn registry path (`Entities/SpawnPoints`)
    - Tests + style enforcement (spawn container must be under `Entities` and named `SpawnPoints`)
  - Verification:
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/style`
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/spawn_system`
    - `tools/run_gut_suite.sh -gdir=res://tests/integration/spawn_system`

---

## Phase 5: Small UX Polish (Low Risk)

**Exit Criteria:** No TODOs remain in core UI flows; user gets actionable feedback.

- [ ] **Task 5.1 (Red)**: Add failing UI tests for save/load/delete error feedback
  - Files:
    - `tests/unit/ui/test_save_load_menu.gd`
    - `tests/mocks/mock_save_manager.gd` (extend mock to simulate non-OK results)
  - Cover the existing TODOs:
    - `scripts/ui/ui_save_load_menu.gd:399` save error surface
    - `scripts/ui/ui_save_load_menu.gd:420` load error surface (overlay currently closes first)
    - `scripts/ui/ui_save_load_menu.gd:431` delete error surface
  - Expected behaviors to assert:
    - Save failure: menu shows a visible error label/message (non-empty).
    - Delete failure: menu shows a visible error label/message (non-empty).
    - Load failure (immediate error return): menu stays open (overlay not closed) and shows a visible error label/message.

- [ ] **Task 5.2 (Green)**: Implement Save/Load menu error UI (and keep menu open on immediate load failure)
  - Files:
    - `scripts/ui/ui_save_load_menu.gd`
    - `scenes/ui/ui_save_load_menu.tscn` (add a dedicated error label/message node)
  - Requirements:
    - Provide a single place to surface operation errors (save/load/delete) in the menu.
    - Only close the overlay after `load_from_slot(...)` returns `OK` (so immediate errors remain visible in-menu).

- [ ] **Task 5.3 (Red)**: Add failing test for “New Game” confirmation when saves exist
  - Files:
    - `tests/unit/ui/test_main_menu.gd`
    - `tests/mocks/mock_save_manager.gd` (extend mock so tests can simulate “saves exist”)
  - Expected:
    - If any save exists, pressing New Game shows a confirmation dialog instead of immediately dispatching `navigation/start_game`.

- [ ] **Task 5.4 (Green)**: Implement “New Game” confirmation when saves exist
  - File: `scripts/ui/ui_main_menu.gd` (resolves TODO at `scripts/ui/ui_main_menu.gd:181`)
  - Expected:
    - Confirm → dispatch `U_NavigationActions.start_game(DEFAULT_GAMEPLAY_SCENE)`
    - Cancel → do nothing (stay in main menu)

---

## Notes / Baseline Results

- Baseline test run (fill in after Task 0.3):
  - Style: ☒ pass / ☐ fail
  - Unit: ☒ pass / ☐ fail
  - Notable warnings:
    - Godot macOS: `get_system_ca_certificates` returned empty string (`ret != noErr`)
    - Shell env: `/bin/ps: Operation not permitted` (printed from Homebrew `shellenv.sh`)
