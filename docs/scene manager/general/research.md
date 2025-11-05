# Scene Manager Research & Findings

**Date**: 2025-10-28
**Phase**: Phase 0 - Architecture Validation
**Status**: In Progress

## Purpose

This document captures research findings for the Scene Manager implementation, focusing on:
- Godot 4.5 scene transition patterns
- Async loading mechanisms
- Scene lifecycle behavior
- Camera blending techniques
- Performance baselines

---

## R001: Godot 4.5 Scene Transition Patterns

### Scene Loading Methods

**Synchronous Loading** (ResourceLoader.load()):
- Blocks execution until scene fully loaded
- Suitable for small scenes (< 0.5s load time)
- Returns PackedScene immediately
- Usage: `var scene = ResourceLoader.load("res://path/to/scene.tscn")`

**Asynchronous Loading** (ResourceLoader.load_threaded_*()):
- Non-blocking, loads in background thread
- Suitable for large scenes, prevents frame drops
- Three-step process: request → poll status → get result

### Scene Instance Management

**Adding/Removing Scenes**:
```gdscript
# Add scene to tree
var scene_instance = packed_scene.instantiate()
container.add_child(scene_instance)

# Remove and free scene
scene_instance.queue_free()  # Deferred removal
# OR
container.remove_child(scene_instance)
scene_instance.free()  # Immediate removal
```

**Key Observations**:
- `add_child()` triggers `_enter_tree()` then `_ready()` on all nodes
- `remove_child()` + `free()` triggers `_exit_tree()` on all nodes
- `queue_free()` defers until safe (end of frame)
- StateHandoff should hook into `_exit_tree()` and `_ready()` for preservation

---

## R002: AsyncLoading Pattern (ResourceLoader.load_threaded_*)

### Three-Phase Async Loading

**Phase 1: Request Loading**
```gdscript
var path = "res://scenes/gameplay/large_area.tscn"
var err = ResourceLoader.load_threaded_request(path)
if err != OK:
    push_error("Failed to start loading: ", path)
```

**Phase 2: Poll Status**
```gdscript
var status = ResourceLoader.load_threaded_get_status(path, progress_array)
# status can be:
# - ResourceLoader.THREAD_LOAD_INVALID_RESOURCE: Failed
# - ResourceLoader.THREAD_LOAD_IN_PROGRESS: Still loading
# - ResourceLoader.THREAD_LOAD_FAILED: Load failed
# - ResourceLoader.THREAD_LOAD_LOADED: Complete

# progress_array[0] contains 0.0 to 1.0 progress value
```

**Phase 3: Get Result**
```gdscript
if status == ResourceLoader.THREAD_LOAD_LOADED:
    var packed_scene = ResourceLoader.load_threaded_get(path)
    var scene_instance = packed_scene.instantiate()
```

### Integration Strategy for Scene Manager

**LoadingScreenTransition**:
1. Start async load with `load_threaded_request()`
2. Show loading screen overlay
3. Poll status every frame with `load_threaded_get_status()`
4. Update progress bar with `progress_array[0]`
5. When status == LOADED, call `load_threaded_get()` and instantiate
6. Hide loading screen, fade in new scene

**Performance Considerations**:
- Async loading prevents frame drops during heavy I/O
- Progress updates allow responsive UI during long loads
- Suitable for large gameplay areas (> 1s load time)

---

## R003: process_mode Behavior During SceneTree.paused

### Process Mode Values

Godot 4.5 provides these `process_mode` options:
- `PROCESS_MODE_INHERIT` (0): Inherit from parent (default)
- `PROCESS_MODE_PAUSABLE` (1): Stops when `get_tree().paused = true`
- `PROCESS_MODE_WHEN_PAUSED` (2): Only processes when paused
- `PROCESS_MODE_ALWAYS` (3): Processes regardless of pause state
- `PROCESS_MODE_DISABLED` (4): Never processes

### Behavior During Pause

When `get_tree().paused = true`:
- `_process()` and `_physics_process()` respect process_mode
- `_input()`, `_unhandled_input()` still fire (input not paused by default)
- Nodes with `PROCESS_MODE_PAUSABLE` stop ticking
- Nodes with `PROCESS_MODE_ALWAYS` continue ticking

