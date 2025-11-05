# Implementation Plan: Scene Manager System

**Branch**: `SceneManager` | **Date**: 2025-10-27 | **Spec**: [scene-manager-prd.md](./scene-manager-prd.md)
**Input**: Feature specification from `/docs/scene_manager/scene-manager-prd.md`

**Post-Phase Tracker**: Follow-up hardening tasks now live in [post-scene-manager-tasks.md](./post-scene-manager-tasks.md). Treat that checklist as the authoritative source for ongoing work after Phase 12.

**⚠️ CRITICAL FINDINGS**: This plan has been revised to address significant architectural challenges not captured in the initial PRD:

1. **Scene Restructuring Required** (High Impact): Current architecture merges managers + gameplay content. Scene Manager requires separation into root scene (persistent managers) + gameplay scenes (dynamic content). This affects ALL existing scenes.

2. **Breaking Changes** (Revised Assessment): NOT an additive feature. Requires restructuring base_scene_template.tscn, changing project.godot main scene, and potentially updating all test scenes.

3. **Effort Increased 40%**: Original estimate 25-35 hours → Revised 35-50 hours due to restructuring overhead and regression testing requirements.

4. **Phase 0 is CRITICAL GATE**: Must prototype restructuring and validate ECS/Redux still work before committing to implementation. If prototype fails, reconsider architecture.

5. **Strict TDD Required**: All 174 existing tests must pass after restructuring. Any regression is a blocker.

See "⚠️ CRITICAL: Architecture Restructuring Required" section below for full analysis.

## Summary

The Scene Manager system provides centralized scene flow control for a Zelda: Ocarina of Time-style game (menu → gameplay (exterior ↔ interior) → pause → end). The system integrates with the existing Redux-based M_StateStore for state management and per-scene M_ECSManager architecture. Key features include:

- **Hybrid scene transitions**: Stack-based for UI overlays (pause/settings), replacement for major scene changes (menu/gameplay/areas)
- **State persistence**: Player state, progress, and settings persist across transitions via M_StateStore serialization
- **Area transitions**: Zelda OoT-style exterior ↔ interior with door pairings and spawn points
- **Transition effects**: Fade, instant, loading screen, and custom transitions
- **Scene preloading**: Mixed strategy (UI preloaded at startup, gameplay on-demand)
- **Pause system**: Freezes gameplay with scene stack, allows nested menus
- **End-game flows**: Game over, victory, and credits scenes with proper navigation

**Technical approach**:
- M_SceneManager (new coordinator) dispatches scene actions to M_StateStore (existing Redux store)
- Scene state slice tracks current_scene_id, scene_stack, is_transitioning
- Root scene pattern: root.tscn persists throughout session, scenes load into ActiveSceneContainer
- Per-scene M_ECSManager (existing pattern) with StateHandoff for gameplay state preservation
- U_SceneRegistry (static class) defines scene metadata and door pairings
- ECS integration via C_SceneTriggerComponent and S_SceneTriggerSystem

## Technical Context

**Language/Version**: GDScript (Godot 4.5)
**Primary Dependencies**:
- Godot 4.5 engine
- Existing ECS framework (M_ECSManager, ECSComponent, ECSSystem, U_ECSUtils)
- M_StateStore (Redux-style state management)
- StateHandoff (state preservation utility)
- GUT (Godot Unit Testing framework)

**Storage**: JSON-based persistence via M_StateStore.save_state() / load_state()
**Testing**: GUT framework for unit/integration tests, manual in-game validation
**Target Platform**: Godot 4.5 runtime (Windows/macOS/Linux/console)
**Project Type**: Single (Godot game project with scene-based architecture)

**Performance Goals**:
- UI transitions (menu to menu): < 0.5s
- Gameplay transitions (exterior/interior): < 3s
- Large area loads: < 5s (with loading screen)
- Scene transitions at 60 FPS minimum
- Memory stable across 20+ transitions (no leaks)

**Constraints**:
- **No autoloads**: Scene-tree-based architecture, discovery via groups and parent traversal
- **Per-scene M_ECSManager**: Each scene has own ECS instance, state preserved via M_StateStore
- **Root scene persistence**: root.tscn remains loaded entire session, scenes load as children
- **Immutable state updates**: All reducers use .duplicate(true) for state changes
- **Scene tree structure**: Must work with existing Godot scene tree, no singleton dependencies

**Scale/Scope**:
- 8+ scene types: Main Menu, Settings Menu, Pause Menu, Loading Screen, Gameplay Areas (exterior/interior/dungeon), Game Over, Victory, Credits
- 3 priority levels (P1: Core transitions & state, P2: Area transitions & pause, P3: Polish & end-game)
- 7 user stories with acceptance scenarios
- 58 edge cases handled
- 112 functional requirements
- 22 success criteria

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Architectural Constraints Check**:

✅ **No Autoloads**: M_SceneManager will be in-scene node in root.tscn, discoverable via "scene_manager" group
✅ **Per-Scene ECS**: Maintains existing M_ECSManager pattern, one instance per active scene
✅ **State Management**: Integrates with existing M_StateStore (Redux) by adding "scene" slice
✅ **Scene Tree Based**: All managers live in scenes, no singleton configuration required
✅ **StateHandoff Compatible**: Leverages existing StateHandoff utility for state preservation

**Integration Points Validated**:

✅ **M_StateStore**: Exists, will add scene slice registration (FR-112)
✅ **StateHandoff**: Exists, already handles state preservation across scene transitions
✅ **ECS Systems**: Existing systems follow pattern that Scene Manager can adopt
✅ **Project Settings**: RS_StateStoreSettings pattern can be used for scene settings
✅ **GUT Testing**: Framework already in use, tests can follow existing patterns

**Risk Assessment**:

⚠️ **Moderate Complexity**: Scene Manager coordinates multiple systems (state, ECS, Godot scene tree, transitions)
✅ **Well-Scoped**: PRD comprehensive with resolved questions, clear phases, and incremental delivery
✅ **Proven Patterns**: Reuses existing Redux patterns, ECS integration, and StateHandoff mechanisms
⚠️ **New Territory**: Scene transitions with camera blending and state coordination are new to codebase

