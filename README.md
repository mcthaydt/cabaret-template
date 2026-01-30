# Cabaret Template (Godot 4.5)

![MOV to GIF (1)](https://github.com/user-attachments/assets/419c5753-2701-4444-aa7b-26b0d59edbd1)

Cabaret Template is an opinionated Godot 4.5 starter project for building a small-to-medium game with:
- A lightweight **Node-based ECS** (entities + components + systems) for gameplay logic
- A **Redux-style state store** (actions/reducers/selectors) for deterministic state + UI/navigation
- A **scene manager** with transitions, overlays, preloading, and caching
- A unified **input stack** (keyboard/mouse, gamepad, touchscreen) with profiles + rebinding
- A real **GUT test suite** + style/scene-structure enforcement

## Quick Start

1. Install **Godot 4.5**.
2. Open `project.godot` in Godot.
3. Press Play: `scenes/root.tscn` boots persistent managers and loads the initial scene (`main_menu` by default).

## What You Get

### Features

- **Persistent root scene** (`scenes/root.tscn`) with global managers and containers
- **Scene transitions** (`instant`, `fade`, `loading`) + transition queue with priorities
- **UI overlay stack** (pause/settings/rebind/etc) driven by navigation state
- **Scene registry**:
  - Critical scenes are hardcoded for boot safety
  - Non-critical scenes can be added via `.tres` resources under `resources/scene_registry/`
- **ECS**:
  - `BaseECSComponent`, `BaseECSSystem`, `M_ECSManager`
  - Entity IDs + tags, component queries, query caching + optional query metrics
  - ECS event bus for decoupled gameplay events
- **State store** (`M_StateStore`):
  - Slice-based state, action history (debug), persistence, and handoff across scene transitions
  - Helpers for safe lookup + async readiness (`U_StateUtils.await_store_ready()`)
- **Input system**:
  - Active device detection + centralized device types
  - Input sources (`I_InputSource`) for keyboard/mouse, gamepad, and touchscreen
  - Input profiles (`resources/input/profiles/`) + Redux-driven rebinding
  - Optional desktop touchscreen smoke testing via `--emulate-mobile`
- **Testing**:
  - GUT runner (`addons/gut`) with headless scripts
  - Mock ECS manager + mock state store for isolated system tests

### Benefits

- **Faster iteration**: core glue (scene transitions, UI overlays, input, persistence) already exists
- **Determinism by default**: gameplay systems dispatch actions; UI reads selectors and reacts
- **Clear boundaries**: root managers vs per-gameplay-scene ECS, plus explicit service dependencies
- **Template-friendly**: content can be added via Resources, not only code

## Architecture Overview

### Runtime structure

`scenes/root.tscn` persists for the entire session:

```
Root
├─ Managers
│  ├─ M_StateStore
│  ├─ M_SceneManager
│  ├─ M_PauseManager
│  ├─ M_SpawnManager
│  ├─ M_CameraManager
│  ├─ M_CursorManager
│  ├─ M_InputProfileManager
│  ├─ M_InputDeviceManager
│  └─ M_UIInputHandler
├─ ActiveSceneContainer   (gameplay scenes are loaded here)
├─ UIOverlayStack         (pause/settings/etc)
├─ TransitionOverlay
└─ LoadingOverlay
```

Gameplay scenes (e.g., `scenes/gameplay/gameplay_base.tscn`) each include their own `M_ECSManager` and a standard tree layout (systems/entities/environment/etc).

### Service discovery

On boot, `scripts/root.gd` registers manager nodes in `U_ServiceLocator` for fast access and validates declared dependencies. Most code should use:

- `U_ServiceLocator` for global managers
- `U_StateUtils` for store lookup/readiness
- `U_ECSUtils` for ECS manager/entity discovery

## Using The Template

### Rename/customize checklist (recommended)

- Update project name/icon: `project.godot`
  - `config/name`
  - `config/icon`
- Replace sample scenes under `scenes/gameplay/` and update `resources/scene_registry/cfg_*_entry.tres` accordingly
- Review `resources/input/profiles/` and tune defaults under `resources/input/*`
- Replace placeholder art under `assets/`
- Skim the conventions docs:
  - `docs/general/STYLE_GUIDE.md`
  - `docs/general/SCENE_ORGANIZATION_GUIDE.md`
  - `docs/general/DEV_PITFALLS.md`

### Add a new gameplay scene

1. Duplicate `scenes/gameplay/gameplay_base.tscn`.
2. Keep the standard scene tree structure (see `docs/general/SCENE_ORGANIZATION_GUIDE.md`).
3. Register it via a resource entry:
   - Create an `RS_SceneRegistryEntry` under `resources/scene_registry/`
   - See `docs/scene_manager/ADDING_SCENES_GUIDE.md`

### Add an ECS component

- Create `scripts/ecs/components/c_<name>_component.gd` extending `BaseECSComponent`.
- Prefer `@export` NodePaths/resources + typed getters; treat missing paths as “feature disabled”.
- If you add new exported settings fields, update the corresponding default `.tres` under `resources/`.

### Add an ECS system

- Create `scripts/ecs/systems/s_<name>_system.gd` extending `BaseECSSystem`.
- Implement `process_tick(delta)`.
- Add the system node to your gameplay scene under `Systems/*`.
- Query via `get_components(StringName(...))` or `query_entities([...])`.

### Read/write Redux state

- In `_ready()`, prefer `await U_StateUtils.await_store_ready(self)` (avoids race conditions).
- Dispatch only via action creators under `scripts/state/actions/`.
- Prefer selectors under `scripts/state/selectors/` for reads.

### UI screens & overlays

- Screen metadata lives in `resources/ui_screens/cfg_*.tres` (`RS_UIScreenDefinition`).
- `U_UIRegistry` preloads/registers definitions for export determinism; add new screens there.
- UI typically drives flow by dispatching navigation actions (rather than calling the scene manager directly).

## Testing

This repo uses GUT (`addons/gut`). A helper script is provided:

- Run all tests: `tools/run_gut_suite.sh`
- Run unit tests: `tools/run_gut_suite.sh -gdir=res://tests/unit`
- Run style enforcement: `tools/run_gut_suite.sh -gdir=res://tests/unit/style`

`tools/run_gut_suite.sh` uses `GODOT_BIN` (defaults to `/Applications/Godot.app/Contents/MacOS/Godot` on macOS):

```bash
GODOT_BIN="/path/to/Godot" tools/run_gut_suite.sh -gdir=res://tests/unit
```

## Docs (Start Here)

- General pitfalls: `docs/general/DEV_PITFALLS.md`
- Naming/prefix conventions: `docs/general/STYLE_GUIDE.md`
- Scene tree conventions: `docs/general/SCENE_ORGANIZATION_GUIDE.md`
- Manager dependency graph: `docs/architecture/dependency_graph.md`
- ECS ↔ state contract: `docs/architecture/ecs_state_contract.md`
- Scene registry workflow: `docs/scene_manager/ADDING_SCENES_GUIDE.md`