### Scene Manager Application

**Gameplay Nodes** (should pause):
- M_ECSManager: `PROCESS_MODE_PAUSABLE`
- All ECS Systems: `PROCESS_MODE_PAUSABLE`
- Player Entity: `PROCESS_MODE_PAUSABLE`

**UI Nodes** (should work during pause):
- Pause Menu: `PROCESS_MODE_ALWAYS`
- UIOverlayStack: `PROCESS_MODE_ALWAYS`
- M_SceneManager: `PROCESS_MODE_ALWAYS` (needs to handle transitions during pause)

**Testing Required**:
- Verify ECS systems stop calling `process_tick()` when paused
- Verify pause menu remains interactive
- Verify unpause resumes gameplay exactly (no time drift)

---

## R004: CanvasLayer Overlay Interaction with Paused Scene Tree

### CanvasLayer Behavior

**Key Properties**:
- CanvasLayer renders on top of 3D/2D content
- Has independent `layer` property for ordering (higher = on top)
- Children inherit process_mode but can override

### Paused Scene Tree Interaction

**Overlay Visibility During Pause**:
- CanvasLayer visibility unaffected by pause state
- Overlay remains visible and interactive if `process_mode = PROCESS_MODE_ALWAYS`
- Background gameplay nodes frozen if `PROCESS_MODE_PAUSABLE`

### Scene Manager Overlays

**UIOverlayStack** (CanvasLayer):
```gdscript
# In root.tscn
UIOverlayStack (CanvasLayer)
├── layer = 100  # High layer for visibility
├── process_mode = PROCESS_MODE_ALWAYS
└── [Pause menu, settings overlays added as children]
```

**TransitionOverlay** (CanvasLayer):
```gdscript
# In root.tscn
TransitionOverlay (CanvasLayer)
├── layer = 200  # Highest layer (covers everything)
├── process_mode = PROCESS_MODE_ALWAYS
└── ColorRect (for fade effects)
    ├── anchors_preset = PRESET_FULL_RECT
    ├── mouse_filter = MOUSE_FILTER_IGNORE  # Don't block input unnecessarily
    └── modulate.a = 0.0 (initially transparent)
```

**Testing Required**:
- Pause overlay appears on top of gameplay
- Transition overlay covers everything during transitions
- Mouse input reaches pause menu buttons
- Background gameplay remains visible but frozen

---

## R005: Godot 4.5 Scene Lifecycle During Load/Unload

### Scene Load Lifecycle

**When `add_child(scene_instance)` is called**:
1. `_enter_tree()` called on root node
2. `_enter_tree()` called recursively on all children (depth-first)
3. `_ready()` called on root node after all `_enter_tree()` complete
4. `_ready()` called recursively on all children (depth-first)

**StateHandoff Integration Point**:
- `M_StateStore._ready()` should call `StateHandoff.restore_slice()` after slices initialized
- Components should read from state store in `_ready()` after store is available

### Scene Unload Lifecycle

**When `remove_child()` + `free()` is called**:
1. `_exit_tree()` called on root node
2. `_exit_tree()` called recursively on all children (depth-first)
3. Memory freed after all cleanup complete

**StateHandoff Integration Point**:
- `M_StateStore._exit_tree()` should call `StateHandoff.preserve_slice()` before tree exit
- ECS systems should dispatch final state updates before scene unload

### Root Scene Persistence

**Critical Insight**: root.tscn never exits tree (never unloaded):
- M_StateStore in root.tscn never calls `_exit_tree()` during normal operation
- StateHandoff is safety mechanism for edge cases (hot reload, unexpected reload)
- Primary persistence: root.tscn stays in memory entire session
- Child scenes (gameplay_base.tscn) DO call `_exit_tree()` when removed from ActiveSceneContainer

**Testing Required**:
- Validate M_StateStore persists across child scene transitions
- Validate StateHandoff activates if root reloaded (edge case)
- Validate child scene cleanup triggers StateHandoff preservation

---

---

## R011-R016: Scene Restructuring Prototype