**Decision**: ✅ **APPROVED TO PROCEED**
- Architecture aligns with project constraints
- Integration points well-defined
- Risk mitigated by phased approach (P1 → P2 → P3)
- Comprehensive PRD provides clear implementation path

## Project Structure

### Documentation (this feature)

```text
docs/scene_manager/
├── scene-manager-plan.md       # This file (implementation plan)
├── scene-manager-prd.md        # Feature specification (v2.3 - complete)
├── research.md                 # Phase 0 output (architectural research)
├── data-model.md               # Phase 1 output (scene slice, U_SceneRegistry)
├── quickstart.md               # Phase 1 output (usage guide for Scene Manager)
└── contracts/                  # Phase 1 output (API contracts for M_SceneManager)
```

### Source Code (repository root)

```text
# Root Scene (persistent)
scenes/
└── root.tscn                   # Main scene, persists entire session
    ├── M_StateStore            # Redux store (existing, modified)
    ├── M_SceneManager          # Scene coordinator (NEW)
    ├── ActiveSceneContainer    # Container for active scene (NEW)
    ├── UIOverlayStack          # CanvasLayer for pause/settings (NEW)
    ├── TransitionOverlay       # CanvasLayer for fade effects (NEW)
    └── LoadingOverlay          # CanvasLayer for loading screens (NEW)

# Scene Manager Scripts
scripts/
├── managers/
│   ├── m_ecs_manager.gd       # Existing - per-scene ECS manager
│   ├── m_state_store.gd       # Existing - Redux store (MODIFIED: add scene slice)
│   ├── m_cursor_manager.gd    # Existing - cursor state manager
│   └── m_scene_manager.gd     # NEW - Scene transition coordinator
│
├── state/
│   ├── m_state_store.gd       # MODIFIED: Register scene slice (FR-112)
│   ├── utils/u_state_handoff.gd       # Existing - State preservation utility
│   ├── u_scene_actions.gd     # NEW - Scene action creators
│   ├── /actions/              # Existing directory for action creators
│   ├── /reducers/
│   │   └── u_scene_reducer.gd   # NEW - Scene slice reducer
│   └── /resources/
│       └── rs_scene_initial_state.gd  # NEW - Scene slice initial state
│
├── scene_management/          # NEW directory
│   ├── u_scene_registry.gd      # NEW - Static class for scene metadata
│   └── /transitions/          # NEW directory
│       ├── base_transition_effect.gd        # NEW - Base transition interface
│       ├── instant_transition.gd       # NEW - Instant transition
│       ├── fade_transition.gd          # NEW - Fade effect
│       └── loading_screen_transition.gd # NEW - Loading screen
│
└── ecs/
    ├── /components/
    │   └── c_scene_trigger_component.gd  # NEW - Door/zone trigger
    └── /systems/
        └── s_scene_trigger_system.gd     # NEW - Trigger processing

# UI Scenes
scenes/
├── ui/
│   ├── main_menu.tscn         # NEW - Main menu scene
│   ├── settings_menu.tscn     # NEW - Settings menu
│   ├── pause_menu.tscn        # NEW - Pause overlay
│   ├── loading_screen.tscn    # NEW - Loading screen UI
│   ├── game_over.tscn         # NEW - Game over screen
│   ├── victory.tscn           # NEW - Victory screen
│   └── credits.tscn           # NEW - Credits scene
│
└── gameplay/
    ├── exterior_template.tscn # NEW - Exterior gameplay area (with M_ECSManager)
    ├── interior_template.tscn # NEW - Interior gameplay area (with M_ECSManager)
    └── dungeon_template.tscn  # NEW - Dungeon gameplay area (with M_ECSManager)

# Tests
tests/
├── integration/
│   └── scene_manager/
│       ├── test_basic_transitions.gd      # NEW - P1 transition tests
│       ├── test_state_persistence.gd      # NEW - P1 state tests
│       ├── test_pause_system.gd           # NEW - P2 pause tests
│       ├── test_area_transitions.gd       # NEW - P2 door/spawn tests
│       └── test_scene_slice.gd            # NEW - Scene slice Redux tests
│
└── unit/
    └── scene_manager/
        ├── test_scene_registry.gd         # NEW - U_SceneRegistry tests
        ├── test_scene_reducer.gd          # NEW - SceneReducer tests
        ├── test_u_scene_actions.gd        # NEW - Action creator tests
        └── test_m_scene_manager.gd        # NEW - M_SceneManager tests
```

**Structure Decision**: Single project structure with Godot scene-based architecture. Root scene pattern maintains persistent managers (M_StateStore, M_SceneManager) while scenes load/unload as children. Per-scene M_ECSManager instances handle gameplay logic with state coordination via Redux store. Follows existing project patterns: auto-discovery via groups, scene-tree-based managers, StateHandoff for state preservation.

## ⚠️ CRITICAL: Architecture Restructuring Required

**Current State vs Target State Mismatch**:

The Scene Manager requires a **root scene pattern** where managers persist separately from gameplay content. However, the current project structure has them **merged**:

**Current Architecture** (`templates/base_scene_template.tscn` as main scene):
```
base_scene_template.tscn (uid://rygahxanlmio)
├── Managers/
│   ├── M_StateStore      ✅ Needed in root
│   ├── M_ECSManager      ❌ Should be per-gameplay-scene
│   └── M_CursorManager   ✅ Needed in root
├── Systems/              ❌ Should be in gameplay scenes
├── Entities/             ❌ Should be in gameplay scenes
│   └── E_Player          ❌ Should be in gameplay scenes
├── SceneObjects/         ❌ Should be in gameplay scenes
└── HUD                   ? May stay in root or move to gameplay
```

