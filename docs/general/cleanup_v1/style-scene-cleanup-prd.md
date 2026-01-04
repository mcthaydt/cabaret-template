# Style & Scene Organization Cleanup PRD

**Feature Name**: Style & Scene Organization Hardening  
**Owner**: Development Team  
**Status**: Complete
**Scope**: Cross‑cutting cleanup across ECS, State Store, Scene Manager, Input Manager, UI Manager, tests, and documentation

---

## 1. Summary

This PRD defines the work required to bring the codebase to **10/10** on:

- Modularity
- Scalability
- Well‑architected design
- Adherence to `STYLE_GUIDE.md`
- Adherence to `SCENE_ORGANIZATION_GUIDE.md`

It focuses on:

- Making naming and prefixes fully consistent (every file and top‑level class has a clear, documented prefix).
- Closing gaps between **documentation vs. implementation** across PRDs, plans, and tasks.
- Eliminating **duplicate responsibilities** (notably pause/cursor handling).
- Extending the **Style Guide** and **Scene Organization Guide** to cover new subsystems (Input Manager, UI Manager, debug overlays, root scene).
- Strengthening **tooling/tests** that enforce these rules.

No gameplay features are added; this is a structural and architectural cleanup.

---

## 2. Problem Statement

The project already adheres strongly to its style and scene organization conventions, but several gaps prevent a “perfect” score:

1. **Prefix coverage is not universal**
   - Most systems/components/managers/resources follow the prefix rules, but there are:
     - UI scripts and helpers whose class names or files lack explicit prefixes.
     - Base/marker/debug scripts whose naming patterns are not fully documented in `STYLE_GUIDE.md`.
   - The user requirement is now “**every file should have a prefix**” – this needs a precise, enforceable definition and migration path.

2. **Pause and cursor responsibilities are duplicated**
   - `M_PauseManager` is documented (and partly implemented) as the engine‑level pause controller that derives pause from the navigation slice.
   - `M_SceneManager._update_pause_state()` still:
     - Sets `get_tree().paused`.
     - Dispatches pause/unpause gameplay actions.
     - Drives cursor visibility based on overlays and scene type.
   - This dual authority is a correctness risk and undermines “single source of truth” architecture.

3. **Docs vs. code drift**
   - Several PRDs and plans (Scene Manager, Input Manager, UI Manager, Redux Store) describe features as “missing” or “planned” that are now implemented and tested.
   - Conversely, new patterns (navigation‑driven UI, entity coordination, input profiles, virtual controls) are well‑implemented but not fully captured in `STYLE_GUIDE.md` or `SCENE_ORGANIZATION_GUIDE.md`.
   - This drift confuses future contributors and reduces confidence in the written architecture.

4. **Scene organization examples are slightly out of sync with reality**
   - Gameplay scenes match the *structure* of `SCENE_ORGANIZATION_GUIDE.md`, but:
     - Root nodes use names like `GameplayRoot` rather than the example `Main`, while still attaching `main.gd`.
     - New groupings (e.g., `E_Hazards`, `E_Objectives`) and controllers (e.g., `E_DoorTrigger`, `E_DeathZone`, `E_GoalZone`, `E_TutorialSign_Interior`) are not yet reflected in the guide’s examples.
   - The root scene (`scenes/root.tscn`) has its own standardized pattern that is documented in AGENTS and PRDs but not consolidated into the Scene Organization Guide.

5. **Tooling doesn’t yet enforce the new “every file has a prefix” requirement**
   - `tests/unit/style/test_style_enforcement.gd` covers:
     - Tab indentation in critical directories.
     - Trigger resource `script = ExtResource(...)` references.
   - There are no tests that:
     - Assert class/file naming conforms to the updated prefix rules.
     - Assert all new categories (UI, debug, scene_structure, resources) follow the agreed prefixes.

---

## 3. Goals

### 3.1 Primary Goals (P0)

1. **Prefix Coverage & Naming Consistency**
   - Enforce the **prefix matrix** defined in `STYLE_GUIDE.md` for:
     - All `.gd` scripts (gameplay, state, UI, managers, markers, base classes).
     - All `.tscn` scenes that participate in gameplay/UI flows.
     - All `.tres` resources that are part of runtime configuration.
   - Ensure **every production file/class** is aligned with a documented prefix family:
     - Category‑specific (e.g., `M_`, `S_`, `C_`, `RS_`, `U_`, `UI_`).
     - Or explicitly documented special prefixes for:
       - Base classes (`Base*`, `base_*.gd`).
       - Marker scripts (`*_group.gd`, `*_node.gd`).
   - Tests, prototypes, and debug helpers use the lighter rules described in the Style Guide (`test_*`, `proto_*`, `debug_*`), but remain clearly separated from production code.