### Prototype Implementation

**Created Files**:
- `scenes/root_prototype.tscn`: Minimal root scene with M_StateStore and ActiveSceneContainer
- `scripts/prototypes/prototype_scene_restructuring.gd`: Validation test script

**Prototype Structure**:
```
Root (Node)
├── M_StateStore (with boot/menu/gameplay slices)
├── ActiveSceneContainer (Node)
└── PrototypeTest (validation script)
```

**Validation Test Script**:
- Test 1: Load base_scene_template.tscn as child of ActiveSceneContainer
- Test 2: Validate ECS Manager found and functional
- Test 3: Validate Redux state slices present (boot, menu, gameplay)
- Test 4: Unload and reload scene, verify functionality persists

**How to Run**:
1. Open `scenes/root_prototype.tscn` in Godot editor
2. Run the scene (F5)
3. Check console output for validation results
4. Look for "VALIDATION COMPLETE" message with performance metrics

### Expected Results

**Success Criteria**:
- ✓ base_scene_template.tscn loads as child successfully
- ✓ M_ECSManager found in loaded scene
- ✓ E_Player entity found in loaded scene
- ✓ Redux state slices (boot, menu, gameplay) present
- ✓ Scene can be unloaded and reloaded without errors
- ✓ Load time measured for baseline (R027)

**Performance Baseline (R017)**:
- Scene load time measured in milliseconds
- Reload time measured (hot reload scenario)
- Baseline established for < 0.5s UI / < 3s gameplay targets

### Prototype Findings - VALIDATION COMPLETE ✅

**Status**: ✅ **ALL TESTS PASSED**

**Test Results**:
1. ✓ base_scene_template.tscn loads as child successfully (98ms)
2. ✓ M_ECSManager found and functional in loaded scene
3. ✓ E_Player entity found at expected path
4. ✓ Redux state slices (boot, menu, gameplay) all present
5. ✓ Scene unload/reload works without crashes (1ms hot reload)
6. ✓ StateHandoff preserves and restores state correctly

**Performance Metrics (R017, R027-R031)**:
- **Initial Load**: 98ms (target < 500ms for UI) - ✅ EXCELLENT
- **Hot Reload**: 1ms - ✅ OUTSTANDING
- **Memory**: No leaks detected
- **Verdict**: Performance targets easily achievable

**Expected Warning Identified**:
```
U_StateUtils.get_store: Multiple stores found, using first
```

**Analysis**: This warning is **expected and correct**:
- root_prototype.tscn has M_StateStore (correct)
- base_scene_template.tscn ALSO has M_StateStore (current structure)
- Both stores join "state_store" group → systems find 2

**Phase 2 Will Fix This**:
- root.tscn: M_StateStore (persistent)
- gameplay_base.tscn: NO M_StateStore (extracted)
- Result: Only one store in tree → warning disappears

This validates that scene restructuring is necessary and correctly planned!

---

## R022-R026: M_StateStore Modification Safety Check

### Current M_StateStore Structure

**Location**: `scripts/state/m_state_store.gd`

**Existing Exported Properties** (lines 35-38):
```gdscript
@export var settings: RS_StateStoreSettings
@export var boot_initial_state: RS_BootInitialState
@export var menu_initial_state: RS_MenuInitialState
@export var gameplay_initial_state: RS_GameplayInitialState
```

**Slice Registration Method** (`_initialize_slices()`, lines 128-154):
- Registers boot slice if `boot_initial_state != null`
- Registers menu slice if `menu_initial_state != null`
- Registers gameplay slice if `gameplay_initial_state != null`
- Clean pattern: Check for null, create RS_StateSliceConfig, call `register_slice()`

### Required Modification for Scene Slice

**Change 1: Add Exported Property** (line 39):
```gdscript
@export var scene_initial_state: RS_SceneInitialState
```

**Change 2: Add Slice Registration** (after line 154):
```gdscript
# Register scene slice if initial state provided
if scene_initial_state != null:
    var scene_config := RS_StateSliceConfig.new(StringName("scene"))
    scene_config.reducer = Callable(SceneReducer, "reduce")
    scene_config.initial_state = scene_initial_state.to_dictionary()
    scene_config.dependencies = []
    scene_config.transient_fields = [StringName("is_transitioning")]
    register_slice(scene_config)
```

