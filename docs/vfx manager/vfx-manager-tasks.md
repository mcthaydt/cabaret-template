# VFX Manager - Task Checklist

**Progress:** 60% (12 / 20 tasks complete)
**Unit Tests:** 50 / 60 passing (Phase 0 Redux: 33/33, Phase 1 Manager: 17/17)
**Integration Tests:** 0 / 35 passing
**Manual QA:** 0 / 9 complete

---

## Phase 0: Redux Foundation ✅ COMPLETE

**Exit Criteria:** All 30+ Redux tests pass (5 initial state + 15 reducer + 13 selectors), VFX slice registered in M_StateStore, no console errors

- [x] **Task 0.1 (Red)**: Write tests for VFX initial state resource
  - Create `tests/unit/state/test_vfx_initial_state.gd`
  - Tests: `test_has_screen_shake_enabled_field`, `test_has_screen_shake_intensity_field`, `test_has_damage_flash_enabled_field`, `test_to_dictionary_returns_all_fields`, `test_defaults_match_reducer`
  - All 5 tests failing as expected ✅

- [x] **Task 0.2 (Green)**: Implement VFX initial state resource
  - Create `scripts/state/resources/rs_vfx_initial_state.gd`
  - Exports: `screen_shake_enabled: bool`, `screen_shake_intensity: float`, `damage_flash_enabled: bool`
  - Implement `to_dictionary()` method merging with reducer defaults
  - All 5 tests passing ✅

- [x] **Task 0.3 (Red)**: Write tests for VFX reducer
  - Create `tests/unit/state/test_vfx_reducer.gd`
  - Tests: default state structure, `set_screen_shake_enabled` action, `set_screen_shake_intensity` action, `set_damage_flash_enabled` action
  - Critical tests: `test_set_screen_shake_intensity_clamp_lower` (-0.5 → 0.0), `test_set_screen_shake_intensity_clamp_upper` (3.5 → 2.0), `test_reducer_immutability` (old_state is not new_state)
  - All 15 tests failing as expected ✅

- [x] **Task 0.4 (Green)**: Implement VFX actions and reducer
  - Create `scripts/state/actions/u_vfx_actions.gd`
  - Action creators: `set_screen_shake_enabled(enabled: bool)`, `set_screen_shake_intensity(intensity: float)`, `set_damage_flash_enabled(enabled: bool)`
  - Create `scripts/state/reducers/u_vfx_reducer.gd`
  - Implement `reduce(state: Dictionary, action: Dictionary) -> Dictionary`
  - Implement `get_default_vfx_state() -> Dictionary`
  - Intensity clamping: 0.0-2.0 range
  - Immutability helpers: `_merge_with_defaults`, `_with_values`, `_deep_copy`
  - All 15 tests passing ✅

- [x] **Task 0.5 (Red)**: Write tests for VFX selectors
  - Create `tests/unit/state/test_vfx_selectors.gd`
  - Tests: `is_screen_shake_enabled`, `get_screen_shake_intensity`, `is_damage_flash_enabled`
  - Edge cases: missing vfx slice, null state, missing fields
  - All 13 tests failing as expected ✅ (implemented 13 tests instead of 10)

- [x] **Task 0.6 (Green)**: Implement VFX selectors
  - Create `scripts/state/selectors/u_vfx_selectors.gd`
  - Implement `is_screen_shake_enabled(state: Dictionary) -> bool`
  - Implement `get_screen_shake_intensity(state: Dictionary) -> float`
  - Implement `is_damage_flash_enabled(state: Dictionary) -> bool`
  - All 13 tests passing ✅

- [x] **Task 0.7 (Green)**: Integrate VFX slice into M_StateStore
  - Modify `scripts/state/m_state_store.gd`:
    - Line ~27: Add `const U_VFX_REDUCER := preload("res://scripts/state/reducers/u_vfx_reducer.gd")` ✅
    - Line ~56: Add `@export var vfx_initial_state: RS_VFXInitialState` ✅
    - Line ~164: Add `vfx_initial_state` parameter to `initialize_slices()` call ✅
  - Modify `scripts/state/utils/u_state_slice_manager.gd`:
    - Add `const U_VFX_REDUCER := preload("res://scripts/state/reducers/u_vfx_reducer.gd")` at top ✅
    - Add `vfx_initial_state: RS_VFXInitialState` parameter to `initialize_slices()` function signature ✅
    - Add VFX slice registration block (after debug slice, ~line 99) ✅
  - VFX slice accessible via `state.vfx` ✅