**Target Architecture** (Scene Manager requires):
```
root.tscn (NEW - will become main scene)
├── M_StateStore          ✅ Persists forever
├── M_SceneManager        ✅ Persists forever
├── M_CursorManager       ✅ Persists forever
├── ActiveSceneContainer  ✅ Where gameplay scenes load
├── UIOverlayStack        ✅ For pause/settings overlays
├── TransitionOverlay     ✅ For fade effects
└── LoadingOverlay        ✅ For loading screens

gameplay_scene.tscn (loads into ActiveSceneContainer)
├── Managers/
│   └── M_ECSManager      ✅ Per-scene instance
├── Systems/              ✅ Per-scene systems
├── Entities/             ✅ Per-scene entities
│   └── E_Player          ✅ Spawned dynamically
└── SceneObjects/         ✅ Per-scene content
```

**Impact Assessment**:

| Change | Scope | Risk | Mitigation |
|--------|-------|------|------------|
| Create new root.tscn | **High** | Medium | Prototype in Phase 0, validate before committing |
| Extract gameplay from base_scene_template | **High** | High | Create new gameplay_scene.tscn, test ECS/Redux still work |
| Update project.godot main scene | **Medium** | Low | Simple config change once root.tscn proven |
| Migrate existing debug scenes | **High** | Medium | Keep old scenes working, migrate incrementally |
| Update all scene references | **Medium** | Medium | Systematic search/replace, validate each |

**Breaking Changes** (Revised Assessment):
- ❌ **NOT an additive feature** - requires restructuring scene hierarchy
- ❌ Current main scene (base_scene_template.tscn) will be demoted to gameplay template
- ❌ All existing test scenes reference base_scene_template - may need updates
- ❌ ECS tests may fail if scene structure changes
- ✅ Can maintain backward compatibility during migration with careful phasing

**Migration Strategy**:
1. **Phase 0**: Prototype root.tscn with minimal managers, load base_scene_template as child, validate no regressions
2. **Phase 1**: Create new root.tscn properly, extract gameplay_scene.tscn from base_scene_template, test thoroughly
3. **Phase 1**: Switch project.godot to root.tscn only after validation
4. **Phase 2+**: Gradually migrate debug/test scenes to new structure

**Decision Gate**: MUST validate Phase 0 prototype before proceeding. If scene restructuring breaks too much, reconsider architecture.

## Complexity Tracking

**Constitution Alignment** (Revised):

✅ **No Autoloads**: Scene Manager is in-scene node
✅ **Per-Scene ECS**: Each gameplay scene has own M_ECSManager
✅ **State Management**: Integrates with M_StateStore
⚠️ **Scene Structure Changes**: Requires splitting managers from gameplay content

**Complexity Increased Due to Restructuring**:

| Aspect | Complexity | Justification |
|--------|------------|---------------|
| State Management | **Moderate** | Adds 1 new slice to existing store (scene), reuses Redux patterns |
| Scene Coordination | **High** | Coordinates Godot scene tree, ECS lifecycle, state updates, and transition effects |
| Scene Restructuring | **Very High** | Must separate managers from gameplay, migrate all scenes, risk of breaking ECS/Redux |
| Transition Effects | **Low-Moderate** | Standard tweening/animation, well-defined interface |
| Testing Complexity | **High** | Must validate no ECS/Redux regressions PLUS new scene transition tests |

**Complexity Mitigation**:

1. **Phased Implementation**: P1 (Core), P2 (Gameplay), P3 (Polish) allows incremental validation
2. **Proven Patterns**: Reuses existing Redux, ECS, and StateHandoff patterns from codebase
3. **Comprehensive PRD**: All 24 architectural questions resolved, clear requirements
4. **Test-Driven**: Each phase has test requirements before moving forward
5. **Decision Gates**: Must pass validation at end of Phase 0 before proceeding to implementation

**Total Estimated Effort** (Revised): 41-59 hours
- Phase 0 (Research + Prototype): 5-8 hours (increased for restructuring prototype + async loading research)
- Phase 1 (P1 Foundation): 20-27 hours (increased for scene extraction + migration + edge cases)
- Phase 2 (P2 Gameplay): 9-12 hours (includes scene history navigation + M_CursorManager integration)
- Phase 3 (P3 Polish): 5-7 hours
- Testing & Documentation: 2-5 hours (ECS/Redux regression testing)

**Note**: Estimate increased by ~60% due to scene restructuring requirements, edge case testing, and scene history navigation not initially accounted for.

## Implementation Phases

### Phase 0: Research & Architecture Validation (5-8 hours) - CRITICAL GATE

**Goal**: Validate architectural decisions, prototype scene restructuring, prove feasibility

**⚠️ DECISION GATE**: This phase MUST be completed and approved before Phase 1. If prototype fails or restructuring too risky, STOP and reconsider architecture.

**Part 1: Research & Documentation** (2-3 hours)

Create `docs/scene_manager/research.md` covering:
- Scene transition patterns in Godot 4.5
- Camera blending techniques (PROTOTYPE REQUIRED - see Part 2)
- **AsyncLoading pattern**: ResourceLoader.load_threaded_request() / load_threaded_get_status() / load_threaded_get() usage
- AsyncLoading progress callbacks for loading screens
- Performance baseline (MEASURE REQUIRED - see Part 2)
- Hot reload behavior during scene transitions
- Godot 4.5 scene lifecycle during load/unload
- process_mode behavior during SceneTree.paused state
- CanvasLayer overlay interaction with paused scene tree

Create `docs/scene_manager/data-model.md` covering:
- Scene state slice schema
- U_SceneRegistry structure with door pairings
- BaseTransitionEffect interface
- Action/reducer signatures
- Integration points (ActionRegistry, RS_StateSliceConfig, U_SignalBatcher)

**Part 2: Critical Prototypes** (3-5 hours) - MUST VALIDATE

1. **Scene Restructuring Prototype** (2-3 hours):
   - Create minimal `scenes/root_prototype.tscn` with only M_StateStore, M_CursorManager
   - Create `ActiveSceneContainer` node in root
   - Load `base_scene_template.tscn` as child of ActiveSceneContainer via script
   - **Validate**: ECS still works, Redux still works, no errors
   - **Validate**: Can unload base_scene_template and reload without crashes
   - **Measure**: Scene load time (baseline for performance targets)
   - Document findings in research.md

