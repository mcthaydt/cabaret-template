# VFX Manager Refactoring Tasks

## Overview

This document tracks the refactoring of the existing VFX Manager system to improve architecture, correctness, scalability, and testability. The VFX Manager currently works (Phases 0-7 complete, 82 unit tests + 13 integration tests passing), but this refactor will improve:

- **Event Architecture**: Decouple from raw gameplay events via publisher systems
- **Gating**: Add player-only and transition blocking
- **Resource-Driven Config**: Externalize magic numbers to tuning resources
- **Type Safety**: Add typed results and event constants
- **Testing**: Add deterministic testing hooks and comprehensive coverage

**Status**: In Progress (Phase 8 implementation complete; verification pending)
**Current Phase**: Phase 8
**Last Updated**: 2026-01-16

---

## Phase 1: Event Architecture + Request Queue

**Goal**: Decouple VFX Manager from raw gameplay events by introducing VFX request events, publisher systems, request queue pattern, and event constants.

**Current State**: VFX Manager directly subscribes to `health_changed`, `entity_landed`, `entity_death`
**Target State**: Publisher systems translate gameplay events → VFX request events → VFX Manager with deterministic queue processing

**Includes (merged from original Phase 6)**:
- Request queue pattern for deterministic ordering
- Event name constants to eliminate string literals

### Tests (Write First - TDD)

- [x] **T1.1**: Write test for `Evn_ScreenShakeRequest` event class
  - Location: `tests/unit/ecs/events/test_evn_screen_shake_request.gd`
  - Extends: `GutTest`
  - Tests:
    - `test_has_entity_id_field`
    - `test_has_trauma_amount_field`
    - `test_has_source_field`
    - `test_timestamp_auto_populated`
    - `test_payload_structure`
    - `test_payload_contains_all_fields`
  - All tests RED initially ✅

- [x] **T1.2**: Write test for `Evn_DamageFlashRequest` event class
  - Location: `tests/unit/ecs/events/test_evn_damage_flash_request.gd`
  - Extends: `GutTest`
  - Tests:
    - `test_has_entity_id_field`
    - `test_has_intensity_field`
    - `test_has_source_field`
    - `test_timestamp_auto_populated`
    - `test_payload_structure`
  - All tests RED initially ✅

- [x] **T1.3**: Write test for `S_ScreenShakePublisherSystem`
  - Location: `tests/unit/ecs/systems/test_s_screen_shake_publisher_system.gd`
  - Extends: `GutTest`
  - Setup: Mock ECS Manager, reset event bus in `before_each()`
  - Tests:
    - `test_subscribes_to_health_changed_on_ready`
    - `test_subscribes_to_entity_landed_on_ready`
    - `test_subscribes_to_entity_death_on_ready`
    - `test_health_changed_publishes_screen_shake_request`
    - `test_damage_maps_to_trauma_range_0_3_to_0_6`
    - `test_ignores_healing`
    - `test_ignores_damage_when_dead`
    - `test_landing_above_threshold_publishes_request`
    - `test_landing_below_threshold_ignored`
    - `test_death_publishes_fixed_trauma_0_5`
    - `test_unsubscribes_on_exit_tree`
  - All tests RED initially ✅

- [x] **T1.4**: Write test for `S_DamageFlashPublisherSystem`
  - Location: `tests/unit/ecs/systems/test_s_damage_flash_publisher_system.gd`
  - Extends: `GutTest`
  - Tests:
    - `test_subscribes_to_health_changed_on_ready`
    - `test_subscribes_to_entity_death_on_ready`
    - `test_health_changed_publishes_damage_flash_request`
    - `test_ignores_healing`
    - `test_ignores_damage_when_dead`
    - `test_death_publishes_damage_flash_request`
    - `test_intensity_fixed_at_1_0_for_now`
    - `test_unsubscribes_on_exit_tree`
  - All tests RED initially ✅

- [x] **T1.5**: Write integration test for event flow
  - Location: `tests/integration/vfx/test_vfx_event_flow_refactor.gd`
  - Setup: Full scene with publisher systems and VFX manager
  - Tests:
    - `test_health_changed_triggers_both_shake_and_flash`
    - `test_landing_triggers_shake_only`
    - `test_death_triggers_both_effects`
    - `test_event_flow_preserves_trauma_amounts`
  - All tests RED initially ✅

### Implementation

- [x] **T1.6**: Create `Evn_ScreenShakeRequest` event class
  - Location: `scripts/events/ecs/evn_screen_shake_request.gd`
  - Extends: `BaseECSEvent`
  - Class name: `Evn_ScreenShakeRequest`
  - Fields:
    - `var entity_id: StringName`
    - `var trauma_amount: float`
    - `var source: StringName`
  - Constructor: `_init(p_entity_id, p_trauma_amount, p_source)`
  - Auto-populate timestamp via `U_ECS_UTILS.get_current_time()`
  - Build payload dictionary with all fields
  - Tests GREEN ✅

- [x] **T1.7**: Create `Evn_DamageFlashRequest` event class
  - Location: `scripts/events/ecs/evn_damage_flash_request.gd`
  - Extends: `BaseECSEvent`
  - Class name: `Evn_DamageFlashRequest`
  - Fields:
    - `var entity_id: StringName`
    - `var intensity: float`
    - `var source: StringName`
  - Constructor: `_init(p_entity_id, p_intensity, p_source)`
  - Auto-populate timestamp and payload
  - Tests GREEN ✅

- [x] **T1.8**: Create `S_ScreenShakePublisherSystem`
  - Location: `scripts/ecs/systems/s_screen_shake_publisher_system.gd`
  - Extends: `BaseECSSystem`
  - Class name: `S_ScreenShakePublisherSystem`
  - Add icon: `@icon("res://assets/editor_icons/system.svg")`
  - Constants (temporary, Phase 4 will move to resources):
    ```gdscript
    const DAMAGE_MIN_TRAUMA := 0.3
    const DAMAGE_MAX_TRAUMA := 0.6
    const DAMAGE_MAX_VALUE := 100.0
    const LANDING_THRESHOLD := 15.0
    const LANDING_MAX_SPEED := 30.0
    const LANDING_MIN_TRAUMA := 0.2
    const LANDING_MAX_TRAUMA := 0.4
    const DEATH_TRAUMA := 0.5
    ```
  - Fields:
    - `var _unsubscribe_health: Callable`
    - `var _unsubscribe_landed: Callable`
    - `var _unsubscribe_death: Callable`
  - Implement `on_configured()`: Subscribe to 3 gameplay events
  - Implement `_exit_tree()`: Unsubscribe from all events
  - Implement `_on_health_changed()`: Extract trauma logic from M_VFXManager
  - Implement `_on_landed()`: Extract landing logic from M_VFXManager
  - Implement `_on_death()`: Extract death logic from M_VFXManager
  - Publish: `Evn_ScreenShakeRequest` via `U_ECS_EVENT_BUS.publish_typed()`
  - Tests GREEN ✅