**Completion Notes:**
- All 33 Redux tests passing (5 initial state + 15 reducer + 13 selectors)
- VFX slice successfully integrated into M_StateStore
- Style enforcement test passing for all new files
- Intensity clamping working correctly (0.0-2.0 range)
- Selectors handle edge cases (missing vfx slice, missing fields)

---

## Phase 1: VFX Core Manager

**Exit Criteria:** All 17 manager tests pass (8 lifecycle + 9 trauma system), manager discoverable via ServiceLocator, trauma accumulates and decays correctly

- [x] **Task 1.1 (Red)**: Write tests for manager scaffolding and lifecycle
  - Create `tests/unit/managers/test_vfx_manager.gd`
  - Tests: extends Node, group membership ("vfx_manager"), ServiceLocator registration, StateStore dependency discovery, trauma initialization, `add_trauma()` method, `get_trauma()` method, trauma clamping (max 1.0)
  - All 8 tests failing as expected ✅

- [x] **Task 1.2 (Green)**: Implement VFX manager scaffolding
  - Create `scripts/managers/m_vfx_manager.gd`
  - Extend Node, add `@icon("res://resources/editor_icons/manager.svg")`
  - Add to "vfx_manager" group
  - `_ready()`: Set `process_mode = PROCESS_MODE_ALWAYS`, register with ServiceLocator, discover M_StateStore
  - Private fields: `_state_store: I_StateStore`, `_trauma: float = 0.0`
  - Constant: `TRAUMA_DECAY_RATE := 2.0`
  - Implement `add_trauma(amount: float) -> void`: `_trauma = minf(_trauma + amount, 1.0)`
  - Implement `get_trauma() -> float`: `return _trauma`
  - All 8 tests passing ✅

- [x] **Task 1.3 (Red)**: Write tests for ECS event subscriptions and trauma decay
  - Extend `tests/unit/managers/test_vfx_manager.gd`
  - Tests: `health_changed` event handler (damage amount → trauma 0.3-0.6 mapping), `entity_landed` event handler (fall speed > 15 → trauma 0.2-0.4), `entity_death` event handler (trauma 0.5), trauma decay in `_physics_process` (2.0/sec rate), trauma never goes negative
  - Use `U_ECSEventBus.reset()` in `before_each()`
  - All 9 tests failing as expected ✅

- [x] **Task 1.4 (Green)**: Implement ECS event subscriptions and trauma decay
  - Modify `scripts/managers/m_vfx_manager.gd`
  - Add fields: `_unsubscribe_health: Callable`, `_unsubscribe_landed: Callable`, `_unsubscribe_death: Callable`
  - Subscribe in `_ready()`:
    ```gdscript
    _unsubscribe_health = U_ECSEventBus.subscribe(StringName("health_changed"), _on_health_changed)
    _unsubscribe_landed = U_ECSEventBus.subscribe(StringName("entity_landed"), _on_landed)
    _unsubscribe_death = U_ECSEventBus.subscribe(StringName("entity_death"), _on_death)
    ```
  - Implement `_on_health_changed(event_data: Dictionary) -> void`:
    - Calculate damage magnitude from payload
    - Map damage to trauma (0.3-0.6 range based on damage amount using lerpf)
  - Implement `_on_landed(event_data: Dictionary) -> void`:
    - Extract fall speed from payload
    - If speed > 15, add trauma 0.2-0.4 based on impact force using lerpf
  - Implement `_on_death(event_data: Dictionary) -> void`:
    - Add trauma 0.5
  - Implement `_physics_process(delta: float) -> void`:
    - Decay trauma: `_trauma = maxf(_trauma - TRAUMA_DECAY_RATE * delta, 0.0)`
  - All 17 tests passing ✅

- [x] **Task 1.5 (Green)**: Add M_VFXManager to root scene
  - Modify `scenes/root.tscn`: Add M_VFXManager node under Managers/ hierarchy
  - Manager automatically registers with ServiceLocator on `_ready()`
  - Verify discoverable via `U_ServiceLocator.get_service(StringName("vfx_manager"))` ✅

---