2. **Camera Blending Prototype** (1-2 hours):
   - Create test scene with two Camera3D nodes
   - Implement interpolation using Tween: `global_position`, `global_rotation`, `fov`
   - Test smooth transition over 0.5s
   - **Validate**: No camera jitter, smooth motion
   - Document implementation pattern in research.md

3. **M_StateStore Modification Safety Check** (30 min):
   - Review `M_StateStore._initialize_slices()` method
   - Plan where scene slice registration will go
   - **Validate**: Adding scene slice won't break existing boot/menu/gameplay slices
   - Check if `ActionRegistry` can handle scene action registration
   - Document integration plan in data-model.md

**Part 3: Performance Baseline** (30 min)

Measure current performance:
- Time to load base_scene_template.tscn from blank scene
- Time to reload base_scene_template.tscn (hot)
- Memory usage before/after load
- **Result**: Baseline to compare against < 0.5s UI, < 3s gameplay targets
- Document in research.md

**Acceptance Criteria** (ALL MUST PASS):
- [ ] Scene restructuring prototype works (ECS + Redux functional after load as child)
- [ ] Camera blending prototype smooth (no jitter)
- [ ] M_StateStore modification plan safe (no risk to existing slices)
- [ ] Performance baseline measured (targets achievable)
- [ ] research.md complete with all findings
- [ ] data-model.md complete with integration details

**Decision Gate Questions**:
1. Does scene restructuring break ECS or Redux? (If yes, STOP)
2. Can we achieve performance targets based on baseline? (If no, adjust or STOP)
3. Is camera blending implementation feasible? (If too complex, descope or STOP)
4. Is M_StateStore modification safe? (If risky, consider alternative architecture)

**Output**:
- Architecture validated OR concerns raised requiring design changes
- Prototypes proven OR blockers identified
- Ready for Phase 1 implementation OR decision to pivot/descope

---

### Phase 1: P1 Foundation - Core Transitions & State (20-27 hours)

**Goal**: Implement basic scene transitions with state persistence (User Stories 1 & 2)

**⚠️ TDD Required**: For EVERY task below, follow strict TDD:
1. Write test FIRST (watch it fail)
2. Implement minimal code (watch it pass)
3. In-game validation
4. Commit with test-green state

**CRITICAL: Scene Restructuring First** (5-6 hours)

Before implementing Scene Manager, must restructure existing scenes:

0. **Run Baseline Tests** (30 min)
   - Run ALL existing tests: `tests/unit/ecs`, `tests/unit/state`, `tests/unit/integration`
   - Document passing count (current baseline: ~314 test methods across 48 files)
   - **Note**: 174 count from continuation prompt is Phase 16 baseline (outdated)
   - **Blocker**: If tests not passing NOW, fix before restructuring

1. **Create Production Root Scene** (2-3 hours)
   - Create `scenes/root.tscn` (based on Phase 0 prototype)
   - Add M_StateStore (with boot/menu/gameplay/scene slices)
   - Add M_CursorManager
   - Add M_SceneManager (stub node for now)
   - Add ActiveSceneContainer (Node type)
   - Add UIOverlayStack (CanvasLayer, process_mode = PROCESS_MODE_ALWAYS)
   - Add TransitionOverlay (CanvasLayer with ColorRect)
   - Add LoadingOverlay (CanvasLayer, initially hidden)
   - **DO NOT change project.godot yet**

2. **Extract Gameplay Scene** (2-3 hours)
   - Duplicate `base_scene_template.tscn` → `scenes/gameplay/gameplay_base.tscn`
   - Remove from gameplay_base.tscn: M_StateStore, M_CursorManager (stay in root)
   - Keep in gameplay_base.tscn: M_ECSManager, Systems, Entities, SceneObjects, Environment
   - **Critical**: Update HUD to find M_StateStore via `U_StateUtils.get_store()` (may need await)
   - Test gameplay_base.tscn loads correctly when added as child

3. **Integration Validation** (1 hour)
   - Create test script in root.tscn that loads gameplay_base.tscn into ActiveSceneContainer
   - Run game from root.tscn
   - **Validate**: ECS works, Redux works, player moves, HUD updates
   - **Validate**: ALL ~314 tests still pass (no regressions from baseline)
   - **Blocker**: If ANY test fails, fix before proceeding

4. **Switch Main Scene** (30 min)
   - Update `project.godot`: `run/main_scene` = `uid://[new_root_uid]`
   - Test game still launches
   - **Validate**: No regressions

**Scene Manager Implementation** (7-9 hours)

5. **Scene State Slice Setup** (2-3 hours) - TDD REQUIRED
   - **Test First**: Write `tests/unit/scene_manager/test_scene_reducer.gd`
   - Create `scripts/state/resources/rs_scene_initial_state.gd`
   - Create `scripts/state/reducers/u_scene_reducer.gd`
   - Create `scripts/state/actions/u_scene_actions.gd` with ActionRegistry registration in `_static_init()`
   - Modify `M_StateStore._initialize_slices()` to register scene slice (FR-112)
   - **Test Pass**: Unit tests for scene slice pass
   - **Test**: Verify transient fields (is_transitioning) excluded from save_state()
   - **Validate**: All ~314 existing tests still pass (no regressions)

6. **U_SceneRegistry** (1-2 hours) - TDD REQUIRED
   - **Test First**: Write `tests/unit/scene_manager/test_scene_registry.gd`
   - Create `scripts/scene_management/u_scene_registry.gd` static class
   - Define scene metadata (paths, types, transitions, preload priority)
   - Define door pairing structure
   - Implement validation methods (`validate_door_pairings()`)
   - **Test Pass**: Registry tests pass
   - **Critical**: Add to registry: "gameplay_base", "main_menu", "settings_menu"

