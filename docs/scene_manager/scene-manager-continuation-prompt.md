# Scene Manager – Quick Start for Humans

## Current Status: Phase 0 Preparation

**Branch**: `SceneManager`
**Last Updated**: 2025-10-27
**Implementation Status**: Planning complete, ready to begin Phase 0 (Research & Validation)

---

## Phase Progress Tracker

- [ ] **Phase 0**: Research & Architecture Validation (5-8 hours) ⚠️ **START HERE**
- [ ] **Phase 1**: Setup - Baseline Tests (30 min)
- [ ] **Phase 2**: Foundational - Scene Restructuring (5-6 hours) 🚨 **BLOCKS ALL USER STORIES**
- [ ] **Phase 3**: US1 - Basic Scene Transitions (7-9 hours)
- [ ] **Phase 4**: US2 - State Persistence (2-3 hours)
- [ ] **Phase 5**: US4 - Pause System (2-3 hours) ⚡ Moved up for risk management
- [ ] **Phase 6**: US3 - Area Transitions (2-3 hours) ⚡ Moved down - complex ECS
- [ ] **Phase 7**: US5 - Transition Effects (1-2 hours)
- [ ] **Phase 8**: US6 - Scene Preloading (2-3 hours)
- [ ] **Phase 9**: US7 - End-Game Flows (1-2 hours)
- [ ] **Phase 10**: Polish & Cross-Cutting (2-3 hours)

**Total Estimated**: 41-59 hours (includes 2-5 hours testing/documentation overhead)

---

## Before You Start

### ⚠️ CRITICAL: Phase 0 is a DECISION GATE

**DO NOT proceed to implementation without Phase 0 approval:**
1. Phase 0 prototypes MUST validate scene restructuring doesn't break ECS/Redux
2. If prototypes fail validation, STOP and reconsider architecture
3. DO NOT skip to Phase 1 without completing all Phase 0 validation criteria

**See Phase 0 section below for decision gate questions that determine if implementation can proceed.**

---

### 1. Review Project Foundations
- `AGENTS.md` - Project conventions and patterns
- `docs/general/DEV_PITFALLS.md` - Common mistakes to avoid
- `docs/general/STYLE_GUIDE.md` - Code style requirements

### 2. Review Scene Manager Documentation
- `docs/scene_manager/scene-manager-prd.md` - Full specification (7 user stories, 112 FRs)
- `docs/scene_manager/scene-manager-plan.md` - Implementation plan with phase breakdown
- `docs/scene_manager/scene-manager-tasks.md` - Task list (237 tasks: R001-R031, T001-T206)

### 3. Understand Existing Architecture
- `scripts/managers/m_state_store.gd` - Redux store (will be modified to add scene slice)
- `scripts/state/state_handoff.gd` - State preservation utility
- `scripts/managers/m_ecs_manager.gd` - Per-scene ECS manager pattern
- `templates/base_scene_template.tscn` - Current main scene (will be restructured)

### 4. Review Key Architectural Decisions

**Root Scene Pattern**:
- `root.tscn` will be new main scene (persists entire session)
- Contains: M_StateStore, M_SceneManager, M_CursorManager (persistent)
- Scenes load into `ActiveSceneContainer` as children (dynamic)

**Per-Scene ECS**:
- Each gameplay scene has its own M_ECSManager instance
- State preserved via M_StateStore "gameplay" slice + StateHandoff
- Components must unregister on scene unload

**Redux Integration**:
- Add "scene" slice to M_StateStore via FR-112
- M_SceneManager dispatches actions (U_SceneActions)
- SceneReducer handles state updates (immutable)
- Transient fields (is_transitioning) excluded from save

**No Autoloads**:
- Scene-tree-based discovery via groups ("scene_manager")
- Use U_StateUtils.get_store(self) to find M_StateStore
- Managers live in scenes, not autoload configuration

---

## Phase 0: Research & Validation (START HERE)

**Goal**: Validate architecture won't break existing systems before committing.

**Critical Gate**: Must pass ALL validation criteria to proceed to Phase 1.

### Tasks (R001-R031)