- [x] **T1.9**: Create `S_DamageFlashPublisherSystem`
  - Location: `scripts/ecs/systems/s_damage_flash_publisher_system.gd`
  - Extends: `BaseECSSystem`
  - Class name: `S_DamageFlashPublisherSystem`
  - Add icon: `@icon("res://assets/editor_icons/system.svg")`
  - Fields:
    - `var _unsubscribe_health: Callable`
    - `var _unsubscribe_death: Callable`
  - Implement `on_configured()`: Subscribe to health_changed and entity_death
  - Implement `_exit_tree()`: Unsubscribe from both events
  - Implement `_on_health_changed()`: Check damage > 0, publish flash request
  - Implement `_on_death()`: Publish flash request with intensity 1.0
  - Tests GREEN ✅

- [x] **T1.10**: Update `M_VFXManager` to use VFX request events with queue pattern
  - Location: `scripts/managers/m_vfx_manager.gd`
  - Remove: `health_changed`, `entity_landed`, `entity_death` subscriptions (lines 90-92)
  - Add request queue fields:
    ```gdscript
    var _shake_requests: Array = []
    var _flash_requests: Array = []
    var _event_unsubscribes: Array[Callable] = []
    ```
  - Add subscription using array pattern:
    ```gdscript
    _event_unsubscribes.append(U_ECS_EVENT_BUS.subscribe(
        U_ECSEventNames.EVENT_SCREEN_SHAKE_REQUEST,
        _on_screen_shake_request
    ))
    _event_unsubscribes.append(U_ECS_EVENT_BUS.subscribe(
        U_ECSEventNames.EVENT_DAMAGE_FLASH_REQUEST,
        _on_damage_flash_request
    ))
    ```
  - Remove: Old event handlers `_on_health_changed`, `_on_landed`, `_on_death`
  - Add new handlers that ENQUEUE (not process immediately):
    ```gdscript
    func _on_screen_shake_request(event_data: Dictionary) -> void:
        _shake_requests.append(event_data)

    func _on_damage_flash_request(event_data: Dictionary) -> void:
        _flash_requests.append(event_data)
    ```
  - Add processing methods:
    ```gdscript
    func _process_shake_request(event_data: Dictionary) -> void:
        var payload: Dictionary = event_data.get("payload", {})
        var trauma_amount: float = float(payload.get("trauma_amount", 0.0))
        add_trauma(trauma_amount)

    func _process_flash_request(event_data: Dictionary) -> void:
        if _state_store == null or _damage_flash == null:
            return
        var state: Dictionary = _state_store.get_state()
        if not U_VFX_SELECTORS.is_damage_flash_enabled(state):
            return
        var payload: Dictionary = event_data.get("payload", {})
        var intensity: float = float(payload.get("intensity", 1.0))
        _damage_flash.trigger_flash(intensity)
    ```
  - Update `_physics_process()` to process queues:
    ```gdscript
    # Process queued requests (deterministic ordering)
    for request in _shake_requests:
        _process_shake_request(request)
    _shake_requests.clear()

    for request in _flash_requests:
        _process_flash_request(request)
    _flash_requests.clear()

    # ... existing trauma decay and shake application ...
    ```
  - Update `_exit_tree()` to use array cleanup:
    ```gdscript
    func _exit_tree() -> void:
        for unsubscribe in _event_unsubscribes:
            if unsubscribe.is_valid():
                unsubscribe.call()
        _event_unsubscribes.clear()
    ```
  - Tests GREEN ✅

- [x] **T1.10b**: Create event name constants file
  - Location: `scripts/events/ecs/u_ecs_event_names.gd`
  - Class name: `U_ECSEventNames`
  - Extends: `RefCounted`
  - Add constants:
    ```gdscript
    # VFX Events
    const EVENT_SCREEN_SHAKE_REQUEST := StringName("screen_shake_request")
    const EVENT_DAMAGE_FLASH_REQUEST := StringName("damage_flash_request")

    # Gameplay Events
    const EVENT_HEALTH_CHANGED := StringName("health_changed")
    const EVENT_ENTITY_LANDED := StringName("entity_landed")
    const EVENT_ENTITY_DEATH := StringName("entity_death")

    # Service Names
    const SERVICE_VFX_MANAGER := StringName("vfx_manager")
    const SERVICE_CAMERA_MANAGER := StringName("camera_manager")
    const SERVICE_STATE_STORE := StringName("state_store")
    ```

- [x] **T1.11**: Add publisher systems to gameplay scene
  - Location: `scenes/gameplay/gameplay_base.tscn`
  - Under `Systems` node, add:
    - `S_ScreenShakePublisherSystem` (name: "S_ScreenShakePublisherSystem")
    - `S_DamageFlashPublisherSystem` (name: "S_DamageFlashPublisherSystem")
  - Position after feedback systems (keep organizational structure)

### Verification