7. **M_SceneManager Core** (3-4 hours) - TDD REQUIRED
   - **Test First**: Write `tests/unit/scene_manager/test_m_scene_manager.gd`
   - Create `scripts/managers/m_scene_manager.gd` node
   - Implement `_ready()`: add to "scene_manager" group, find M_StateStore via `U_StateUtils.get_store()`
   - Implement **transition queue** with priority system:
     - Queue: Array of {scene_id, transition_type, priority}
     - Priority: CRITICAL (pause/death) > HIGH (menu) > NORMAL (doors)
     - Ignore duplicate transitions for same scene_id while queued
   - Implement `transition_to_scene(scene_id, transition_type, priority)`:
     - Check if transition already in progress → queue or ignore based on priority
     - Dispatch `U_SceneActions.transition_to()`
     - Load scene via ResourceLoader (sync) or ResourceLoader.load_threaded_* (async - Phase 3)
     - Remove old scene from ActiveSceneContainer (triggers StateHandoff preservation)
     - Add new scene to ActiveSceneContainer (triggers StateHandoff restoration)
     - Dispatch `U_SceneActions.transition_complete()`
   - Subscribe to scene slice updates via `M_StateStore.subscribe()`
   - **Test Pass**: M_SceneManager unit tests pass (including queue priority tests)

8. **Transition Effects** (2-3 hours) - TDD REQUIRED
   - **Test First**: Write `tests/unit/scene_manager/test_transitions.gd`
   - Create `scripts/scene_management/transitions/base_transition_effect.gd` base class
   - Implement `scripts/scene_management/transitions/instant_transition.gd`
   - Implement `scripts/scene_management/transitions/fade_transition.gd` with Tween
   - **Input Blocking**: Block input during transition (set_input_as_handled() in fade)
   - Update TransitionOverlay in root.tscn (ColorRect with modulate.a = 0)
   - Integrate with M_SceneManager.transition_to_scene()
   - **Test Pass**: Transition effect tests pass (including input blocking)

9. **Basic UI Scenes** (1-2 hours)
   - Create `scenes/ui/main_menu.tscn` (minimal: Label + Button to settings)
   - Create `scenes/ui/settings_menu.tscn` (minimal: Label + Button to main)
   - Add to U_SceneRegistry with correct paths and scene_ids
   - **Important**: These scenes do NOT have M_ECSManager (UI scenes, not gameplay)

10. **Integration Testing** (2-3 hours) - CRITICAL
   - Write `tests/integration/scene_manager/test_basic_transitions.gd`
     - Test: Load main_menu, transition to settings, transition back
     - Assert: Scene slice state updated correctly
   - Write `tests/integration/scene_manager/test_state_persistence.gd`
     - Test: Modify gameplay state, transition to menu, back to gameplay
     - Assert: Gameplay state preserved via StateHandoff
   - **Validate**: All tests pass (~314 existing + new scene manager tests)
   - **Manual Test**: Launch game → main menu → settings → back to main → gameplay_base
   - **Critical**: Verify debug overlay (F3) still works during transitions

11. **Edge Case Testing** (1-2 hours) - HIGH PRIORITY
   - Write `tests/integration/scene_manager/test_edge_cases.gd`
   - **Test Coverage**:
     - Scene loading fails (missing file) → fallback to main menu
     - Transition during transition (priority queue test)
     - Corrupted save file → warn player, start new game
     - Pause during transition → transition completes first
     - Low memory scenario → unload non-essential scenes
     - Door trigger while player in air → validate grounded state
     - Transition from within physics frame → defer to next frame
     - Unsaved progress on quit → trigger auto-save
   - **Test Pass**: All edge case tests pass

**Acceptance Criteria** (ALL MUST PASS):
- [ ] **Scene restructuring complete**: root.tscn is main scene, gameplay_base.tscn loads as child
- [ ] **No regressions**: ALL ~314 existing tests still pass (ECS + Redux + integration)
- [ ] **Scene state slice**: Registered in M_StateStore, actions/reducer working, transient fields excluded
- [ ] **M_SceneManager functional**: Can load/unload scenes via dispatch with priority queue
- [ ] **Fade transitions**: Work smoothly, no visual glitches, input blocked during transition
- [ ] **State persistence**: Gameplay state survives menu transitions (via StateHandoff)
- [ ] **New tests passing**: Scene slice, U_SceneRegistry, M_SceneManager, transitions, edge cases
- [ ] **Manual test**: menu → settings → menu → gameplay_base (with F3 debug overlay working)
- [ ] **Integration validation**: HUD updates, player moves, pause works in restructured scenes
- [ ] **Edge cases**: All 8 edge case scenarios tested and handled

**Commit Strategy** (After EACH Test-Green Milestone):
- Commit 1: Baseline test results (~314 passing) + research.md + data-model.md (Phase 0)
- Commit 2: Root scene created + gameplay_base extracted (restructuring)
- Commit 3: Integration validated (restructuring working, ~314 tests passing)
- Commit 4: Main scene switched to root.tscn
- Commit 5: Scene slice + actions + reducer (with tests, transient field test)
- Commit 6: U_SceneRegistry (with tests)
- Commit 7: M_SceneManager core with priority queue (with tests)
- Commit 8: Transition effects with input blocking (with tests)
- Commit 9: UI scenes + integration tests
- Commit 10: Edge case tests passing
- Commit 11: Phase 1 complete validation + documentation update

**⚠️ Important**: Do NOT commit if ANY test fails. Fix before committing.

---

### Phase 2: P2 Gameplay - Area Transitions, Pause & History (9-12 hours)

**Goal**: Implement gameplay area transitions and pause system (User Stories 3 & 4)

**Tasks**:

1. **Scene Stack Implementation** (2-3 hours)
   - Extend M_SceneManager with push_overlay/pop_overlay
   - Implement UIOverlayStack management
   - Sync scene_stack state with UIOverlayStack
   - Write unit tests

1b. **Scene History Navigation** (1-2 hours) - HIGH PRIORITY
   - Extend M_SceneManager with history tracking
   - **UI History Stack**: Separate from scene_stack, tracks UI navigation breadcrumbs
   - Implement `go_back()` function for UI scenes
   - Add history metadata to scene transitions (is_history_enabled)
   - UI scenes (menu, settings) automatically track history
   - Gameplay scenes explicitly disable history (FR-078)
   - Test: menu → settings → gameplay → back() returns to settings, not menu