2. **Single Source of Truth for Pause/Cursor**
   - Centralize pause and cursor control in **one place**, consistent with the UI Manager architecture:
     - `M_PauseManager` (or a clearly named manager/system) is responsible for:
       - `get_tree().paused`.
       - High‑level pause state (and signals).
       - Delegating cursor state to `M_CursorManager`.
   - `M_SceneManager` and other systems must:
     - Derive pause only from state/navigation or from published signals.
     - Stop manipulating `get_tree().paused` or gameplay pause fields directly.

3. **Style & Scene Guides Updated for New Patterns**
   - Extend `STYLE_GUIDE.md` to cover:
     - New categories: UI controllers, navigation helpers, debug overlays, scene_structure markers.
     - File naming rules that guarantee “every file has a prefix” while still accommodating base and marker scripts.
     - Clear examples for Input Manager and UI Manager layers.
   - Extend `SCENE_ORGANIZATION_GUIDE.md` to cover:
     - Root scene organization (`Root`, `Managers`, `ActiveSceneContainer`, `UIOverlayStack`, `TransitionOverlay`, `LoadingOverlay`, `MobileControls`).
     - Interactable controllers pattern (already partially documented).
     - Entity groupings and naming patterns (hazards, objectives, signposts).

4. **Hard Tests for Style & Scene Rules**
   - Expand `tests/unit/style/test_style_enforcement.gd` (or parallel suites) to enforce:
     - Prefix patterns per directory/category.
     - Allowed exceptions (documented by pattern, not ad‑hoc).
     - Scene/resource naming where practical.

5. **Docs/Plans/Tasks Alignment**
   - Update existing PRDs, plans, and task lists (Scene Manager, State Store, Input Manager, UI Manager, ECS) so that:
     - All **implemented** features are marked complete and described as such.
     - All **future** work is moved into new cleanup tasks or explicitly marked as deferred.
     - Architecture diagrams and narrative match the current code, not historical intermediate states.

### 3.2 Secondary Goals (P1)

6. **Refined Debug & Testing Patterns**
   - Document and standardize naming/prefixes for debug scenes (`sc_state_debug_overlay.tscn`, etc.), integration test scenes, and prototypes.
   - Optionally add style checks that ensure debug/test assets:
     - Live only under certain directories.
     - Use clear prefixes and are not accidentally shipped as production content.

7. **Process Discipline Hooks**
   - Ensure each major subsystem’s “continuation prompt” and tasks checklist explicitly call out:
     - The updated style/scene rules.
     - The requirement to run style/scene tests.

8. **ECS Entity IDs & Tagging**
   - Introduce explicit, stable entity identifiers in the ECS layer (beyond Node paths).
   - Add an optional tag/indexing layer (e.g., per‑tag lists, fast lookups) to support more complex gameplay and AI.
   - Ensure the new entity ID model integrates cleanly with `U_EntitySelectors` and the state store’s entity snapshots.

9. **Spawn Registry & Spawn Conditions**
   - Add a lightweight spawn registry that can describe spawn points with metadata (tags, conditions).
   - Integrate spawn conditions with `M_SpawnManager` (e.g., gated by quest state, area progress).
   - Keep the initial implementation simple (no quest system yet), but design for future expansion.

10. **Multi‑Slot Save Manager**
    - Wrap `M_StateStore.save_state/load_state` in a dedicated save manager that supports multiple slots.
    - Define a minimal slot metadata format (last played, location, etc.).
    - Provide a thin UI/overlay for selecting slots (even if it is initially developer‑facing).

---

## 4. Non‑Goals

- Redesigning gameplay, physics, or player feel.
- Changing high‑level flow (menu → gameplay → pause → endgame).
- Replacing Godot 4.5 or major engine‑level configuration.
- Introducing wholly new subsystems **unrelated** to style/scene/architecture (e.g., full quest system, combat overhaul).
- Adding new runtime features on top of the Input/UI/Scene Managers beyond what’s already scoped (ECS IDs, spawn registry, multi‑slot save).

---

## 5. Requirements

### 5.1 Naming & Prefix Rules

1. **Global Rule**: Every production `.gd`, `.tscn`, and `.tres` in `res://scripts`, `res://scenes`, and `res://resources` must:
   - Have a filename that starts with a documented prefix (e.g., `m_`, `s_`, `c_`, `rs_`, `u_`, `sc_`, `e_`, `so_`, `env_`, `base_`, `ui_`, etc.), or
   - Be explicitly covered by a special “marker/base/debug” prefix rule in `STYLE_GUIDE.md`.

2. **Class Names**:
   - Must use the appropriate prefix for their category (`M_`, `S_`, `C_`, `RS_`, `U_`, `Base*`, `SC_*`, etc.).
   - Base and marker scripts must be documented as acceptable exceptions (e.g., `BaseECSSystem`, `main.gd`).

