# VFX Manager - Implementation Plan

**Project**: Cabaret Template (Godot 4.5)
**Status**: Implemented (Phases 0-7 complete)
**Estimated Duration**: 14 days
**Test Count**: 95 tests (82 unit + 13 integration)
**Methodology**: Test-Driven Development (Red-Green-Refactor)

---

## Overview

The VFX Manager provides screen-level visual effects (screen shake, damage flash) with Redux state integration. Implementation follows established codebase patterns for Redux slices, managers, and ECS integration.

---

## Phase 0: Redux Foundation (Days 1-2)

### Commit 1: VFX Initial State Resource

**Files to create**:
- `scripts/state/resources/rs_vfx_initial_state.gd`
- `tests/unit/state/test_vfx_initial_state.gd` (6 tests)

**Implementation**:
```gdscript
@icon("res://resources/editor_icons/resource.svg")
extends Resource
class_name RS_VFXInitialState

@export_group("Screen Shake")
@export var screen_shake_enabled: bool = true
@export_range(0.0, 2.0, 0.1) var screen_shake_intensity: float = 1.0

@export_group("Damage Flash")
@export var damage_flash_enabled: bool = true

@export_group("Particles")
@export var particles_enabled: bool = true

func to_dictionary() -> Dictionary:
    return {
        "screen_shake_enabled": screen_shake_enabled,
        "screen_shake_intensity": screen_shake_intensity,
        "damage_flash_enabled": damage_flash_enabled,
        "particles_enabled": particles_enabled
    }
```

**Tests**:
- test_has_screen_shake_enabled_field
- test_has_screen_shake_intensity_field
- test_has_damage_flash_enabled_field
- test_has_particles_enabled_field
- test_to_dictionary_returns_all_fields
- test_defaults_match_reducer

---

### Commit 2: VFX Actions & Reducer

**Files to create**:
- `scripts/state/actions/u_vfx_actions.gd`
- `scripts/state/reducers/u_vfx_reducer.gd`
- `tests/unit/state/test_vfx_reducer.gd` (15 tests)

**Key Features**:
- 4 action creators (set_screen_shake_enabled, set_screen_shake_intensity, set_damage_flash_enabled, set_particles_enabled)
- Intensity clamping (0.0-2.0)
- Immutability helpers (_merge_with_defaults, _with_values, _deep_copy)

**Critical Tests**:
- test_set_screen_shake_intensity_clamp_lower (-0.5 → 0.0)
- test_set_screen_shake_intensity_clamp_upper (3.5 → 2.0)
- test_reducer_immutability (old_state is not new_state)

---

### Commit 3: VFX Selectors & M_StateStore Integration

**Files to create**:
- `scripts/state/selectors/u_vfx_selectors.gd`
- `tests/unit/state/test_vfx_selectors.gd` (17 tests)

**Files to modify**:
- `scripts/state/m_state_store.gd`:
  - Line ~27: Add `const U_VFX_REDUCER := preload("res://scripts/state/reducers/u_vfx_reducer.gd")`
  - Line ~56: Add `@export var vfx_initial_state: RS_VFXInitialState`
  - Line ~164: Add `vfx_initial_state` to `initialize_slices()` call

- `scripts/state/utils/u_state_slice_manager.gd`:
  - **Add parameter** to `initialize_slices()` function signature:
    ```gdscript
    static func initialize_slices(
        # ... existing parameters ...
        debug_initial_state: RS_DebugInitialState,
        vfx_initial_state: RS_VFXInitialState  # ADD THIS
    ) -> void:
    ```
  - **Add VFX slice registration** (after debug slice block, ~line 99):
    ```gdscript
    # VFX slice
    if vfx_initial_state != null:
        var vfx_config := RS_StateSliceConfig.new(StringName("vfx"))
        vfx_config.reducer = Callable(U_VFXReducer, "reduce")
        vfx_config.initial_state = vfx_initial_state.to_dictionary()
        vfx_config.dependencies = []
        vfx_config.transient_fields = []
        register_slice(slice_configs, state, vfx_config)
    ```
  - **Add reducer preload** at top of file:
    ```gdscript
    const U_VFX_REDUCER := preload("res://scripts/state/reducers/u_vfx_reducer.gd")
    ```