2. **Pause System** (2-3 hours)
   - Create `pause_menu.tscn`
   - Implement pause trigger in M_SceneManager (push_overlay with "pause_menu")
   - Set `get_tree().paused = true` on pause
   - **M_CursorManager Integration**: Call `M_CursorManager.set_cursor_visible(true)` on pause
   - **M_CursorManager Integration**: Call `M_CursorManager.set_cursor_visible(false)` on unpause
   - Configure process_mode for pause-aware nodes
   - Test pause freezes gameplay (verify ECS systems stop processing)
   - Test unpause resumes exactly (no state drift)

3. **Area Transition Components** (2-3 hours)
   - Create `C_SceneTriggerComponent` (door_id, target, spawn_point)
   - Create `S_SceneTriggerSystem` (collision detection, input handling)
   - Extend U_SceneRegistry with door pairings
   - Implement spawn point restoration

4. **Gameplay Scenes** (1-2 hours)
   - Create `exterior_template.tscn` with M_ECSManager
   - Create `interior_template.tscn` with M_ECSManager
   - Add door triggers with C_SceneTriggerComponent
   - Add spawn point markers

5. **Integration Testing** (1 hour)
   - Write `test_pause_system.gd`
   - Write `test_area_transitions.gd`
   - Manual test: exterior → door → interior → exit → exterior
   - Verify pause during gameplay

**Acceptance Criteria**:
- [ ] Scene stack works (gameplay → pause → settings → back)
- [ ] Pause freezes gameplay, unpause resumes exactly
- [ ] Door triggers transition to correct scene with correct spawn point
- [ ] Player state persists through area transitions
- [ ] Tests passing: pause, area transitions
- [ ] Manual test: Full gameplay loop with pause and area transitions

**Commit Strategy**: Commit after each task (4-5 commits)

---

### Phase 3: P3 Polish - Transitions, Preloading, End-Game (5-7 hours)

**Goal**: Implement polish features (User Stories 5, 6, 7)

**Tasks**:

1. **Loading Screen Transition** (1-2 hours)
   - Create `loading_screen.tscn`
   - Implement `LoadingScreenTransition`
   - Add progress bar updates during async loading
   - Add LoadingOverlay to root.tscn

2. **Scene Preloading** (2-3 hours)
   - Implement preload on startup for high-priority scenes
   - Implement on-demand loading for gameplay scenes
   - Add memory management (unload unused scenes)
   - Add preload hints for next likely scene

3. **End-Game Scenes** (1-2 hours)
   - Create `game_over.tscn`
   - Create `victory.tscn`
   - Create `credits.tscn`
   - Implement retry/continue navigation

4. **Camera Blending** (1-2 hours)
   - Implement camera position/rotation/FOV blending
   - Add transition camera to M_SceneManager
   - Test smooth camera transitions

5. **Final Testing & Documentation** (1 hour)
   - Run full test suite
   - Create `quickstart.md` usage guide
   - Update AGENTS.md with Scene Manager patterns
   - Manual test: Full game loop (menu → gameplay → pause → end → menu)

**Acceptance Criteria**:
- [ ] Loading screen appears for long scene loads
- [ ] UI scenes preloaded at startup (fast transitions)
- [ ] End-game scenes work (game over, victory, credits)
- [ ] Camera transitions smoothly between scenes
- [ ] All tests passing (100%)
- [ ] Documentation complete (quickstart.md)
- [ ] Manual test: Full game loop validated

**Commit Strategy**: Commit after each task (5 commits), final commit for documentation

---

## Success Criteria

**Technical Success**:
- [ ] All 112 functional requirements implemented
- [ ] All 7 user stories have passing acceptance tests
- [ ] Scene transitions complete within performance targets (< 0.5s UI, < 3s gameplay)
- [ ] Memory stable across 20+ transitions (no leaks)
- [ ] Zero Godot autoloads added
- [ ] All tests passing (unit + integration)

**User Experience Success**:
- [ ] Players can complete full game loop without crashes
- [ ] Transitions feel responsive (no input lag)
- [ ] State persistence invisible to player (seamless)
- [ ] Loading screens only appear when necessary
- [ ] Pause system maintains exact game state

**Documentation Success**:
- [ ] PRD complete and accurate
- [ ] Plan document tracks phases
- [ ] Quickstart guide enables developers to use Scene Manager
- [ ] Code follows AGENTS.md patterns
- [ ] DEV_PITFALLS.md updated with scene-specific pitfalls

## Next Steps

1. **Start Phase 0**: Create research.md and data-model.md
2. **Validate Architecture**: Confirm camera blending approach, AsyncLoading patterns
3. **Begin Phase 1**: After Phase 0 approval, start with scene state slice
4. **Follow TDD**: Write tests → implement → verify → commit for each task
5. **Update Planning Docs**: Keep scene-manager-plan.md current as phases complete

## Critical Integration Details

### ActionRegistry Integration

Scene actions MUST register in `U_SceneActions._static_init()`:

```gdscript
static func _static_init() -> void:
    ActionRegistry.register_action(ACTION_TRANSITION_TO)
    ActionRegistry.register_action(ACTION_TRANSITION_COMPLETE)
    ActionRegistry.register_action(ACTION_PUSH_OVERLAY)
    ActionRegistry.register_action(ACTION_POP_OVERLAY)
```

### RS_StateSliceConfig for Scene Slice

In `M_StateStore._initialize_slices()`:

```gdscript
if scene_initial_state != null:
    var scene_config := RS_StateSliceConfig.new(StringName("scene"))
    scene_config.reducer = Callable(SceneReducer, "reduce")
    scene_config.initial_state = scene_initial_state.to_dictionary()
    scene_config.dependencies = []  # No dependencies
    scene_config.transient_fields = [StringName("is_transitioning")]  # Don't persist
    register_slice(scene_config)
```

### Signal Batching

Scene transitions emit via `U_StateEventBus` (batched per-frame). Systems can subscribe:

```gdscript
func _ready() -> void:
    var store: M_StateStore = U_StateUtils.get_store(self)
    store.subscribe(_on_state_changed)

func _on_state_changed(action: Dictionary, new_state: Dictionary) -> void:
    var scene_slice: Dictionary = new_state.get("scene", {})
    if action.get("type") == U_SceneActions.ACTION_TRANSITION_COMPLETE:
        # React to scene transitions
        pass
```