- [x] **T1.12**: Run Phase 1 tests
  - Command: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs/events -gexit`
  - Expected: All event class tests pass
  - Command: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs/systems -gexit`
  - Expected: All publisher system tests pass
  - Command: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/vfx -gexit`
  - Expected: All VFX integration tests pass (13 existing + 4 new)

- [ ] **T1.13**: Manual verification
  - Play game → take damage → verify screen shake + damage flash
  - Fall from height → verify screen shake only
  - Die → verify both screen shake + damage flash
  - Check console → no errors or warnings

- [x] **T1.14**: Update existing VFX Manager tests
  - Location: `tests/unit/managers/test_vfx_manager.gd`
  - Replace: Gameplay event dispatches with VFX request event dispatches
  - Update: Event handler tests to match new signatures
  - Verify: All 17 existing tests still pass

### Commit Point
- [x] **Commit Phase 1**: "refactor(vfx): decouple VFX Manager via publisher systems" (`6860034`)
  - Summary: Introduced VFX request events and publisher systems
  - Changes: 2 new event classes, 2 new systems, updated M_VFXManager
  - Tests: ECS event unit tests (11), ECS system unit tests (203), VFX integration tests (17), style enforcement (8) all passing

**Completion Notes (2026-01-16)**:
- Commit: `6860034` (implementation).
- Tests run: ECS event unit tests, ECS system unit tests, VFX integration tests, style enforcement (all passing).
- Manual verification pending (T1.13).
- Integration camera test updated to use request events.

---

## Phase 2: Service Locator & Dependency Injection

**Goal**: Add explicit dependency injection for testability while maintaining discovery fallback.

**Current State**: M_VFXManager discovers dependencies via ServiceLocator/groups
**Target State**: @export injection with fallback to discovery

### Tests (Write First - TDD)

- [x] **T2.1**: Write test for VFX Manager dependency injection
  - Location: `tests/unit/managers/test_vfx_manager_injection.gd`
  - Extends: `GutTest`
  - Tests:
    - `test_uses_injected_state_store`
    - `test_uses_injected_camera_manager`
    - `test_injection_overrides_discovery`
    - `test_fallback_to_discovery_when_no_injection`
  - Use `MockStateStore` and `MockCameraManager`
  - Tests RED initially ✅

### Implementation

- [x] **T2.2**: Add dependency injection exports to `M_VFXManager`
  - Location: `scripts/managers/m_vfx_manager.gd`
  - After line 27 (after constants), add:
    ```gdscript
    ## Injected dependencies (for testing)
    @export var state_store: I_StateStore = null
    @export var camera_manager: M_CameraManager = null
    ```
  - Update `_ready()` to check injection first:
    ```gdscript
    # Use injected or discover
    if state_store != null:
        _state_store = state_store
    else:
        _state_store = U_STATE_UTILS.try_get_store(self)

    if camera_manager != null:
        _camera_manager = camera_manager
    else:
        _camera_manager = U_SERVICE_LOCATOR.try_get_service(StringName("camera_manager"))
    ```
  - Tests GREEN ✅

- [x] **T2.3**: Update `root.gd` to register VFX Manager with ServiceLocator
  - Location: `scripts/root.gd`
  - Find `_register_services()` or equivalent
  - After camera_manager registration, add:
    ```gdscript
    var vfx_manager := get_node_or_null("M_VFXManager")
    if vfx_manager != null:
        U_SERVICE_LOCATOR.register(StringName("vfx_manager"), vfx_manager)
    ```

- [x] **T2.4**: Remove self-registration from `M_VFXManager`
  - Location: `scripts/managers/m_vfx_manager.gd`
  - Remove: Line 61 `U_SERVICE_LOCATOR.register(StringName("vfx_manager"), self)`
  - Keep: `add_to_group("vfx_manager")` for backward compatibility

### Verification

- [x] **T2.5**: Run Phase 2 tests
  - Verify: Injection tests pass
  - Verify: Existing VFX tests still pass (discovery fallback)
  - Ran: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/managers/test_vfx_manager_injection.gd -gexit`
  - Ran: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/managers/test_vfx_manager.gd -gexit`

- [ ] **T2.6**: Manual verification
  - Play game → verify VFX still works (discovery path)
  - Check console → no error messages about missing dependencies

### Commit Point
- [x] **Commit Phase 2**: "refactor(vfx): add dependency injection with discovery fallback" (`9cde55d`)

---

## Phase 3: Player-Only & Transition Gating

**Goal**: Prevent non-player entities and inappropriate states from triggering VFX.

**Current State**: All entities trigger VFX, no transition blocking
**Target State**: Only player entity triggers VFX, blocked during transitions/menus

### Tests (Write First - TDD)

- [x] **T3.1**: Write test for `_is_player_entity()` helper
  - Location: `tests/unit/managers/test_vfx_manager_player_gating.gd`
  - Tests:
    - `test_returns_true_for_player_entity_id`
    - `test_returns_false_for_non_player_entity_id`
    - `test_returns_false_when_player_entity_id_empty` (fallback: BLOCK VFX)
    - `test_returns_false_when_no_state_store` (fallback: BLOCK VFX)
  - Mock StateStore with `gameplay.player_entity_id` field
  - Tests RED initially ✅

- [x] **T3.2**: Write test for `_is_transition_blocked()` helper
  - Location: `tests/unit/managers/test_vfx_manager_transition_gating.gd`
  - Tests:
    - `test_blocked_when_is_transitioning_true`
    - `test_blocked_when_scene_stack_not_empty`
    - `test_blocked_when_shell_not_gameplay`
    - `test_allowed_in_normal_gameplay`
    - `test_allowed_when_no_state_store` (fallback to false)
  - Mock StateStore with scene and navigation slices
  - Tests RED initially ✅

- [x] **T3.3**: Write integration test for player-only gating
  - Location: `tests/integration/vfx/test_vfx_player_only_gating.gd`
  - Setup: Create player entity (entity_id="player") and enemy entity
  - Publish: `screen_shake_request` with enemy entity_id → verify no shake
  - Publish: `screen_shake_request` with player entity_id → verify shake applied
  - Publish: `damage_flash_request` with enemy entity_id → verify no flash
  - Publish: `damage_flash_request` with player entity_id → verify flash applied
  - Tests RED initially ✅

- [x] **T3.4**: Write integration test for transition blocking
  - Location: `tests/integration/vfx/test_vfx_transition_blocking.gd`
  - Setup: Create VFX manager with mock state store
  - Test: Normal gameplay (shell="gameplay", not transitioning) → VFX works
  - Test: During transition (is_transitioning=true) → VFX blocked
  - Test: In menu (shell="main_menu") → VFX blocked
  - Test: With overlay (scene_stack=["pause_menu"]) → VFX blocked
  - Tests RED initially ✅

### Implementation

- [x] **T3.5**: Add gating constants to `M_VFXManager`
  - Add preload statements:
    ```gdscript
    const U_GAMEPLAY_SELECTORS := preload("res://scripts/state/selectors/u_gameplay_selectors.gd")
    const U_SCENE_SELECTORS := preload("res://scripts/state/selectors/u_scene_selectors.gd")
    const U_NAVIGATION_SELECTORS := preload("res://scripts/state/selectors/u_navigation_selectors.gd")
    ```

- [x] **T3.5b**: Create `u_scene_selectors.gd` (REQUIRED - does not exist)
  - Location: `scripts/state/selectors/u_scene_selectors.gd`
  - Class name: `U_SceneSelectors`
  - Add selector:
    ```gdscript
    class_name U_SceneSelectors
    extends RefCounted

    ## Check if scene is currently transitioning
    static func is_transitioning(scene_slice: Dictionary) -> bool:
        return bool(scene_slice.get("is_transitioning", false))

    ## Get current scene stack
    static func get_scene_stack(scene_slice: Dictionary) -> Array:
        return scene_slice.get("scene_stack", [])
    ```
  - Follow existing selector patterns (u_navigation_selectors.gd, u_vfx_selectors.gd)

- [x] **T3.6**: Add `_is_player_entity()` helper to `M_VFXManager`
  - Add method:
    ```gdscript
    ## Check if entity_id matches the player entity
    func _is_player_entity(entity_id: StringName) -> bool:
        if _state_store == null:
            return false  # Fallback: BLOCK VFX if no store (safer)
        var state: Dictionary = _state_store.get_state()
        var gameplay: Dictionary = state.get("gameplay", {})
        var player_entity_id: StringName = StringName(str(gameplay.get("player_entity_id", "")))
        if player_entity_id.is_empty():
            return false  # Fallback: BLOCK VFX if no player registered (safer)
        return entity_id == player_entity_id
    ```
  - Tests GREEN ✅

- [x] **T3.7**: Add `_is_transition_blocked()` helper to `M_VFXManager`
  - Add method:
    ```gdscript
    ## Check if VFX should be blocked due to transitions or non-gameplay state
    func _is_transition_blocked() -> bool:
        if _state_store == null:
            return false
        var state: Dictionary = _state_store.get_state()

        # Block during scene transitions
        var scene_slice: Dictionary = state.get("scene", {})
        if U_SCENE_SELECTORS.is_transitioning(scene_slice):
            return true

        # Block if scene stack is not empty (loading/overlay scenes)
        var scene_stack: Array = scene_slice.get("scene_stack", [])
        if not scene_stack.is_empty():
            return true

        # Block if not in gameplay shell
        var nav_slice: Dictionary = state.get("navigation", {})
        var shell: StringName = U_NAVIGATION_SELECTORS.get_shell(nav_slice)
        if shell != StringName("gameplay"):
            return true

        return false
    ```
  - Tests GREEN ✅

- [x] **T3.8**: Update `_on_screen_shake_request()` with gating
  - Add gating checks at start:
    ```gdscript
    func _on_screen_shake_request(event_data: Dictionary) -> void:
        var payload: Dictionary = event_data.get("payload", {})
        var entity_id: StringName = StringName(str(payload.get("entity_id", "")))

        # Gating: player-only and transition check
        if not _is_player_entity(entity_id):
            return
        if _is_transition_blocked():
            return

        _shake_requests.append(event_data)
    ```
  - Tests GREEN ✅

- [x] **T3.9**: Update `_on_damage_flash_request()` with gating
  - Add gating checks:
    ```gdscript
    func _on_damage_flash_request(event_data: Dictionary) -> void:
        if _state_store == null or _damage_flash == null:
            return

        var payload: Dictionary = event_data.get("payload", {})
        var entity_id: StringName = StringName(str(payload.get("entity_id", "")))

        # Gating: player-only and transition check
        if not _is_player_entity(entity_id):
            return
        if _is_transition_blocked():
            return

        _flash_requests.append(event_data)
    ```
  - Tests GREEN ✅

### Verification

- [x] **T3.10**: Run Phase 3 tests
  - Verify: All gating unit tests pass
  - Verify: All gating integration tests pass
  - Ran: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/managers -gexit`
  - Ran: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/vfx -gexit`
  - Ran: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/style/test_style_enforcement.gd -gexit`