**Research & Documentation** (2-3 hours):
1. Research Godot 4.5 scene lifecycle, AsyncLoading pattern
2. Document findings in `docs/scene_manager/research.md`
3. Create `docs/scene_manager/data-model.md` with scene slice schema

**Prototypes** (3-5 hours):
1. **Scene Restructuring Prototype**: Create `scenes/root_prototype.tscn`, load base_scene_template as child
   - ✅ Validate: ECS still works (player moves, components register)
   - ✅ Validate: Redux still works (state updates, actions dispatch)
   - ✅ Validate: Can unload/reload without crashes
   - ❌ If broken, STOP and reconsider architecture

2. **Camera Blending Prototype**: Test Camera3D Tween interpolation (position, rotation, FOV)
   - ✅ Validate: Smooth transitions over 0.5s, no jitter
   - ❌ If too complex, descope camera blending

3. **Performance Baseline**: Measure scene load times, memory usage
   - ✅ Validate: Can achieve < 0.5s UI, < 3s gameplay targets
   - ❌ If too slow, adjust strategy

**Decision Gate Questions**:
1. Does scene restructuring break ECS or Redux? **(If yes, STOP)**
2. Can we achieve performance targets? **(If no, adjust or STOP)**
3. Is camera blending feasible? **(If too complex, descope)**
4. Is M_StateStore modification safe? **(If risky, reconsider)**

**Output**: `research.md` and `data-model.md` complete, all prototypes validated

---

## Phase 2 Warning: Restructuring Is High Risk

**Critical**: Phase 2 restructures the entire scene hierarchy.

**Current Structure** (base_scene_template.tscn = main scene):
```
base_scene_template.tscn
├── M_StateStore      ← Will move to root
├── M_ECSManager      ← Will stay per-scene
├── M_CursorManager   ← Will move to root
├── Systems/          ← Will stay in gameplay scenes
├── Entities/         ← Will stay in gameplay scenes
└── HUD               ← Must use U_StateUtils.get_store()
```

**Target Structure** (root.tscn = new main scene):
```
root.tscn
├── M_StateStore           ← Persistent forever
├── M_SceneManager         ← Persistent forever (NEW)
├── M_CursorManager        ← Persistent forever
└── ActiveSceneContainer   ← Where gameplay_base.tscn loads

gameplay_base.tscn (loads as child)
├── M_ECSManager      ← Per-scene instance
├── Systems/
├── Entities/
└── HUD               ← Finds M_StateStore via tree walk
```

**Test Baseline**: Before restructuring, ALL ~314 existing tests must pass. After restructuring, ALL 314 must still pass.

**If ANY test fails after restructuring, STOP and fix before proceeding.**

---

## Key Implementation Patterns

### 1. Scene State Slice (Phase 3)

```gdscript
# RS_SceneInitialState.gd
extends Resource
class_name RS_SceneInitialState

@export var current_scene_id: String = ""
@export var scene_stack: Array[String] = []
@export var is_transitioning: bool = false  # Transient field

func to_dictionary() -> Dictionary:
    return {
        "current_scene_id": current_scene_id,
        "scene_stack": scene_stack.duplicate(),
        "is_transitioning": is_transitioning
    }
```

### 2. Scene Actions (Phase 3)

```gdscript
# U_SceneActions.gd
extends RefCounted
class_name U_SceneActions

const ACTION_TRANSITION_TO := StringName("scene/transition_to")
const ACTION_TRANSITION_COMPLETE := StringName("scene/transition_complete")
const ACTION_PUSH_OVERLAY := StringName("scene/push_overlay")
const ACTION_POP_OVERLAY := StringName("scene/pop_overlay")

static func _static_init() -> void:
    ActionRegistry.register_action(ACTION_TRANSITION_TO)
    ActionRegistry.register_action(ACTION_TRANSITION_COMPLETE)
    ActionRegistry.register_action(ACTION_PUSH_OVERLAY)
    ActionRegistry.register_action(ACTION_POP_OVERLAY)

static func transition_to(scene_id: String, transition_type: String = "fade") -> Dictionary:
    return {
        "type": ACTION_TRANSITION_TO,
        "payload": {"scene_id": scene_id, "transition_type": transition_type}
    }

static func transition_complete(scene_id: String) -> Dictionary:
    return {
        "type": ACTION_TRANSITION_COMPLETE,
        "payload": {"scene_id": scene_id}
    }

static func push_overlay(scene_id: String) -> Dictionary:
    return {
        "type": ACTION_PUSH_OVERLAY,
        "payload": {"scene_id": scene_id}
    }

static func pop_overlay() -> Dictionary:
    return {
        "type": ACTION_POP_OVERLAY,
        "payload": null
    }
```