### Debug Overlay During Transitions

The F3 debug overlay must remain accessible:
- Overlay lives in root.tscn (persists)
- process_mode = PROCESS_MODE_ALWAYS (works during pause)
- Should display scene slice state during transitions

### Hot Reload Considerations

During development:
- Editing a loaded scene may cause Godot to reload it
- M_SceneManager should handle unexpected scene changes gracefully
- StateHandoff provides safety net if root.tscn reloads unexpectedly

## Notes

### Dependencies
- **M_StateStore** (implemented, WILL BE MODIFIED to add scene slice)
- **StateHandoff** (implemented, already handles state preservation)
- **M_ECSManager** (implemented, per-scene pattern maintained)
- **ActionRegistry** (implemented, scene actions will register)
- **GUT** (implemented, tests follow existing patterns)

### Breaking Changes (REVISED)
- ❌ **NOT an additive feature** - requires scene hierarchy restructuring
- ❌ **base_scene_template.tscn** demoted from main scene to gameplay template
- ❌ **project.godot** main scene will change to root.tscn
- ❌ **All debug/test scenes** may need updates to reference new structure
- ✅ **ECS/Redux functionality** preserved through careful migration
- ✅ **Backward compatibility** maintained during Phase 1 migration

### Migration Path
1. **Phase 0**: Prototype restructuring, validate ECS/Redux still work
2. **Phase 1**: Create root.tscn, extract gameplay_base.tscn, switch main scene
3. **Phase 1**: Keep base_scene_template.tscn for now (old scenes reference it)
4. **Phase 2+**: Gradually migrate debug/test scenes to new structure
5. **Future**: Remove base_scene_template.tscn once all scenes migrated

### Testing Strategy
- **GUT framework** for unit tests (scene slice, reducer, registry)
- **Integration tests** for scene transitions (must validate StateHandoff)
- **Manual validation** for each phase before committing
- **Regression testing** - ALL 174 existing tests must pass after restructuring
- **Performance testing** - measure actual vs target transition times

### Commit Discipline
- Follow AGENTS.md guidance: commit at logical milestones
- **NEVER commit with failing tests** - fix first
- Commit messages must reference phase/task (e.g., "Phase 1 Task 5: Scene slice")
- Update scene-manager-plan.md in commits as phases complete

## Audit Summary

**Audit Date**: 2025-10-27
**Audit Status**: ✅ **PASSED** - All critical and high-priority issues resolved
**Plan Quality**: B+ → A- (after revisions)

### Critical Issues Resolved
1. ✅ **Test Baseline Updated**: Changed from outdated 174 tests → current ~314 test methods
2. ✅ **Phase 1 Estimate Corrected**: 15-18 hours → 20-27 hours (matches task breakdown)
3. ✅ **Async Loading Research Added**: ResourceLoader.load_threaded_* pattern added to Phase 0

### High-Priority Issues Resolved
4. ✅ **Scene History Navigation Added**: FR-076 to FR-079 now covered in Phase 2, Task 1b
5. ✅ **M_CursorManager Integration**: Added to pause system (Phase 2, Task 2)
6. ✅ **Transition Priority Queue**: Detailed in Phase 1, Task 7 (CRITICAL > HIGH > NORMAL)
7. ✅ **Edge Case Testing**: Added Phase 1, Task 11 with all 8 PRD edge cases
8. ✅ **Input Blocking**: Added to Phase 1, Task 8 (transition effects)

### Additional Improvements
- ✅ Removed unnecessary scene_initial_state.tres file (programmatic initialization only)
- ✅ Added transient field exclusion test for save_state()
- ✅ Updated all test validation checkpoints to reference ~314 baseline
- ✅ Added process_mode and CanvasLayer research to Phase 0
- ✅ Clarified StateHandoff triggers on child scene unload (not root)

### Final Verification
- **PRD Coverage**: 98% → 100% (scene history added)
- **Functional Requirements**: 110/112 → 112/112 (FR-076 to FR-079 covered)
- **Time Estimates**: Consistent across all phases
- **Technical Accuracy**: Verified against actual codebase implementations
- **Commit Strategy**: Updated to reflect new tasks (11 commits in Phase 1)

**Implementation Status**: ✅ **READY FOR PHASE 0**

---

## Phase 12: Spawn System Architecture (Future Enhancement)

### Overview

**Status**: Phase 11 Complete, Phase 12 Planned
**Purpose**: Extract spawn/camera logic from M_SceneManager into dedicated M_SpawnManager

### Current Architecture Issues

**M_SceneManager Responsibilities** (as of Phase 11):
- Scene loading/unloading ✅ (Core responsibility)
- Scene transition queue management ✅ (Core responsibility)
- Transition effect execution ✅ (Core responsibility)
- UI overlay stack management ✅ (Core responsibility)
- **Player spawn point restoration** ⚠️ (Should be separate)
- **Camera positioning/blending** ⚠️ (Should be separate)
- State persistence coordination ✅ (Integration responsibility)
- Scene cache management ✅ (Core responsibility)
- Cursor state management ✅ (Integration responsibility)

**Coupling Issues**:
- 241 lines of spawn/camera logic embedded in M_SceneManager (106 spawn + 135 camera)
- Violates Single Responsibility Principle
- Difficult to add spawn features (checkpoints, effects, conditions)
- Camera blending tightly coupled to scene transitions

### Proposed Architecture

**M_SpawnManager** (Scene-based manager, added to root.tscn):

**Core Responsibilities**:
1. **Player Spawning**
   - Find player entity in scene
   - Find spawn point by ID
   - Validate spawn point (Node3D type, exists)
   - Position player at spawn point
   - Clear target spawn point from state

2. **Camera Coordination**
   - Initialize scene camera
   - Capture camera state before scene change
   - Coordinate camera blending during transitions
   - Manage transition camera lifecycle

3. **Checkpoint System** (Phase 12.3)
   - Register checkpoints (scene + spawn point)
   - Restore player at last checkpoint
   - Persist checkpoint in save files
   - Death respawn integration