- [ ] **T3.11**: Manual verification
  - Play as player → take damage → VFX works
  - Pause game → unpause → VFX works
  - Transition between scenes → no VFX during transition
  - Open main menu → no VFX
  - TODO: Verify enemy damage doesn't trigger VFX (need enemy entity in test scene)

### Commit Point
- [x] **Commit Phase 3**: "feat(vfx): add player-only and transition gating" (`4ec288a`)

**Completion Notes (2026-01-17)**:
- Added player-only gating and transition blocking helpers in `M_VFXManager`
- Added `U_SceneSelectors` for scene slice checks
- Added unit + integration gating tests and updated VFX integration setup for gameplay shell/player ID
- Tests run: unit managers, VFX integration, style enforcement (all passing)
- Manual verification still pending (T3.11)

---

## Phase 4: Resource-Driven Configuration

**Goal**: Move magic numbers from code to resources for easy tuning.

**Current State**: Hardcoded trauma values in publisher system constants
**Target State**: Tuning parameters in `RS_ScreenShakeTuning` resource

### Tests (Write First - TDD)

- [x] **T4.1**: Write test for `RS_ScreenShakeTuning` calculations
  - Location: `tests/unit/ecs/resources/test_rs_screen_shake_tuning.gd`
  - Tests:
    - `test_calculate_damage_trauma_zero_returns_zero`
    - `test_calculate_damage_trauma_at_midpoint`
    - `test_calculate_damage_trauma_at_max`
    - `test_calculate_landing_trauma_below_threshold_returns_zero`
    - `test_calculate_landing_trauma_at_threshold`
    - `test_calculate_landing_trauma_at_max`
    - `test_death_trauma_field_accessible`
  - Tests RED initially ✅

- [x] **T4.2**: Write test for publisher with tuning resource
  - Location: Update `tests/unit/ecs/systems/test_s_screen_shake_publisher_system.gd`
  - Add tests:
    - `test_uses_injected_tuning_resource`
    - `test_fallback_to_default_tuning_when_not_injected`
    - `test_custom_tuning_affects_trauma_calculation`
  - Tests RED initially ✅

### Implementation

- [x] **T4.3**: Create `RS_ScreenShakeTuning` resource class
  - Location: `scripts/ecs/resources/rs_screen_shake_tuning.gd`
  - Extends: `Resource`
  - Class name: `RS_ScreenShakeTuning`
  - Fields:
    ```gdscript
    @export_group("Decay")
    @export var trauma_decay_rate: float = 2.0

    @export_group("Damage")
    @export var damage_min_trauma: float = 0.3
    @export var damage_max_trauma: float = 0.6
    @export var damage_max_value: float = 100.0

    @export_group("Landing")
    @export var landing_threshold: float = 15.0
    @export var landing_max_speed: float = 30.0
    @export var landing_min_trauma: float = 0.2
    @export var landing_max_trauma: float = 0.4

    @export_group("Death")
    @export var death_trauma: float = 0.5
    ```
  - Methods:
    ```gdscript
    func calculate_damage_trauma(damage_amount: float) -> float:
        if damage_amount <= 0.0:
            return 0.0
        var damage_ratio := clampf(damage_amount / damage_max_value, 0.0, 1.0)
        return lerpf(damage_min_trauma, damage_max_trauma, damage_ratio)

    func calculate_landing_trauma(fall_speed: float) -> float:
        if fall_speed <= landing_threshold:
            return 0.0
        var speed_ratio := clampf((fall_speed - landing_threshold) / (landing_max_speed - landing_threshold), 0.0, 1.0)
        return lerpf(landing_min_trauma, landing_max_trauma, speed_ratio)
    ```
  - Tests GREEN ✅

- [x] **T4.4**: Create default tuning resource file
  - Location: `resources/vfx/cfg_screen_shake_tuning.tres`
  - Format:
    ```
    [gd_resource type="Resource" script_class="RS_ScreenShakeTuning" load_steps=2 format=3]

    [ext_resource type="Script" path="res://scripts/ecs/resources/rs_screen_shake_tuning.gd" id="1"]

    [resource]
    script = ExtResource("1")
    trauma_decay_rate = 2.0
    damage_min_trauma = 0.3
    damage_max_trauma = 0.6
    damage_max_value = 100.0
    landing_threshold = 15.0
    landing_max_speed = 30.0
    landing_min_trauma = 0.2
    landing_max_trauma = 0.4
    death_trauma = 0.5
    ```