**Selectors**:
- `is_screen_shake_enabled(state: Dictionary) -> bool`
- `get_screen_shake_intensity(state: Dictionary) -> float`
- `is_damage_flash_enabled(state: Dictionary) -> bool`
- `is_particles_enabled(state: Dictionary) -> bool`

---

## Phase 1: VFX Core Manager (Days 3-4)

### Commit 1: Manager Scaffolding & Lifecycle

**Files to create**:
- `scripts/managers/m_vfx_manager.gd`
- `tests/unit/managers/test_vfx_manager.gd` (8 tests)

**Manager Structure**:
```gdscript
@icon("res://resources/editor_icons/manager.svg")
class_name M_VFXManager
extends Node

const U_ServiceLocator := preload("res://scripts/core/u_service_locator.gd")
var _state_store: I_StateStore
var _trauma: float = 0.0
const TRAUMA_DECAY_RATE := 2.0

func _ready() -> void:
    process_mode = PROCESS_MODE_ALWAYS
    add_to_group("vfx_manager")
    U_ServiceLocator.register(StringName("vfx_manager"), self)
    # ... state store discovery

func add_trauma(amount: float) -> void:
    _trauma = minf(_trauma + amount, 1.0)

func get_trauma() -> float:
    return _trauma
```

---

### Commit 2: ECS Event Subscriptions & Trauma Decay

**Event Subscriptions**:
- `health_changed` → `_on_health_changed()` (damage → trauma 0.3-0.6)
- `entity_landed` → `_on_landed()` (fall speed > 15 → trauma 0.2-0.4)
- `entity_death` → `_on_death()` (trauma 0.5)

**Trauma Decay**: `_physics_process(delta)` reduces trauma by 2.0/second

---

### Commit 3: Add to Main Scene

**Modify**:
- `scenes/root.tscn`: Add M_VFXManager node under Managers/
- `scripts/scene_structure/main.gd`: Register with ServiceLocator (Root bootstrap)

---

## Phase 2: Screen Shake System (Days 5-7)

### Commit 1: U_ScreenShake Helper

**Files to create**:
- `scripts/managers/helpers/u_screen_shake.gd`
- `tests/unit/managers/helpers/test_screen_shake.gd` (15 tests)

**Shake Algorithm**:
```gdscript
class_name U_ScreenShake
extends RefCounted

var max_offset := Vector2(10.0, 8.0)
var max_rotation := 0.05
var _noise: FastNoiseLite

func calculate_shake(trauma: float, settings_multiplier: float, delta: float) -> Dictionary:
    _time += delta * noise_speed
    var shake_amount := trauma * trauma  # Quadratic falloff

    var offset := Vector2(
        max_offset.x * shake_amount * _noise.get_noise_1d(_time),
        max_offset.y * shake_amount * _noise.get_noise_1d(_time + 100.0)
    ) * settings_multiplier

    var rotation := max_rotation * shake_amount * _noise.get_noise_1d(_time + 200.0) * settings_multiplier

    return {"offset": offset, "rotation": rotation}
```

---

## Phase 3: Camera Manager Integration (Days 8-9)

### Shake Parent Node Approach

**Modify**: `scripts/managers/m_camera_manager.gd`

```gdscript
var _shake_parent: Node3D = null

func _create_shake_parent() -> void:
    _shake_parent = Node3D.new()
    _shake_parent.name = "ShakeParent"
    add_child(_shake_parent)

    # Reparent transition camera under shake parent
    remove_child(_transition_camera)
    _shake_parent.add_child(_transition_camera)

func apply_shake_offset(offset: Vector2, rotation: float) -> void:
    # Convert 2D to 3D using camera basis
    var right := _transition_camera.global_transform.basis.x
    var up := _transition_camera.global_transform.basis.y
    var offset_3d := right * offset.x * 0.01 + up * offset.y * 0.01

    _shake_parent.position = offset_3d
    _shake_parent.rotation.z = rotation
```

**Why parent node?**: Prevents gimbal lock, isolates shake from camera rotation

---

## Phase 4: Damage Flash System (Days 10-11)