### 3. Scene Reducer (Phase 3)

```gdscript
# SceneReducer.gd
static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
    var action_type: StringName = action.get("type", StringName())

    match action_type:
        U_SceneActions.ACTION_TRANSITION_TO:
            var new_state: Dictionary = state.duplicate(true)
            new_state["is_transitioning"] = true
            return new_state

        U_SceneActions.ACTION_TRANSITION_COMPLETE:
            var new_state: Dictionary = state.duplicate(true)
            var payload: Dictionary = action.get("payload", {})
            new_state["current_scene_id"] = payload.get("scene_id", "")
            new_state["is_transitioning"] = false
            return new_state

        U_SceneActions.ACTION_PUSH_OVERLAY:
            var new_state: Dictionary = state.duplicate(true)
            var payload: Dictionary = action.get("payload", {})
            var scene_id: String = payload.get("scene_id", "")
            if not scene_id.is_empty():
                var stack: Array = new_state.get("scene_stack", []).duplicate()
                stack.append(scene_id)
                new_state["scene_stack"] = stack
            return new_state

        U_SceneActions.ACTION_POP_OVERLAY:
            var new_state: Dictionary = state.duplicate(true)
            var stack: Array = new_state.get("scene_stack", []).duplicate()
            if not stack.is_empty():
                stack.pop_back()
            new_state["scene_stack"] = stack
            return new_state

        _:
            return state
```

### 4. M_StateStore Modification (Phase 3, Task T033)

```gdscript
# Add to M_StateStore
@export var scene_initial_state: RS_SceneInitialState

func _initialize_slices() -> void:
    # ... existing boot, menu, gameplay registrations ...

    if scene_initial_state != null:
        var scene_config := StateSliceConfig.new(StringName("scene"))
        scene_config.reducer = Callable(SceneReducer, "reduce")
        scene_config.initial_state = scene_initial_state.to_dictionary()
        scene_config.dependencies = []
        scene_config.transient_fields = [StringName("is_transitioning")]
        register_slice(scene_config)
```

### 5. M_SceneManager Pattern (Phase 3)

```gdscript
# M_SceneManager.gd
extends Node
class_name M_SceneManager

var _state_store: M_StateStore = null

func _ready() -> void:
    add_to_group("scene_manager")
    _state_store = U_StateUtils.get_store(self)
    _state_store.subscribe(_on_state_changed)

    # Validate door pairings at startup
    if not SceneRegistry.validate_door_pairings():
        push_error("SceneRegistry door pairings invalid!")

func transition_to_scene(scene_id: String, transition_type: String = "fade") -> void:
    _state_store.dispatch(U_SceneActions.transition_to(scene_id, transition_type))
    await _perform_transition(scene_id, transition_type)
    _state_store.dispatch(U_SceneActions.transition_complete(scene_id))
```

---

## Critical Constraints

### Must Follow
- ❌ **NO autoloads** - Scene-tree-based discovery only
- ✅ **Per-scene ECS** - Each gameplay scene has own M_ECSManager
- ✅ **TDD Required** - Write tests FIRST, watch fail, then implement
- ✅ **Immutable State** - Always use .duplicate(true) in reducers
- ✅ **StateHandoff** - Automatically preserves state across transitions
- ✅ **Test Baseline** - All ~314 tests must pass after restructuring

### Test Discipline
1. Write test FIRST (T025, T068, T101, etc.)
2. Run test, watch it FAIL
3. Implement minimal code to pass
4. Run test, watch it PASS
5. Commit with test-green state
6. Never commit with failing tests

---

## Task Numbering Note

**Intentional "Backwards" Numbering**: Phase 5 starts at T101, Phase 6 uses T080-T100. This is because US4 (Pause) and US3 (Area Transitions) were reordered after initial task numbering for risk management.