- [x] **T4.5**: Create `RS_ScreenShakeConfig` resource class
  - Location: `scripts/ecs/resources/rs_screen_shake_config.gd`
  - Extends: `Resource`
  - Class name: `RS_ScreenShakeConfig`
  - Fields:
    ```gdscript
    @export var max_offset: Vector2 = Vector2(10.0, 8.0)
    @export var max_rotation: float = 0.05
    @export var noise_speed: float = 50.0
    ```

- [x] **T4.6**: Create default config resource file
  - Location: `resources/vfx/cfg_screen_shake_config.tres`
  - Set default values from U_ScreenShake

- [x] **T4.7**: Update `S_ScreenShakePublisherSystem` to use tuning
  - Add export:
    ```gdscript
    @export var tuning: RS_ScreenShakeTuning = null
    ```
  - Add helper:
    ```gdscript
    func _get_tuning() -> RS_ScreenShakeTuning:
        if tuning != null:
            return tuning
        # Fallback to default
        return preload("res://resources/vfx/cfg_screen_shake_tuning.tres")
    ```
  - Replace constants with tuning calls:
    ```gdscript
    func _on_health_changed(event_data: Dictionary) -> void:
        # ... payload extraction ...
        var trauma_amount := _get_tuning().calculate_damage_trauma(damage_amount)
        if trauma_amount <= 0.0:
            return
        # ... publish event ...

    func _on_landed(event_data: Dictionary) -> void:
        # ... payload extraction ...
        var trauma_amount := _get_tuning().calculate_landing_trauma(fall_speed)
        if trauma_amount <= 0.0:
            return
        # ... publish event ...

    func _on_death(event_data: Dictionary) -> void:
        # ... payload extraction ...
        var trauma_amount := _get_tuning().death_trauma
        # ... publish event ...
    ```
  - Remove all constants
  - Tests GREEN ✅
  - Note: `tuning` is typed as `Resource` to avoid headless `class_name` parse errors (see DEV_PITFALLS).

- [x] **T4.8**: Update `U_ScreenShake` to accept config resource
  - Add constructor parameter:
    ```gdscript
    func _init(config: RS_ScreenShakeConfig = null) -> void:
        if config != null:
            max_offset = config.max_offset
            max_rotation = config.max_rotation
            noise_speed = config.noise_speed

        _noise = FastNoiseLite.new()
        _noise.seed = randi()
        _noise.frequency = 1.0
    ```
  - Note: `config` is typed as `Resource` to avoid headless `class_name` parse errors (see DEV_PITFALLS).

- [x] **T4.9**: Update `M_VFXManager` to use config resource
  - Update `_ready()`:
    ```gdscript
    var shake_config := preload("res://resources/vfx/cfg_screen_shake_config.tres")
    _screen_shake = U_ScreenShake.new(shake_config)
    ```
  - Remove `TRAUMA_DECAY_RATE` constant
  - Load decay rate from tuning resource if needed

### Verification