4. **Advanced Spawn Features** (Phase 12.4)
   - Spawn effects (fade, particles)
   - Conditional spawning (quest/item/flag gates)
   - Spawn point metadata (priority, tags)
   - Spawn registry (lookup by tag/condition)

### Interface Design

**M_SpawnManager Public API**:
```gdscript
class_name M_SpawnManager extends Node

# Core spawning
func spawn_player_at_point(scene: Node, spawn_point_id: StringName) -> bool
func spawn_at_checkpoint() -> bool
func spawn_by_tag(scene_id: StringName, tag: String) -> bool

# Camera coordination
func initialize_scene_camera(scene: Node) -> Camera3D
func coordinate_camera_blend(old_scene: Node, new_scene: Node, duration: float) -> void

# Checkpoint management
func register_checkpoint(scene_id: StringName, spawn_point: StringName) -> void
func clear_checkpoint() -> void

# Validation
func validate_spawn_point(scene: Node, spawn_point_id: StringName) -> bool

# Signals
signal spawn_completed(success: bool)
signal checkpoint_registered(scene_id: StringName, spawn_point: StringName)
signal camera_blend_complete()
```

### Integration with M_SceneManager

**M_SceneManager Changes**:
```gdscript
# Add reference to spawn manager
var _spawn_manager: M_SpawnManager

func _ready() -> void:
    # Find spawn manager via group
    var spawn_managers := get_tree().get_nodes_in_group("spawn_manager")
    if spawn_managers.size() > 0:
        _spawn_manager = spawn_managers[0] as M_SpawnManager

func _perform_transition(...) -> void:
    # ... scene loading logic ...

    # Replace spawn logic with spawn manager call
    if _spawn_manager != null:
        var spawn_success := _spawn_manager.spawn_player_at_point(
            new_scene,
            target_spawn_point
        )
        if not spawn_success:
            push_warning("Spawn failed, player at default position")

    # Replace camera blending with spawn manager coordination
    if _spawn_manager != null and should_blend_camera:
        _spawn_manager.coordinate_camera_blend(
            old_scene,
            new_scene,
            transition_duration
        )
```

**Code Extracted from M_SceneManager**:
- `_restore_player_spawn_point()` → M_SpawnManager.spawn_player_at_point()
- `_find_spawn_point()` → M_SpawnManager._find_spawn_point()
- `_find_player_entity()` → M_SpawnManager._find_player_entity()
- `_clear_target_spawn_point()` → M_SpawnManager (internal)
- `_create_transition_camera()` → M_SpawnManager._create_transition_camera()
- `_capture_camera_state()` → M_SpawnManager._capture_camera_state()
- `_blend_camera()` → M_SpawnManager._blend_camera_internal()
- `_finalize_camera_blend()` → M_SpawnManager._finalize_camera_blend()
- `CameraState` class → M_SpawnManager (nested class)

### Benefits

**Separation of Concerns**:
- M_SceneManager: Scene transitions only (~1,171 lines, down from 1,412)
- M_SpawnManager: Player/camera spawning (~400 lines)
- Clear interface boundary between systems

**Extensibility**:
- Add spawn effects without modifying scene manager
- Conditional spawning based on game state
- Spawn point metadata and registry
- Multiple spawn strategies (checkpoint, tag-based, priority-based)

**Reusability**:
- Checkpoint system uses spawn manager
- Death respawn uses spawn manager
- Teleport system uses spawn manager
- Manual spawn triggers use spawn manager

**Testability**:
- Spawn logic isolated and independently testable
- Mock spawn manager in scene transition tests
- Comprehensive spawn validation tests
- Camera coordination tests separate from transition tests

### Implementation Phases

**Sub-Phase 12.1: Core Extraction** (8-10 hours)
- Extract player spawn logic
- M_SpawnManager in root.tscn
- Update M_SceneManager integration
- Test coverage: spawn validation

**Sub-Phase 12.2: Camera Integration** (6-8 hours)
- Extract camera blending coordination
- CameraState class moved
- Camera tests comprehensive

**Sub-Phase 12.3: Checkpoint System** (10-12 hours)
- Checkpoint registration/restoration
- Death respawn integration
- Save/load persistence
- C_CheckpointComponent + S_CheckpointSystem

**Sub-Phase 12.4: Advanced Features** (12-15 hours)
- Spawn effects (fade, particles)
- Conditional spawning (quest/item/flag)
- Spawn registry (U_SpawnRegistry)
- Spawn by tag/priority

### Testing Strategy

**New Test Coverage**:
- `tests/integration/spawn_system/test_spawn_manager.gd` (~200 lines)
- `tests/integration/spawn_system/test_camera_initialization.gd` (~150 lines)
- `tests/integration/spawn_system/test_checkpoint_system.gd` (~180 lines)
- `tests/unit/spawn_system/test_spawn_validation.gd` (~120 lines)

**Regression Testing**:
- All existing scene manager tests must pass
- No changes to scene transition behavior
- Camera blending identical to Phase 10 implementation

### Risk Assessment

**Low Risk**:
- Well-defined interface boundary
- No architectural changes to M_SceneManager
- Existing tests validate no regressions
- Can be implemented incrementally (4 sub-phases)

**Mitigations**:
- TDD approach (tests first)
- Keep camera blending in M_SceneManager until Sub-Phase 12.2
- Comprehensive regression testing after each sub-phase
- Manual validation of door transitions after each sub-phase

---

## Related Documentation

- [scene-manager-prd.md](./scene-manager-prd.md) - Full feature specification (v2.3)
- [AUDIT_REPORT.md](./AUDIT_REPORT.md) - Complete audit report with detailed findings
- [AGENTS.md](../../AGENTS.md) - Project conventions and repo map
- [DEV_PITFALLS.md](../general/DEV_PITFALLS.md) - Common pitfalls to avoid
- [STYLE_GUIDE.md](../general/STYLE_GUIDE.md) - Code style requirements
- [redux-state-store-prd.md](../state%20store/redux-state-store-prd.md) - State store architecture