**Execution Order**: Phase 0 (R001-R031) → Phase 1 (T001-T002) → Phase 2 (T003-T024) → Phase 3 (T025-T067) → Phase 4 (T068-T079) → **Phase 5 (T101-T128)** → **Phase 6 (T080-T100)** → Phase 7 (T129-T144) → Phase 8 (T145-T161) → Phase 9 (T162-T177) → Phase 10 (T178-T206)

---

## Common Pitfalls

### During Scene Restructuring (Phase 2)
❌ **Forgetting to update HUD** - HUD must use U_StateUtils.get_store() instead of get_parent()
❌ **Skipping test validation** - Must verify ALL 314 tests pass after restructuring
❌ **Changing project.godot too early** - Only switch main scene after validation
❌ **Not using await** - U_StateUtils.get_store() may need await if store not ready

### During Implementation
❌ **Mutating state directly** - Always use .duplicate(true) in reducers
❌ **Forgetting transient fields** - Mark is_transitioning as transient in slice config
❌ **Not validating door pairings** - Call SceneRegistry.validate_door_pairings() at startup
❌ **Hardcoding paths** - Use SceneRegistry for all scene metadata
❌ **Skipping ActionRegistry** - All actions must register in _static_init()

### Testing
❌ **Implementing before testing** - TDD is mandatory, not optional
❌ **Not testing edge cases** - All 8 edge cases (T184-T191) must have tests:
  - **T184**: Scene loading fails (missing file) → fallback to main menu
  - **T185**: Transition during transition → priority queue handles correctly
  - **T186**: Corrupted save file → warn player, offer new game
  - **T187**: Pause during transition → transition completes first
  - **T188**: Low memory scenario → unload non-essential scenes
  - **T189**: Door trigger while player in air → validate grounded state
  - **T190**: Transition from within physics frame → defer to next frame
  - **T191**: Unsaved progress on quit → trigger auto-save
❌ **Ignoring test failures** - Fix immediately, never commit with red tests
❌ **Not testing transient fields** - Verify is_transitioning excluded from save_state()

---

## Next Steps (Phase 0)

1. **Read the plan**: `scene-manager-plan.md` Phase 0 section (lines 307-386)
2. **Read the tasks**: `scene-manager-tasks.md` Phase 0 (R001-R031)
3. **Start research**: Create `research.md` and begin Godot 4.5 pattern research
4. **Build prototypes**: Validate scene restructuring, camera blending, performance
5. **Decision gate**: Pass all 4 validation questions or STOP
6. **Document findings**: Complete research.md and data-model.md
7. **Get approval**: Review Phase 0 output before proceeding to Phase 1

**If Phase 0 passes**: Proceed to Phase 1 (baseline tests) → Phase 2 (restructuring)
**If Phase 0 fails**: Reconsider architecture, adjust approach, or descope features

---

## Quick Reference

**Documentation**:
- PRD: `docs/scene_manager/scene-manager-prd.md` (v2.3 - 112 FRs, 7 user stories)
- Plan: `docs/scene_manager/scene-manager-plan.md` (10 phases, audit complete)
- Tasks: `docs/scene_manager/scene-manager-tasks.md` (237 tasks, reordered for risk)

**Key Files to Understand**:
- `scripts/managers/m_state_store.gd` - Redux store (will modify)
- `scripts/state/state_handoff.gd` - State preservation (existing)
- `scripts/managers/m_ecs_manager.gd` - Per-scene ECS (existing pattern)
- `scripts/utils/u_state_utils.gd` - Store discovery utilities
- `templates/base_scene_template.tscn` - Current main scene

**Test Baseline**: Run all tests, expect ~314 passing. Document exact count.

---

## Phase Completion Checkpoints

After each phase, verify:
- [ ] All tasks for phase complete
- [ ] All tests passing (unit + integration + existing baseline)
- [ ] Documentation updated (research.md, quickstart.md as appropriate)
- [ ] Manual validation performed (in-game testing)
- [ ] Committed with descriptive message
- [ ] Ready for next phase or STOP if validation fails

**Remember**: This is a 35-50 hour commitment with HIGH RISK during restructuring. Phase 0 validation is critical. If prototypes fail, reconsider before proceeding.

Good luck! 🚀