- [x] **T4.10**: Run Phase 4 tests
  - Verify: All resource calculation tests pass
  - Verify: Publisher system tests with tuning pass
  - Ran: `tools/run_gut_suite.sh -gdir=res://tests/unit/ecs/resources -gexit`
  - Ran: `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_s_screen_shake_publisher_system.gd -gexit` (passes; Godot aborted after summary with `recursive_mutex lock failed`)
  - Ran: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd -gexit`

- [ ] **T4.11**: Manual verification
  - Play game → verify VFX still works with default resources
  - Edit `cfg_screen_shake_tuning.tres` → change `damage_min_trauma` to 0.1
  - Play game → verify weaker shake on damage

### Commit Point
- [x] **Commit Phase 4**: "refactor(vfx): move tuning to resources" (`1dae3c9`)

---

## Phase 5: Typed Results & Helper Fixes

**Goal**: Fix alpha bug, improve helper APIs, add testing hooks.

**Current State**: Dictionary return from `calculate_shake()`, alpha bug in scene
**Target State**: Typed `U_ShakeResult`, alpha = 1.0 in scene, tween pause mode

### Tests (Write First - TDD)

- [x] **T5.1**: Write test for `U_ShakeResult` class
  - Location: `tests/unit/managers/helpers/test_shake_result.gd`
  - Tests:
    - `test_constructor_with_defaults`
    - `test_constructor_with_custom_values`
    - `test_offset_field_accessible`
    - `test_rotation_field_accessible`
  - Tests RED initially ✅

- [x] **T5.2**: Write test for deterministic U_ScreenShake
  - Location: Update `tests/unit/managers/helpers/test_screen_shake.gd`
  - Add tests:
    - `test_set_noise_seed_for_testing_makes_deterministic`
    - `test_set_sample_time_for_testing_freezes_time`
    - `test_get_sample_time_returns_current_time`
    - `test_calculate_shake_returns_shake_result_instance`
  - Tests RED initially ✅

- [x] **T5.3**: Write test for damage flash alpha correctness
  - Location: Update `tests/unit/managers/helpers/test_damage_flash.gd`
  - Add tests:
    - `test_flash_rect_color_alpha_is_1_0` (scene fix)
    - `test_tween_has_pause_mode_process` (tween fix)
  - Tests RED initially ✅

### Implementation

- [x] **T5.4**: Create `U_ShakeResult` class
  - Location: `scripts/managers/helpers/u_shake_result.gd`
  - Extends: `RefCounted`
  - Class name: `U_ShakeResult`
  - Fields:
    ```gdscript
    var offset: Vector2
    var rotation: float
    ```
  - Constructor:
    ```gdscript
    func _init(p_offset: Vector2 = Vector2.ZERO, p_rotation: float = 0.0) -> void:
        offset = p_offset
        rotation = p_rotation
    ```
  - Tests GREEN ✅

- [x] **T5.5**: Add testing hooks to `U_ScreenShake`
  - Add fields:
    ```gdscript
    var _test_seed: int = -1
    var _test_time: float = -1.0
    ```
  - Add methods:
    ```gdscript
    func set_noise_seed_for_testing(seed: int) -> void:
        _test_seed = seed
        if seed >= 0:
            _noise.seed = seed

    func set_sample_time_for_testing(time: float) -> void:
        _test_time = time

    func get_sample_time() -> float:
        return _time
    ```
  - Update `calculate_shake()`:
    ```gdscript
    func calculate_shake(trauma: float, intensity_multiplier: float, delta: float) -> U_ShakeResult:
        if _test_time >= 0.0:
            _time = _test_time
        else:
            _time += delta * noise_speed

        var shake_amount := trauma * trauma * intensity_multiplier

        var offset := Vector2(
            _noise.get_noise_1d(_time) * max_offset.x * shake_amount,
            _noise.get_noise_1d(_time + 100.0) * max_offset.y * shake_amount
        )
        var rotation_amount := _noise.get_noise_1d(_time + 200.0) * max_rotation * shake_amount

        return U_ShakeResult.new(offset, rotation_amount)
    ```
  - Tests GREEN ✅

- [x] **T5.6**: Update `M_VFXManager` to use `U_ShakeResult`
  - Update `_physics_process()`:
    ```gdscript
    var shake_result = _screen_shake.calculate_shake(_trauma, intensity, delta)
    _camera_manager.apply_shake_offset(shake_result.offset, shake_result.rotation)
    ```

- [x] **T5.7**: Fix alpha bug in damage flash scene
  - Location: `scenes/ui/ui_damage_flash_overlay.tscn`
  - Find: FlashRect ColorRect node
  - Change: `color = Color(1.0, 0.0, 0.0, 0.3)` → `color = Color(1.0, 0.0, 0.0, 1.0)`
  - Reason: `color.a` multiplies with `modulate.a` (0.3 * 0.3 = 0.09 actual)
  - Tests GREEN ✅

- [x] **T5.8**: Add tween pause mode to `U_DamageFlash`
  - Location: `scripts/managers/helpers/u_damage_flash.gd`
  - Update `trigger_flash()` after tween creation:
    ```gdscript
    _tween = _scene_tree.create_tween()
    _tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)  # Add this line
    _tween.tween_property(_flash_rect, "modulate:a", 0.0, FADE_DURATION)
    ```
  - Reason: Flash should continue during pause
  - Tests GREEN ✅

### Verification

- [x] **T5.9**: Run Phase 5 tests
  - Verify: U_ShakeResult tests pass
  - Verify: Deterministic shake tests pass
  - Verify: Alpha correctness tests pass
  - Ran: `tools/run_gut_suite.sh -gdir=res://tests/unit/managers/helpers -gexit`
  - Ran: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd -gexit`

- [ ] **T5.10**: Manual verification
  - Play game → take damage → verify damage flash is CLEARLY visible (red tint)
  - Compare: Flash should be ~3x more visible than before (0.3 vs 0.09)
  - Pause game → take damage → verify flash still animates

### Commit Point
- [x] **Commit Phase 5**: "fix(vfx): correct alpha bug and add typed results" (`994da2e`)

---

## Phase 6: Preload & Publisher Cleanup

**Goal**: Use compile-time loading and apply cleanup patterns to publisher systems.

**Note**: Unsubscribe array pattern already implemented in Phase 1 (T1.10). This phase focuses on preload and publisher system cleanup.

### Tests (Write First - TDD)

- [x] **T6.1**: Write test for preload usage
  - Location: `tests/unit/managers/test_vfx_manager_cleanup.gd`
  - Tests:
    - `test_damage_flash_scene_preloaded`
    - `test_no_load_calls_at_runtime`
  - Tests RED initially ✅

### Implementation

- [x] **T6.2**: Add preload for damage flash scene
  - Add constant at top of `M_VFXManager`:

    ```gdscript
    const DAMAGE_FLASH_SCENE := preload("res://scenes/ui/ui_damage_flash_overlay.tscn")
    ```

  - Replace in `_ready()`:

    ```gdscript
    # Before:
    var flash_scene: PackedScene = load("res://scenes/ui/ui_damage_flash_overlay.tscn")

    # After:
    var flash_scene: PackedScene = DAMAGE_FLASH_SCENE
    ```

  - Reason: Compile-time loading, faster startup

- [x] **T6.3**: Apply same pattern to publisher systems
  - Update: `S_ScreenShakePublisherSystem` with unsubscribe array
  - Update: `S_DamageFlashPublisherSystem` with unsubscribe array
  - Replace individual fields with `Array[Callable]`
  - Update cleanup logic

### Verification

- [x] **T6.4**: Run Phase 6 tests
  - Verify: Cleanup tests pass
  - Verify: No memory leaks reported
  - Notes: `tools/run_gut_suite.sh -gtest=res://tests/unit/managers/test_vfx_manager_cleanup.gd -gexit`

- [x] **T6.5**: Code review
  - Search: `load("res://scenes/ui/ui_damage_flash_overlay.tscn")` → 0 results
  - Verify: Only `preload()` used

### Commit Point

- [x] **Commit Phase 6**: "refactor(vfx): consolidate cleanup and use preload" (`b288afc`)

---

## Phase 7: Testing Improvements

**Goal**: Add comprehensive tests for all new gating and behavior.

### Implementation

- [x] **T7.1**: Create comprehensive player gating integration test
  - Location: `tests/integration/vfx/test_vfx_player_gating_comprehensive.gd`
  - Tests:
    - Enemy takes damage → no shake, no flash
    - Player takes damage → shake + flash
    - Enemy dies → no shake, no flash
    - Player dies → shake + flash
    - Enemy lands → no shake
    - Player lands → shake

- [x] **T7.2**: Create comprehensive transition gating integration test
  - Location: `tests/integration/vfx/test_vfx_transition_gating_comprehensive.gd`
  - Tests:
    - Normal gameplay → VFX works
    - is_transitioning=true → VFX blocked
    - scene_stack=["pause_menu"] → VFX blocked
    - shell="main_menu" → VFX blocked
    - shell="endgame" → VFX blocked
    - Transition completes → VFX resumes

- [x] **T7.3**: Update existing integration tests
  - Update: `tests/integration/vfx/test_vfx_camera_integration.gd`
  - Add: Gating verification to existing tests
  - Verify: Existing 5 tests still pass

- [x] **T7.4**: Update existing unit tests for new architecture
  - Update: `tests/unit/managers/test_vfx_manager.gd`
  - Replace: Old event structure with new VFX request events
  - Add: Request queue verification
  - Verify: All 17 original tests still pass

- [x] **T7.5**: Add deterministic shake tests
  - Location: Update `tests/unit/managers/helpers/test_screen_shake.gd`
  - Add tests using seed and time control:
    - `test_same_seed_produces_same_results`
    - `test_different_seeds_produce_different_results`
    - `test_frozen_time_produces_same_results`

### Verification

- [x] **T7.6**: Run full test suite
  - Command: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
  - Expected: All tests pass (existing + new)
  - Track: Total test count before/after
  - Notes: 1799 tests, 5 pending (headless timing skips)

### Commit Point

- [x] **Commit Phase 7**: "test(vfx): add comprehensive gating and behavior tests" (`5a882b7`)

---

## Phase 8: UI Settings Preview

**Goal**: Add live preview to VFX settings (matching audio settings pattern).