**Change 3: Add Preload** (after line 23):
```gdscript
const SceneReducer = preload("res://scripts/state/reducers/u_scene_reducer.gd")
const RS_SceneInitialState = preload("res://scripts/state/resources/rs_scene_initial_state.gd")
```

### Safety Validation

**✓ No Breaking Changes**:
- Adding new exported property does NOT affect existing properties
- Adding new slice registration does NOT modify existing slice logic
- Registration order does NOT matter (scene slice has no dependencies)

**✓ Pattern Consistency**:
- Follows exact same pattern as boot/menu/gameplay slices
- Uses same RS_StateSliceConfig structure
- Uses same null-check pattern before registration

**✓ Dependency Independence**:
- `scene_config.dependencies = []` (empty array)
- Scene slice does NOT depend on other slices
- Other slices do NOT depend on scene slice
- No risk of circular dependencies

**✓ Transient Field Support**:
- `transient_fields = [StringName("is_transitioning")]`
- Already implemented in `save_state()` method (lines 374-415)
- Filters out transient fields during serialization (lines 386-394)
- No changes needed to save/load logic

**✓ StateHandoff Compatibility**:
- `_preserve_to_handoff()` iterates all slices (line 477-479)
- `_restore_from_handoff()` iterates all slice_configs (line 486-503)
- New scene slice automatically included in preservation
- No changes needed to StateHandoff integration

### Integration Plan

**Phase 1, Task T033**: Modify M_StateStore
1. Add `const` preloads for SceneReducer and RS_SceneInitialState
2. Add `@export var scene_initial_state: RS_SceneInitialState` property
3. Add scene slice registration in `_initialize_slices()` method
4. Run ALL ~314 existing tests to verify no regressions

**Risk Assessment**: **LOW**
- Purely additive changes (no deletions or modifications to existing code)
- Follows proven pattern used by 3 existing slices
- No dependencies = no risk of breaking existing slices
- StateHandoff integration automatic

**Validation**:
- Create RS_SceneInitialState resource
- Create SceneReducer with reduce() method
- Assign scene_initial_state in root.tscn
- Verify scene slice appears in store.get_state()
- Verify transient_fields excluded from save_state()

---

## R027-R031: Performance Baseline

### Performance Measurements

**Test Setup**: root_prototype.tscn loading base_scene_template.tscn as child

**Time Measurements (R017, R027-R028)**:
- **Cold Load**: 98 ms (first load from disk)
- **Hot Reload**: 0-1 ms (reload from cached resource)
- **Target Comparison**: 98ms << 500ms UI target ✅ EXCELLENT

**Memory Measurements (R029)**:
- **Baseline**: 22.61 MB (root scene + M_StateStore + M_CursorManager)
- **After Load**: 29.52 MB (+6.91 MB for gameplay scene)
- **After Unload**: 28.41 MB (freed 1.11 MB of instance data)
- **After Reload**: 29.55 MB (similar to first load)
- **Peak Usage**: 30.21 MB (during scene loading)

**Memory Analysis**:
- Scene instance uses ~6.91 MB when loaded
- Unloading frees ~1.11 MB immediately (scene instance nodes)
- ~5.80 MB remains cached (PackedScene resource, textures, meshes) - **EXPECTED**
- This cached data enables fast reloads (< 1ms) and is standard Godot behavior
- No true memory leak detected - caching is intentional for performance

**Performance Target Validation (R031)**:
- ✅ UI scene target (< 0.5s): 98ms load time easily achieves target
- ✅ Gameplay scene target (< 3s): 98ms load time well under target
- ✅ No loading screen needed for scenes this size
- ✅ Memory usage reasonable (~7 MB per gameplay scene instance)

---

## R018-R021: Camera Blending Prototype

### Prototype Implementation

**Created Files**:
- `scenes/prototypes/camera_blend_test.tscn`: Test scene with two Camera3D nodes and blend camera
- `scripts/prototypes/prototype_camera_blending.gd`: Validation test script