### Damage Flash Scene & Script

**Files to create**:
- `scenes/ui/ui_damage_flash_overlay.tscn`
- `scripts/managers/helpers/u_damage_flash.gd`
- `tests/unit/managers/helpers/test_damage_flash.gd` (10 tests)

**Scene Structure**:
```
CanvasLayer (recommend layer=50; keep below `LoadingOverlay.layer = 100` in `scenes/root.tscn`)
└── ColorRect (anchors=FULL_RECT, color=Color(1,0,0,0.3), alpha=0)
```

**Flash Behavior**:
- Instant jump to max_alpha * intensity
- Fade to 0.0 over 0.4 seconds
- Restart on retrigger (kill existing tween)
- Respect `damage_flash_enabled` toggle

---

## Phase 5: Settings UI Integration (Days 12-14)

### VFX Settings Tab

**Scene**: `scenes/ui/settings/vfx_settings_tab.tscn`

```
VBoxContainer
├── Label ("VISUAL EFFECTS")
├── HBoxContainer
│   ├── CheckBox (shake_enabled_toggle)
│   └── Label ("Screen Shake")
├── HBoxContainer
│   ├── Label ("Intensity")
│   ├── HSlider (0.0-2.0, step 0.1)
│   └── Label (percentage)
├── HBoxContainer
│   ├── CheckBox (flash_enabled_toggle)
│   └── Label ("Damage Flash")
```

**Auto-Save Pattern**: Immediate Redux dispatch on change (no Apply button)

---

## Success Criteria

### Phase 0 Complete:
- [ ] All 30 Redux tests pass (initial state, reducer, selectors)
- [ ] VFX slice registered in M_StateStore
- [ ] No console errors

### Phase 1 Complete:
- [ ] All 17 manager tests pass
- [ ] Trauma accumulates from events and decays correctly
- [ ] Manager registered with ServiceLocator

### Phase 2-3 Complete:
- [ ] Screen shake visible when taking damage
- [ ] Shake respects enabled toggle
- [ ] Shake intensity slider affects magnitude
- [ ] No gimbal lock at extreme camera angles

### Phase 4 Complete:
- [ ] Damage flash visible and fades correctly
- [ ] Flash respects enabled toggle
- [ ] Multiple hits restart fade (no stacking)

### Phase 5 Complete:
- [ ] All 95 tests pass
- [ ] Settings persist to save files
- [ ] UI updates reflect in game immediately
- [ ] Manual playtest: damage triggers both shake and flash

---

## Common Pitfalls

1. **Godot 4.5 Type Inference**: Use explicit types for Variant returns:
   ```gdscript
   var new_state: Variant = U_VFX_REDUCER.reduce(state, action)
   # OR
   var new_state := U_VFX_REDUCER.reduce(state, action) as Dictionary
   ```

2. **Test Subscription Leaks**: Always `U_ECSEventBus.reset()` in `before_each()`

3. **Shake Applied to Wrong Node**: Apply to parent, not camera directly

4. **Flash Layer Order**: Pick an explicit layer below `LoadingOverlay.layer = 100` and below `TransitionOverlay` (fade-to-black should win); docs recommend `layer = 50`

---

## Testing Commands

```bash
# Run VFX unit tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit

# Run VFX integration tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/vfx -gexit

# Run all tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

---

## File Structure

```
scripts/managers/
  m_vfx_manager.gd
  helpers/
    u_screen_shake.gd
    u_damage_flash.gd

scripts/state/
  resources/rs_vfx_initial_state.gd
  actions/u_vfx_actions.gd
  reducers/u_vfx_reducer.gd
  selectors/u_vfx_selectors.gd

scenes/ui/
  ui_damage_flash_overlay.tscn

tests/unit/
  state/
    test_vfx_initial_state.gd
    test_vfx_reducer.gd
    test_vfx_selectors.gd
  managers/
    test_vfx_manager.gd
    helpers/
      test_screen_shake.gd
      test_damage_flash.gd

tests/integration/vfx/
  test_vfx_camera_integration.gd
  test_vfx_settings_ui.gd
```

---

**END OF VFX MANAGER PLAN**