### Tests (Write First - TDD)

- [x] **T8.1**: Write test for preview settings
  - Location: `tests/unit/managers/test_vfx_manager_preview.gd`
  - Tests:
    - `test_set_preview_overrides_redux_state`
    - `test_clear_preview_reverts_to_redux_state`
    - `test_preview_affects_shake_enabled`
    - `test_preview_affects_shake_intensity`
    - `test_preview_affects_flash_enabled`
  - Tests RED initially ✅

- [x] **T8.2**: Write test for test shake trigger
  - Location: Update `tests/unit/managers/test_vfx_manager.gd`
  - Add tests:
    - `test_trigger_test_shake_adds_0_3_trauma`
    - `test_trigger_test_shake_with_intensity_scales_trauma`
    - `test_test_shake_respects_preview_settings`
  - Tests RED initially ✅

### Implementation

- [x] **T8.3**: Add preview state to `M_VFXManager`
  - Add fields:

    ```gdscript
    var _preview_settings: Dictionary = {}
    var _is_previewing: bool = false
    ```

- [x] **T8.4**: Add preview methods to `M_VFXManager`
  - Add methods:

    ```gdscript
    ## Apply temporary preview settings (for UI testing)
    func set_vfx_settings_preview(settings: Dictionary) -> void:
        _preview_settings = settings.duplicate()
        _is_previewing = true

    ## Clear preview and revert to Redux state
    func clear_vfx_settings_preview() -> void:
        _preview_settings.clear()
        _is_previewing = false

    ## Trigger a test shake for preview purposes
    func trigger_test_shake(intensity: float = 1.0) -> void:
        add_trauma(0.3 * intensity)
    ```

  - Tests GREEN ✅

- [x] **T8.5**: Add preview getters to `M_VFXManager`
  - Add methods:

    ```gdscript
    ## Get effective screen shake enabled (preview or state)
    func _get_screen_shake_enabled() -> bool:
        if _is_previewing and _preview_settings.has("screen_shake_enabled"):
            return _preview_settings.get("screen_shake_enabled", true)
        if _state_store == null:
            return true
        return U_VFX_SELECTORS.is_screen_shake_enabled(_state_store.get_state())

    ## Get effective screen shake intensity (preview or state)
    func _get_screen_shake_intensity() -> float:
        if _is_previewing and _preview_settings.has("screen_shake_intensity"):
            return _preview_settings.get("screen_shake_intensity", 1.0)
        if _state_store == null:
            return 1.0
        return U_VFX_SELECTORS.get_screen_shake_intensity(_state_store.get_state())

    ## Get effective damage flash enabled (preview or state)
    func _get_damage_flash_enabled() -> bool:
        if _is_previewing and _preview_settings.has("damage_flash_enabled"):
            return _preview_settings.get("damage_flash_enabled", true)
        if _state_store == null:
            return true
        return U_VFX_SELECTORS.is_damage_flash_enabled(_state_store.get_state())
    ```

- [x] **T8.6**: Update `_physics_process()` to use preview getters
  - Replace:

    ```gdscript
    # Before:
    if U_VFX_SELECTORS.is_screen_shake_enabled(state):
        var intensity := U_VFX_SELECTORS.get_screen_shake_intensity(state)

    # After:
    if _get_screen_shake_enabled():
        var intensity := _get_screen_shake_intensity()
    ```

- [x] **T8.7**: Update `UI_VFXSettingsOverlay` to use preview
  - Location: `scripts/ui/settings/ui_vfx_settings_overlay.gd`
  - Add in `_ready()`:

    ```gdscript
    _vfx_manager = U_SERVICE_LOCATOR.try_get_service(StringName("vfx_manager")) as M_VFXManager
    ```

  - Add in `_exit_tree()`:

    ```gdscript
    _clear_vfx_settings_preview()
    ```

  - Update `_on_intensity_changed()`:

    ```gdscript
    func _on_intensity_changed(value: float) -> void:
        _update_percentage_label(value)
        if _updating_from_state:
            return
        U_UISoundPlayer.play_slider_tick()
        _has_local_edits = true
        _update_vfx_settings_preview_from_ui()
        # Trigger test shake on slider change
        if _vfx_manager != null:
            _vfx_manager.trigger_test_shake(value)
    ```

  - Add method:

    ```gdscript
    func _update_vfx_settings_preview_from_ui() -> void:
        if _vfx_manager == null:
            return
        _vfx_manager.set_vfx_settings_preview({
            "screen_shake_enabled": _shake_enabled_toggle.button_pressed if _shake_enabled_toggle != null else true,
            "screen_shake_intensity": _intensity_slider.value if _intensity_slider != null else 1.0,
            "damage_flash_enabled": _flash_enabled_toggle.button_pressed if _flash_enabled_toggle != null else true,
        })
    ```

  - Add method:

    ```gdscript
    func _clear_vfx_settings_preview() -> void:
        if _vfx_manager == null:
            return
        _vfx_manager.clear_vfx_settings_preview()
    ```

  - Update `_on_cancel_pressed()`:

    ```gdscript
    func _on_cancel_pressed() -> void:
        U_UISoundPlayer.play_cancel()
        _has_local_edits = false
        _clear_vfx_settings_preview()
        _close_overlay()
    ```

- [x] **T8.8**: Update enable toggle handlers to trigger preview
  - Update `_on_shake_enabled_changed()`:

    ```gdscript
    func _on_shake_enabled_changed(toggled_on: bool) -> void:
        if _updating_from_state:
            return
        U_UISoundPlayer.play_toggle()
        _has_local_edits = true
        _update_vfx_settings_preview_from_ui()
    ```

  - Update `_on_flash_enabled_changed()` similarly

### Verification

- [ ] **T8.9**: Run Phase 8 tests
  - Verify: Preview tests pass
  - Verify: Test shake tests pass

- [ ] **T8.10**: Manual verification
  - Open VFX settings
  - Move intensity slider → verify test shake triggers
  - Higher intensity → stronger shake
  - Lower intensity → weaker shake
  - Toggle shake off → no test shake
  - Toggle shake on → test shake resumes
  - Click Cancel → settings revert, preview cleared

### Commit Point

- [x] **Commit Phase 8**: "feat(vfx): add live preview to settings UI"

---

## Phase 9: Documentation Updates

**Goal**: Update all documentation to reflect new architecture.

### Implementation