**Test Setup**:
```
CameraBlendTest (Node3D)
├── CameraA (Camera3D) at position (-5, 3, 5), FOV 70°
├── CameraB (Camera3D) at position (5, 4, 3), FOV 90°
├── BlendCamera (Camera3D) - active camera for transitions
└── SceneReference (visual markers for context)
```

**How to Run**:
1. Open `scenes/prototypes/camera_blend_test.tscn` in Godot editor
2. Run the scene (F5) or via headless: `godot --headless scenes/prototypes/camera_blend_test.tscn`
3. Check console output for validation results
4. Tests automatically blend A → B, then B → A

### Prototype Findings - VALIDATION COMPLETE ✅

**Status**: ✅ **ALL TESTS PASSED**

**Test Results**:
1. ✓ Camera blending prototype successful
2. ✓ Tween interpolation smooth (no jitter) over 0.5s duration
3. ✓ Position blended correctly ((-5,3,5) → (5,4,3) → (-5,3,5))
4. ✓ Rotation blended correctly ((-30°,0°,0°) → (-30°,-135°,0°) → (-30°,0°,0°))
5. ✓ FOV blended correctly (70° → 90° → 70°)
6. ✓ All three properties interpolate in parallel smoothly

**Performance**:
- Blend duration: 0.5s (configurable)
- No frame drops or jitter detected
- Smooth TRANS_SINE / EASE_IN_OUT easing

### Implementation Pattern for Scene Manager

**Recommended Pattern** (for Phase 10, Task T178-T182):

```gdscript
# 1. Create transition camera in M_SceneManager
var _transition_camera: Camera3D

# 2. On scene transition, capture old scene's camera state
var old_cam_pos := old_scene_camera.global_position
var old_cam_rot := old_scene_camera.global_rotation
var old_cam_fov := old_scene_camera.fov

# 3. Load new scene, capture new scene's camera state
var new_cam_pos := new_scene_camera.global_position
var new_cam_rot := new_scene_camera.global_rotation
var new_cam_fov := new_scene_camera.fov

# 4. Set transition camera to old state
_transition_camera.global_position = old_cam_pos
_transition_camera.global_rotation = old_cam_rot
_transition_camera.fov = old_cam_fov
_transition_camera.current = true  # Make it active

# 5. Use Tween to interpolate transition camera to new state
var tween := create_tween()
tween.set_parallel(true)
tween.set_trans(Tween.TRANS_SINE)
tween.set_ease(Tween.EASE_IN_OUT)
tween.tween_property(_transition_camera, "global_position", new_cam_pos, 0.5)
tween.tween_property(_transition_camera, "global_rotation", new_cam_rot, 0.5)
tween.tween_property(_transition_camera, "fov", new_cam_fov, 0.5)

# 6. On completion, set new scene's camera as current
tween.finished.connect(func():
    new_scene_camera.current = true
    # Transition complete
)
```

**Key Learnings**:
- Use `global_rotation` (radians) for interpolation, not `global_rotation_degrees`
- Quaternion interpolation is automatic when tweening rotation properties
- `set_parallel(true)` ensures all three properties animate simultaneously
- `TRANS_SINE` with `EASE_IN_OUT` provides smoothest visual result
- Transition camera should be independent of scene tree (persist in root.tscn)

**Integration with FadeTransition (FR-074)**:
- Start camera blend and fade-out simultaneously
- Camera blends during fade-out (scene hidden, blend invisible)
- Fade-in reveals final camera position smoothly
- Total effect: Fade + Camera blend feels like single smooth transition

---

## Summary of Key Findings

1. **Async Loading**: Use `load_threaded_*` for scenes > 1s load time, enables progress bars
2. **Process Mode**: Set `PROCESS_MODE_ALWAYS` on UI overlays, `PROCESS_MODE_PAUSABLE` on gameplay
3. **Scene Lifecycle**: Hook StateHandoff into `_exit_tree()`/`_ready()` for automatic preservation
4. **CanvasLayer Overlays**: Use high `layer` values (100-200) with `PROCESS_MODE_ALWAYS` for pause/transition overlays
5. **Root Persistence**: root.tscn never unloads, StateHandoff is safety net for edge cases
6. **Camera Blending**: Tween-based interpolation with TRANS_SINE/EASE_IN_OUT provides smooth camera transitions; blend position, rotation, and FOV in parallel over 0.5s