3. **Scenes & Resources**:
   - Gameplay scenes under `scenes/gameplay` must use consistent naming (e.g., `gameplay_*` or `sc_*` pattern acceptable if documented).
   - UI scenes under `scenes/ui` should be covered by a `SC_` or `ui_` prefix rule in the style guide.
   - Resource files must match their `class_name` where applicable (`rs_*`, `rs_*_settings`, etc.).

### 5.2 Scene Organization

4. **Gameplay Scenes**:
   - Must follow the hierarchy defined in `SCENE_ORGANIZATION_GUIDE.md`:
     - Root Node3D with `main.gd`.
     - `SceneObjects`, `Environment`, `Systems`, `Managers`, `Entities`, `SpawnPoints`, `HUD` as appropriate.
   - System nodes and priorities must match the documented category layout.

5. **Root Scene**:
   - `scenes/root.tscn` must be codified in the guide as the canonical root pattern:
     - `Managers` node with all manager scripts.
     - `ActiveSceneContainer`, `UIOverlayStack`, `TransitionOverlay`, `LoadingOverlay`, `MobileControls`.
   - Any evolution (e.g., new managers) must be reflected in both the guide and the root scene.

6. **Interactable Controllers**:
   - Single‑entity `E_*` controllers must:
     - Own their `Area3D` via settings/controller logic.
     - Use `RS_SceneTriggerSettings` via `settings` export.
     - Follow naming rules in both style and scene organization guides.

### 5.3 Responsibility & Architecture

7. **Pause & Cursor**:
   - `M_PauseManager` is the **single authority** for:
     - Engine pause (`get_tree().paused`).
     - Emitting a canonical pause signal/state.
     - Delegating cursor visibility/lock state to `M_CursorManager`.
   - `M_SceneManager`:
     - Must not set `get_tree().paused` directly.
     - May still manage particles and scene‑local pause behaviours, but must depend on the centralized pause indicator (navigation slice or `M_PauseManager`), not its own overlay count.

8. **Navigation & UI**:
   - `navigation` slice and UI registry remain source of truth for UI state.
   - All pause/overlay flows must be derived from navigation actions/selectors, not from raw Input or ad‑hoc state checks.

### 5.4 Tests & Tooling

9. **Style Tests**:
   - Extend style tests to enforce:
     - Prefix rules per directory/category.
     - Exceptions documented in `STYLE_GUIDE.md`.

10. **Scene Tests**:
    - Add or extend tests that assert:
      - Gameplay scenes have the required groups and markers.
      - Root scene wiring (managers, containers) matches the documented pattern.

11. **Docs & Tasks**:
    - For each major subsystem (ECS, State Store, Scene Manager, Input Manager, UI Manager), ensure:
      - PRD, plan, and tasks files are consistent with the current implementation.
      - Any remaining work that affects style/scene organization is referenced from this cleanup tasks file, not scattered in multiple places.

---

## 6. Risks & Mitigations

1. **Risk: Renaming classes/files could break resources and scenes.**
   - **Mitigation**:
     - Use incremental phases with tests at each step.
     - Prefer editor‑driven refactors where feasible.
     - Add temporary compatibility aliases only if absolutely necessary, then remove once migration is complete.

2. **Risk: New style/scene checks might fail for legitimate edge cases.**
   - **Mitigation**:
     - Document exceptions explicitly in `STYLE_GUIDE.md`.
     - Parameterize tests with allowlists for specific paths/patterns.

3. **Risk: Pause refactor could regress gameplay behaviour.**
   - **Mitigation**:
     - Drive pause flows via existing integration tests (pause system, edge cases, input during transition).
     - Add additional tests to cover interactions with Scenes, UI, and MobileControls.

4. **Risk: Documentation updates lag behind code again.**
   - **Mitigation**:
     - Treat documentation updates as first‑class tasks in this cleanup project.
     - Require docs to be updated in the same phase as implementation, with separate commits as per AGENTS.

---

## 7. Acceptance Criteria

The cleanup work is considered complete when:

1. All agreed prefix rules are codified in `STYLE_GUIDE.md` and enforced by automated tests.
2. All `.gd`, `.tscn`, and `.tres` files in production directories adhere to a documented prefix pattern or exception rule.
3. `SCENE_ORGANIZATION_GUIDE.md` matches:
   - The current gameplay scenes (base, exterior, interior_house).
   - The current root scene structure.
   - The interactable controller patterns.
4. `M_PauseManager` (or a clearly designated component) is the sole owner of engine pause state and cursor coordination, with tests confirming behaviour.
5. `M_SceneManager` no longer directly toggles `get_tree().paused` or gameplay pause flags, instead responding to navigation/pause state.
6. All subsystem PRDs/plans/tasks are synchronized with the present codebase; any remaining work is delegated to this cleanup tasks file.
7. Full GUT test suites (ECS, state, scene_manager, input_manager, ui, style) pass on target platforms.