- [ ] **T9.1**: Update AGENTS.md with VFX Manager patterns
  - Location: `AGENTS.md`
  - After existing manager patterns, add:

    ```markdown
    ## VFX Manager Patterns

    ### Event Architecture
    - Publisher systems translate gameplay events → VFX request events
    - M_VFXManager subscribes only to VFX request events
    - Separation of concerns: publishers decide *when*, manager executes *how*

    ### Gating
    - Player-only: Only player entity triggers screen shake/flash
    - Transition blocking: No VFX during transitions, overlays, or non-gameplay shells
    - Use `_is_player_entity()` and `_is_transition_blocked()` helpers

    ### Resource-Driven Tuning
    - `RS_ScreenShakeTuning` for trauma calculation parameters
    - `RS_ScreenShakeConfig` for visual shake parameters
    - All magic numbers externalized to resources

    ### Preview Pattern
    - VFX settings supports live preview via `set_vfx_settings_preview()`
    - Test shake triggers on intensity slider change
    - Preview cleared on cancel or overlay close
    ```

- [ ] **T9.2**: Update DEV_PITFALLS.md with VFX pitfalls
  - Location: `docs/general/DEV_PITFALLS.md`
  - Add section:

    ```markdown
    ## VFX Pitfalls

    ### Alpha Bug
    - ColorRect.color.a multiplies with modulate.a
    - Set color.a = 1.0 in scene, control visibility via modulate.a only
    - Example: color=(1,0,0,0.3) + modulate.a=0.3 = 0.09 actual alpha (bug!)

    ### Tween Pause Mode
    - Use `tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)` for effects that should continue during pause
    - Damage flash should animate even when game is paused

    ### Preload vs Load
    - Use `preload()` for VFX scenes loaded at startup (compile-time)
    - `load()` only for dynamically determined paths (runtime)
    - Performance: preload is instant, load can cause frame hitches

    ### Player-Only Gating
    - Always check `_is_player_entity()` before applying VFX
    - Enemy damage should not trigger player VFX
    - Use Redux `gameplay.player_entity_id` as source of truth

    ### Transition Blocking
    - Check `_is_transition_blocked()` before applying VFX
    - No VFX during: scene transitions, menus, pause overlays
    - Prevents jarring effects during loading screens
    ```

- [ ] **T9.3**: Create vfx-manager-continuation-prompt.md
  - Location: `docs/vfx_manager/vfx-manager-continuation-prompt.md`
  - Content:

    ```markdown
    ## Current Status (2026-01-15)

    **Refactoring Complete**: All 9 phases finished
    - Event architecture with publisher systems
    - Player-only and transition gating
    - Resource-driven configuration
    - Typed results and testing hooks
    - Request queue pattern
    - Event constants
    - Comprehensive testing
    - Live preview in settings UI
    - Documentation updated

    **Test Coverage**:
    - Unit tests: XX passing (Redux + Manager + Helpers + Systems + Events + Resources)
    - Integration tests: XX passing (Event flow + Gating + Settings UI)

    **Architecture**:
    - Gameplay Events → Publisher Systems → VFX Request Events → VFX Manager
    - Player-only gating via Redux state
    - Transition blocking via scene/navigation state
    - All tuning parameters in resources
    ```

- [ ] **T9.4**: Update this tasks document with completion summary
  - Add completion date to each phase
  - Add final test counts
  - Add links to commits
  - Add architectural summary

### Verification

- [ ] **T9.5**: Documentation review
  - Read through all updated docs
  - Verify: Patterns match implementation
  - Verify: Examples are correct
  - Verify: No contradictions with existing docs

### Commit Point

- [ ] **Commit Phase 9**: "docs(vfx): update documentation for refactored architecture"

---

## Final Completion Checklist

- [ ] All 9 phases complete
- [ ] All tests pass (unit + integration)
- [ ] No console warnings or errors during gameplay
- [ ] Manual smoke test complete:
  - [ ] Player damage triggers shake + flash
  - [ ] Enemy damage triggers nothing
  - [ ] Player landing triggers shake
  - [ ] During transition → no VFX
  - [ ] In menu → no VFX
  - [ ] Settings preview works (slider triggers test shake)
  - [ ] Shake intensity slider affects magnitude
  - [ ] Enable toggles work
- [ ] Code review complete:
  - [ ] No magic numbers (all in resources)
  - [ ] No string literals (all use constants)
  - [ ] All unsubscribes use array pattern
  - [ ] All preload instead of load
- [ ] Documentation updated and reviewed
- [ ] All commits made with meaningful messages
- [ ] Continuation prompt updated

---

## Notes

### Key Architectural Changes

1. **Event Architecture**: Gameplay events → Publisher Systems → VFX Request Events → VFX Manager
2. **Separation of Concerns**: Publishers decide *when* (gameplay logic), Manager decides *how* (VFX execution)
3. **Player-Only Gating**: Only `gameplay.player_entity_id` triggers VFX
4. **Transition Blocking**: No VFX during transitions, menus, or overlays
5. **Resource-Driven**: All tuning moved to `RS_ScreenShakeTuning` and `RS_ScreenShakeConfig`
6. **Type Safety**: `U_ShakeResult` typed result, `Evn_*Request` event classes
7. **Testability**: Dependency injection, deterministic shake via testing hooks
8. **Cleanup**: Unsubscribe array pattern, preload instead of load

### Testing Strategy

- **TDD**: Write tests first for each feature (RED → GREEN → REFACTOR)
- **Unit Tests**: Isolated components with mocks (events, systems, manager, helpers, resources)
- **Integration Tests**: Full event flow (gameplay → publishers → manager → camera)
- **Manual Tests**: Visual verification and edge case exploration

### Performance Improvements

- **Preload**: Damage flash scene loads at compile-time (no runtime hitching)
- **Request Queue**: Batches multiple requests per frame (deterministic ordering)
- **Resource Caching**: Tuning resources loaded once, reused for all calculations

### Backward Compatibility

- **Discovery Fallback**: Dependency injection optional, discovery still works
- **Same Public API**: `add_trauma()` and `get_trauma()` unchanged
- **Gameplay Events**: Still published by systems (publishers consume them)
- **Scene Structure**: Systems added to gameplay scene (not replaced)

### Common Pitfalls

1. **Alpha Multiplication**: `color.a * modulate.a` = final alpha (set color.a=1.0)
2. **Tween Pause Mode**: Use `TWEEN_PAUSE_PROCESS` for effects during pause
3. **Player Gating**: Always check `_is_player_entity()` before VFX
4. **Transition Blocking**: Always check `_is_transition_blocked()` before VFX
5. **Unsubscribe Leaks**: Use array pattern, clear in `_exit_tree()`
6. **Request Ordering**: Process queues in `_physics_process()`, not event handlers

### Future Enhancements (Deferred)

- **Trauma Event Weighting**: Configurable trauma amounts per event type
- **Shake Frequency Customization**: Expose noise parameters for different "feels"
- **Flash Color Customization**: Support different colors per damage type
- **Directional Shake**: Shake direction based on damage source position
- **Intensity Curves**: Non-linear trauma-to-shake mapping curves
- **Multi-Entity Support**: Allow non-player entities to opt-in to VFX