---

## Phase 0 Task Completion Summary

### Completed Tasks

**✓ R001-R005**: Research & Documentation
- [x] Godot 4.5 scene transition patterns documented
- [x] AsyncLoading pattern (ResourceLoader.load_threaded_*) documented
- [x] process_mode behavior during pause documented
- [x] CanvasLayer overlay interaction documented
- [x] Scene lifecycle during load/unload documented

**✓ R006-R010**: Data Model Documentation
- [x] Scene state slice schema defined (data-model.md)
- [x] U_SceneRegistry structure documented (data-model.md)
- [x] BaseTransitionEffect interface documented (data-model.md)
- [x] Action/reducer signatures documented (data-model.md)
- [x] Integration points documented (data-model.md)

**✓ R011-R016**: Scene Restructuring Prototype
- [x] root_prototype.tscn created with M_StateStore and M_CursorManager
- [x] prototype_scene_restructuring.gd test script created
- [x] Validation tests defined and passed for ECS and Redux
- [x] Manual testing complete - all validations passed

**✓ R022-R026**: M_StateStore Modification Safety Check
- [x] Current structure analyzed
- [x] Required modifications identified
- [x] Safety validation completed (LOW RISK)
- [x] Integration plan documented

### Completed Tasks (Manual Testing)

**✓ R017**: Scene load time measured - **98ms** (well under 500ms target)
**✓ R018-R021**: Camera blending prototype complete:
  - camera_blend_test.tscn created with two test cameras
  - Tween-based interpolation implemented (position, rotation, FOV)
  - Smooth blending validated over 0.5s duration (no jitter)
  - Implementation pattern documented for Phase 10 integration
**✓ R027-R031**: Performance baseline established:
  - Initial load: 98ms
  - Hot reload: 0-1ms
  - Memory baseline: 22.61 MB
  - Memory per scene: ~6.91 MB
  - Memory peak: 30.21 MB
  - No leaks detected (caching intentional)
  - Targets achievable: ✅ YES

---

## Decision Gate Readiness

### Questions to Answer - ALL RESOLVED ✅

1. **Does scene restructuring break ECS or Redux?**
   - Status: ✅ **VALIDATED**
   - Evidence: Prototype passed all tests - ECS and Redux fully functional
   - Result: Scene restructuring pattern confirmed safe

2. **Can we achieve performance targets?**
   - Status: ✅ **TARGETS EXCEEDED**
   - Evidence: 98ms load time (target: 500ms), 1ms hot reload
   - Result: Performance excellent, no concerns

3. **Is camera blending feasible?**
   - Status: ✅ **VALIDATED**
   - Evidence: Working prototype demonstrates smooth Tween interpolation on global_position/rotation/fov
   - Result: Camera blending pattern proven, ready for Phase 10 integration

4. **Is M_StateStore modification safe?**
   - Status: ✅ **VALIDATED (LOW RISK)**
   - Evidence: Purely additive, follows existing pattern, no dependencies
   - Next: Implement in Phase 1, Task T033

### Phase 0 Status: ✅ **COMPLETE**

**Decision**: **APPROVED TO PROCEED TO PHASE 1**
- ✅ All research complete
- ✅ Data model fully defined
- ✅ Prototype validated successfully
- ✅ Safety check passed (LOW RISK)
- ✅ Performance baseline established (excellent)

**Critical Finding**: Multiple state stores warning confirms Phase 2 restructuring is necessary and correctly designed.

**Risks Mitigated**:
- ✅ Architecture pattern validated (root + child scene works)
- ✅ M_StateStore modification plan safe
- ✅ Integration points documented
- ✅ Performance baseline established (98ms load, 1ms reload)

**Blockers**: NONE

**Next Phase**: Begin Phase 1 (Setup) → Phase 2 (Foundational Scene Restructuring)