## Phase 2: Screen Shake System

**Exit Criteria:** All 15 screen shake tests pass, shake algorithm validated with quadratic falloff, noise-based offset/rotation working

- [ ] **Task 2.1 (Red)**: Write tests for U_ScreenShake helper
  - Create `tests/unit/managers/helpers/test_screen_shake.gd`
  - Tests: initialization with FastNoiseLite, `calculate_shake()` returns Dictionary with offset and rotation keys, trauma 0.0 → zero shake, trauma 1.0 → full shake, quadratic falloff (trauma 0.5 → shake_amount 0.25), settings_multiplier scaling, noise-based randomness (different offsets over time), max_offset clamping, max_rotation clamping
  - All 15 tests failing as expected

- [ ] **Task 2.2 (Green)**: Implement U_ScreenShake helper
  - Create `scripts/managers/helpers/u_screen_shake.gd`
  - Class structure:
    ```gdscript
    class_name U_ScreenShake
    extends RefCounted

    var max_offset := Vector2(10.0, 8.0)
    var max_rotation := 0.05  # radians
    var noise_speed := 50.0
    var _noise: FastNoiseLite
    var _time: float = 0.0

    func _init() -> void:
        _noise = FastNoiseLite.new()
        _noise.seed = randi()
        _noise.frequency = 1.0

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
  - All 15 tests passing

---

## Phase 3: Camera Manager Integration

**Exit Criteria:** Camera shake visible in-game, no gimbal lock at extreme camera angles, shake applied to parent node (not camera directly)

- [ ] **Task 3.1 (Green)**: Integrate shake parent node into M_CameraManager
  - Modify `scripts/managers/m_camera_manager.gd`
  - Add field: `var _shake_parent: Node3D = null`
  - Add method `_create_shake_parent() -> void`:
    ```gdscript
    _shake_parent = Node3D.new()
    _shake_parent.name = "ShakeParent"
    add_child(_shake_parent)

    # Reparent transition camera under shake parent
    remove_child(_transition_camera)
    _shake_parent.add_child(_transition_camera)
    ```
  - Call `_create_shake_parent()` after transition camera creation in `_ready()`
  - Add method `apply_shake_offset(offset: Vector2, rotation: float) -> void`:
    ```gdscript
    if _shake_parent == null:
        return

    # Convert 2D offset to 3D using camera basis
    var right := _transition_camera.global_transform.basis.x
    var up := _transition_camera.global_transform.basis.y
    var offset_3d := right * offset.x * 0.01 + up * offset.y * 0.01

    _shake_parent.position = offset_3d
    _shake_parent.rotation.z = rotation
    ```
  - Shake parent approach prevents gimbal lock and isolates shake from camera rotation

- [ ] **Task 3.2 (Green)**: Wire VFX Manager to Camera Manager shake application
  - Modify `scripts/managers/m_vfx_manager.gd`
  - Add field: `var _camera_manager: M_CameraManager`, `var _screen_shake: U_ScreenShake`
  - Discover camera manager in `_ready()`: `_camera_manager = U_ServiceLocator.get_service(StringName("camera_manager"))`
  - Initialize `_screen_shake = U_ScreenShake.new()` in `_ready()`
  - Update `_physics_process(delta: float) -> void`:
    ```gdscript
    # Decay trauma
    _trauma = maxf(_trauma - TRAUMA_DECAY_RATE * delta, 0.0)

    # Apply screen shake if enabled
    if _camera_manager != null and _state_store != null:
        var state := _state_store.get_state()
        if U_VFX_SELECTORS.is_screen_shake_enabled(state):
            var intensity := U_VFX_SELECTORS.get_screen_shake_intensity(state)
            var shake_data := _screen_shake.calculate_shake(_trauma, intensity, delta)
            _camera_manager.apply_shake_offset(shake_data["offset"], shake_data["rotation"])
        else:
            # Reset shake when disabled
            _camera_manager.apply_shake_offset(Vector2.ZERO, 0.0)
    ```

---

## Phase 4: Damage Flash System

**Exit Criteria:** All 10 damage flash tests pass, flash visible on damage, fade animation correct (0.4s duration), retrigger kills existing tween

- [ ] **Task 4.1 (Green)**: Create damage flash overlay scene
  - Create `scenes/ui/ui_damage_flash_overlay.tscn` (CanvasLayer; recommend `layer = 50` to stay below `LoadingOverlay.layer = 100` in `scenes/root.tscn`)
  - Scene structure:
    ```
	    CanvasLayer (layer=50)
    └── ColorRect (name="FlashRect")
        - Anchors: FULL_RECT (all sides to 0)
        - Color: Color(1.0, 0.0, 0.0, 0.3)  # Red, 30% opacity when active
        - Modulate.a: 0.0 (invisible by default)
    ```
  - Recommend `layer = 50` to stay below `LoadingOverlay.layer = 100` in `scenes/root.tscn` (choose final layering based on whether you want UI tinted by the flash)

- [ ] **Task 4.2 (Red)**: Write tests for U_DamageFlash helper
  - Create `tests/unit/managers/helpers/test_damage_flash.gd`
  - Tests: initialization with ColorRect reference, `trigger_flash()` sets alpha to max instantly, fade to 0.0 over 0.4 seconds using tween, retrigger kills existing tween, respects enabled toggle, intensity parameter affects max_alpha
  - All 10 tests failing as expected

- [ ] **Task 4.3 (Green)**: Implement U_DamageFlash helper
  - Create `scripts/managers/helpers/u_damage_flash.gd`
  - Class structure:
    ```gdscript
    class_name U_DamageFlash
    extends RefCounted

    const FADE_DURATION := 0.4
    const MAX_ALPHA := 0.3

    var _flash_rect: ColorRect
    var _tween: Tween
    var _scene_tree: SceneTree

    func _init(flash_rect: ColorRect, scene_tree: SceneTree) -> void:
        _flash_rect = flash_rect
        _scene_tree = scene_tree

    func trigger_flash(intensity: float = 1.0) -> void:
        if _flash_rect == null or _scene_tree == null:
            return

        # Kill existing tween
        if _tween != null and _tween.is_valid():
            _tween.kill()

        # Instant jump to max alpha
        _flash_rect.modulate.a = MAX_ALPHA * intensity

        # Fade to 0 over FADE_DURATION
        _tween = _scene_tree.create_tween()
        _tween.tween_property(_flash_rect, "modulate:a", 0.0, FADE_DURATION)
    ```
  - All 10 tests passing

- [ ] **Task 4.4 (Green)**: Integrate damage flash into VFX Manager
  - Modify `scripts/managers/m_vfx_manager.gd`
  - Add field: `var _damage_flash: U_DamageFlash`
  - Load and instance damage flash scene in `_ready()`:
    ```gdscript
    var flash_scene := load("res://scenes/ui/ui_damage_flash_overlay.tscn")
    var flash_instance := flash_scene.instantiate()
    add_child(flash_instance)
    var flash_rect := flash_instance.get_node("FlashRect") as ColorRect
    _damage_flash = U_DamageFlash.new(flash_rect, get_tree())
    ```
  - Update `_on_health_changed()` to trigger flash:
    ```gdscript
    func _on_health_changed(event_data: Dictionary) -> void:
        var payload := event_data.get("payload", {})
        var damage := payload.get("damage", 0.0)

        # Add trauma based on damage
        var trauma_amount := remap(damage, 0.0, 100.0, 0.3, 0.6)
        add_trauma(trauma_amount)

        # Trigger damage flash if enabled
        if _state_store != null and _damage_flash != null:
            var state := _state_store.get_state()
            if U_VFX_SELECTORS.is_damage_flash_enabled(state):
                _damage_flash.trigger_flash(1.0)
    ```

---

## Phase 5: Settings UI Integration

**Exit Criteria:** Settings persist to save files, UI updates reflect in-game immediately, auto-save on change (no Apply button)

- [ ] **Task 5.1 (Green)**: Create VFX settings tab scene
  - Create `scenes/ui/settings/vfx_settings_tab.tscn`
  - Scene structure:
    ```
    VBoxContainer (name="VFXSettingsTab")
    ├── Label (text="VISUAL EFFECTS", theme_variant="heading")
    ├── HBoxContainer (name="ShakeEnabledRow")
    │   ├── CheckBox (name="ShakeEnabledToggle")
    │   └── Label (text="Screen Shake")
    ├── HBoxContainer (name="ShakeIntensityRow")
    │   ├── Label (text="Intensity")
    │   ├── HSlider (name="IntensitySlider", min=0.0, max=2.0, step=0.1, value=1.0)
    │   └── Label (name="IntensityPercentage", text="100%")
    ├── HBoxContainer (name="FlashEnabledRow")
    │   ├── CheckBox (name="FlashEnabledToggle")
    │   └── Label (text="Damage Flash")
    ```
  - All controls use focus navigation for gamepad support

- [ ] **Task 5.2 (Green)**: Implement VFX settings tab script
  - Create `scripts/ui/settings/ui_vfx_settings_tab.gd`
  - Extend Control or VBoxContainer
  - Script structure:
    ```gdscript
    extends VBoxContainer
    class_name UI_VFXSettingsTab

    var _state_store: I_StateStore
    var _unsubscribe: Callable

    @onready var _shake_enabled_toggle := %ShakeEnabledToggle as CheckBox
    @onready var _intensity_slider := %IntensitySlider as HSlider
    @onready var _intensity_percentage := %IntensityPercentage as Label
    @onready var _flash_enabled_toggle := %FlashEnabledToggle as CheckBox

    func _ready() -> void:
        _state_store = U_ServiceLocator.get_service(StringName("state_store"))
        if _state_store == null:
            push_error("VFX Settings Tab: StateStore not found")
            return

        # Connect UI signals
        _shake_enabled_toggle.toggled.connect(_on_shake_enabled_toggled)
        _intensity_slider.value_changed.connect(_on_intensity_changed)
        _flash_enabled_toggle.toggled.connect(_on_flash_enabled_toggled)

        # Subscribe to state changes
        _unsubscribe = _state_store.subscribe(_on_state_changed)
        _on_state_changed(_state_store.get_state())

    func _exit_tree() -> void:
        if _unsubscribe.is_valid():
            _unsubscribe.call()

    func _on_state_changed(state: Dictionary) -> void:
        # Update UI from state (without triggering signals)
        _shake_enabled_toggle.set_block_signals(true)
        _shake_enabled_toggle.button_pressed = U_VFX_SELECTORS.is_screen_shake_enabled(state)
        _shake_enabled_toggle.set_block_signals(false)

        _intensity_slider.set_block_signals(true)
        var intensity := U_VFX_SELECTORS.get_screen_shake_intensity(state)
        _intensity_slider.value = intensity
        _intensity_slider.set_block_signals(false)
        _update_percentage_label(intensity)

        _flash_enabled_toggle.set_block_signals(true)
        _flash_enabled_toggle.button_pressed = U_VFX_SELECTORS.is_damage_flash_enabled(state)
        _flash_enabled_toggle.set_block_signals(false)

    func _on_shake_enabled_toggled(pressed: bool) -> void:
        if _state_store:
            _state_store.dispatch(U_VFX_ACTIONS.set_screen_shake_enabled(pressed))

    func _on_intensity_changed(value: float) -> void:
        if _state_store:
            _state_store.dispatch(U_VFX_ACTIONS.set_screen_shake_intensity(value))
        _update_percentage_label(value)

    func _on_flash_enabled_toggled(pressed: bool) -> void:
        if _state_store:
            _state_store.dispatch(U_VFX_ACTIONS.set_damage_flash_enabled(pressed))

    func _update_percentage_label(value: float) -> void:
        _intensity_percentage.text = "%d%%" % int(value * 100.0)
    ```
  - Auto-save pattern: immediate Redux dispatch on change (no Apply button needed)

- [ ] **Task 5.3 (Green)**: Wire VFX settings tab into settings panel
  - Modify main settings panel scene to include VFX tab
  - Ensure VFX settings are saved to save file via Redux state persistence
  - Test: Change settings → Save game → Load game → Settings persist

---

## Phase 6: Testing & Integration

**Exit Criteria:** All 95 tests pass (60 unit + 35 integration), manual playtest successful, no console errors

- [ ] **Task 6.1 (Red)**: Write integration test for VFX-Camera interaction
  - Create `tests/integration/vfx/test_vfx_camera_integration.gd`
  - Tests: VFX Manager applies shake to Camera Manager, shake offset reflects in camera transform, shake respects enabled toggle, shake intensity multiplier affects magnitude, trauma decay reduces shake over time, multiple damage events accumulate trauma (clamped to 1.0), camera shake doesn't affect camera rotation (parent node isolation)
  - All tests failing as expected

- [ ] **Task 6.2 (Green)**: Verify VFX-Camera integration passes tests
  - Run integration tests
  - Fix any integration issues discovered
  - All integration tests passing

- [ ] **Task 6.3 (Red)**: Write integration test for VFX settings UI
  - Create `tests/integration/vfx/test_vfx_settings_ui.gd`
  - Tests: UI controls initialize from Redux state, toggling shake enabled dispatches action and updates state, changing intensity slider dispatches action and updates state, toggling flash enabled dispatches action and updates state, state changes update UI (bidirectional binding), settings persist to save file, settings restore from save file
  - All tests failing as expected

- [ ] **Task 6.4 (Green)**: Verify VFX settings UI integration passes tests
  - Run integration tests
  - Fix any UI binding issues discovered
  - All integration tests passing

- [ ] **Task 6.5 (Manual QA)**: Perform manual playtest
  - [ ] Screen shake visible when taking damage (trauma added from health_changed event)
  - [ ] Shake respects enabled toggle (toggle off → no shake, toggle on → shake resumes)
  - [ ] Shake intensity slider affects magnitude (0.0 = no shake, 1.0 = normal, 2.0 = double intensity)
  - [ ] No gimbal lock at extreme camera angles (shake parent isolates rotation)
  - [ ] Damage flash visible and fades correctly (instant red flash, fades over 0.4s)
  - [ ] Flash respects enabled toggle (toggle off → no flash, toggle on → flash resumes)
  - [ ] Multiple hits restart fade (no stacking/flickering, tween killed and restarted)
  - [ ] Settings persist across save/load (change settings → save → quit → load → settings restored)
  - [ ] UI updates reflect in game immediately (no delay, auto-save on change)

- [ ] **Task 6.6 (Testing)**: Run full test suite
  - Command: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
  - Verify all 95 tests pass (60 unit + 35 integration)
  - Verify no console errors or warnings
  - All tests passing, Phase 6 complete

---

## File Reference

| File Path | Status | Phase | Notes |
|-----------|--------|-------|-------|
| `scripts/state/resources/rs_vfx_initial_state.gd` | ⬜ Not Started | 0 | VFX initial state resource with 3 fields |
| `scripts/state/actions/u_vfx_actions.gd` | ⬜ Not Started | 0 | 3 action creators for VFX settings |
| `scripts/state/reducers/u_vfx_reducer.gd` | ⬜ Not Started | 0 | VFX reducer with intensity clamping |
| `scripts/state/selectors/u_vfx_selectors.gd` | ⬜ Not Started | 0 | 3 selectors for VFX state |
| `scripts/state/m_state_store.gd` | ⬜ Not Started | 0 | Modified to export vfx_initial_state |
| `scripts/state/utils/u_state_slice_manager.gd` | ⬜ Not Started | 0 | Modified to register VFX slice |
| `tests/unit/state/test_vfx_initial_state.gd` | ⬜ Not Started | 0 | 5 tests for initial state |
| `tests/unit/state/test_vfx_reducer.gd` | ⬜ Not Started | 0 | 15 tests for reducer (includes clamping) |
| `tests/unit/state/test_vfx_selectors.gd` | ⬜ Not Started | 0 | 10 tests for selectors |
| `scripts/managers/m_vfx_manager.gd` | ⬜ Not Started | 1 | VFX manager with trauma system |
| `tests/unit/managers/test_vfx_manager.gd` | ⬜ Not Started | 1 | 17 tests for manager lifecycle + trauma |
| `scenes/root.tscn` | ⬜ Not Started | 1 | Modified to add M_VFXManager node |
| `scripts/managers/helpers/u_screen_shake.gd` | ⬜ Not Started | 2 | Screen shake helper with noise algorithm |
| `tests/unit/managers/helpers/test_screen_shake.gd` | ⬜ Not Started | 2 | 15 tests for shake algorithm |
| `scripts/managers/m_camera_manager.gd` | ⬜ Not Started | 3 | Modified to add shake parent + apply method |
| `scenes/ui/ui_damage_flash_overlay.tscn` | ⬜ Not Started | 4 | Damage flash overlay scene (CanvasLayer; recommend layer 50) |
| `scripts/managers/helpers/u_damage_flash.gd` | ⬜ Not Started | 4 | Damage flash helper with tween fade |
| `tests/unit/managers/helpers/test_damage_flash.gd` | ⬜ Not Started | 4 | 10 tests for damage flash |
| `scenes/ui/settings/vfx_settings_tab.tscn` | ⬜ Not Started | 5 | VFX settings UI scene |
| `scripts/ui/settings/ui_vfx_settings_tab.gd` | ⬜ Not Started | 5 | VFX settings UI script with auto-save |
| `tests/integration/vfx/test_vfx_camera_integration.gd` | ⬜ Not Started | 6 | Integration tests for VFX-Camera |
| `tests/integration/vfx/test_vfx_settings_ui.gd` | ⬜ Not Started | 6 | Integration tests for settings UI |

**Status Legend:**
- ⬜ Not Started
- 🟡 In Progress
- ✅ Complete

---

## Links

- Overview: `docs/vfx manager/vfx-manager-overview.md`
- PRD: `docs/vfx manager/vfx-manager-prd.md`
- Plan: `docs/vfx manager/vfx-manager-plan.md`
- Continuation prompt: `docs/vfx manager/vfx-manager-continuation-prompt.md`

---

## Notes

### Test Patterns
- All tests use GUT framework (`extends GutTest`)
- Event subscriptions: Always `U_ECSEventBus.reset()` in `before_each()` to prevent test pollution
- Redux immutability: Verify `old_state is not new_state` in reducer tests
- Tween testing: Use `await get_tree().create_timer(duration + 0.1).timeout` to wait for tween completion
- Camera shake testing: Check `_shake_parent.position` and `_shake_parent.rotation.z`, not camera transform directly

### Test Commands
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

### Decisions
- **Shake Parent Node Approach**: Chosen to prevent gimbal lock and isolate shake from camera rotation. Alternative considered: direct camera manipulation (rejected due to gimbal issues at extreme angles).
- **Quadratic Trauma Falloff**: Using `trauma * trauma` for shake_amount provides smoother, more natural-feeling shake decay. Linear falloff felt too abrupt.
- **Damage Flash Layering**: Recommend `layer = 50` to ensure it stays below `LoadingOverlay.layer = 100` in `scenes/root.tscn`; decide whether it should be above/below `UIOverlayStack` based on desired UX.
- **Auto-Save Settings**: Immediate Redux dispatch on UI change (no Apply button) provides instant feedback and simpler UX. Settings automatically persist via Redux→SaveManager integration.
- **Intensity Range 0.0-2.0**: Allows users to completely disable shake (0.0), use normal intensity (1.0), or amplify for accessibility/preference (2.0). Clamping prevents excessive/negative values.

### Deferred Items
- **Trauma event weighting**: Currently using hardcoded trauma amounts (0.3-0.6 for damage, 0.5 for death). Future: Make configurable via settings resource.
- **Shake frequency/noise customization**: Currently using fixed FastNoiseLite settings. Future: Expose as settings for different shake "feels" (smooth vs jittery).
- **Flash color customization**: Currently hardcoded to red (1.0, 0.0, 0.0). Future: Support different colors for different damage types (poison green, ice blue, etc.).
- **Directional shake**: Currently omnidirectional. Future: Shake direction based on damage source position relative to camera.

### Common Pitfalls
1. **Godot 4.5 Type Inference**: Use explicit types for Variant returns:
   ```gdscript
   var new_state: Variant = U_VFX_REDUCER.reduce(state, action)
   # OR
   var new_state := U_VFX_REDUCER.reduce(state, action) as Dictionary
   ```
2. **Test Subscription Leaks**: Always `U_ECSEventBus.reset()` in `before_each()` or tests will interfere with each other
3. **Shake Applied to Wrong Node**: Apply to `_shake_parent`, not `_transition_camera` directly, or gimbal lock will occur
4. **Flash Layer Order**: Ensure damage flash layer is below `LoadingOverlay` and below `TransitionOverlay` (fade-to-black should win); set an explicit `CanvasLayer.layer` to avoid ambiguous draw order
5. **Tween Kill Before Retrigger**: Always check `if _tween != null and _tween.is_valid(): _tween.kill()` before creating new tween, or multiple tweens will conflict

---

**END OF VFX MANAGER TASKS**
