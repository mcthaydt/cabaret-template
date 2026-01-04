# VFX Manager PRD

**Project**: Cabaret Template (Godot 4.5)
**Owner**: Development Team
**Feature Branch**: `feature/vfx-manager`
**Created**: 2026-01-01
**Last Updated**: 2026-01-04
**Target Release**: Phase 6 (Testing & Integration)
**Status**: IMPLEMENTED (Phases 0-5); Phase 6 pending
**Version**: 1.1

## Problem Statement

### What Problem Are We Solving?

Players currently experience no visual feedback for impactful gameplay events like taking damage, landing heavily, or dying. The lack of screen-level visual effects (screen shake, damage flash) makes combat feel weightless and impacts difficult to perceive. While the game has excellent particle systems for local effects, there's no orchestration layer for screen-wide visual feedback.

### Why Now?

- **Gameplay Feel**: Combat and movement lack visceral feedback, making hits and falls feel unsatisfying
- **Accessibility**: Players with audio disabilities have no alternative feedback for damage events
- **Game Juice**: Screen effects are essential for action platformers, currently missing from the template
- **Settings Control**: Users cannot adjust or disable screen shake/flash for motion sensitivity

### User Impact

**Without VFX Manager**:
- Taking damage has no visual indication beyond health bar changes
- Heavy landings feel identical to light landings
- Screen shake is impossible to implement without manager coordination
- No settings to control motion-sensitive effects

**With VFX Manager**:
- Camera shake on damage/landings adds weight and impact
- Red flash overlay provides clear damage indication
- Settings panel allows users to disable/reduce effects for accessibility
- Centralized VFX coordination via Redux state

## Goals

1. **Screen Shake System**: Implement trauma-based screen shake triggered by gameplay events
2. **Damage Flash Overlay**: Red vignette flash when player takes damage
3. **Redux Integration**: VFX settings stored in Redux state, persisted to save files
4. **Accessibility Controls**: Toggle and intensity slider for screen shake, toggle for damage flash
5. **Camera Manager Integration**: Add shake offset methods to existing camera manager
6. **Event-Driven Architecture**: Subscribe to ECS events for trauma triggers
7. **Settings Persistence**: VFX preferences saved with game progress

## Non-Goals

- **Post-Processing Effects** (film grain, CRT, Lomo, bloom, vignette persistent effects) - Deferred to Display Manager
- **Graphics Quality Settings** (resolution, fullscreen, vsync, quality presets) - Deferred to Display Manager
- **Particle System Changes** - Existing systems (`S_JumpParticlesSystem`, `S_LandingParticlesSystem`, etc.) remain unchanged
- **Complex Shader Effects** (distortion, heat haze, chromatic aberration) - Out of scope for initial implementation
- **Directional Damage Indicators** - Future enhancement
- **WorldEnvironment Configuration** - Display Manager responsibility

## Functional Requirements

### Phase 0: Redux Foundation (FR-001 to FR-005)

**FR-001: VFX Redux Slice**
The VFX system SHALL define a Redux slice named `vfx` with the following fields:

| Field | Type | Default | Range/Values | Description |
|-------|------|---------|--------------|-------------|
| `screen_shake_enabled` | bool | true | true/false | Global screen shake toggle |
| `screen_shake_intensity` | float | 1.0 | 0.0-2.0 | Shake intensity multiplier |
| `damage_flash_enabled` | bool | true | true/false | Damage flash effect toggle |

**FR-002: VFX Action Creators**
The system SHALL provide action creators in `U_VFXActions`:

```gdscript
class_name U_VFXActions
extends RefCounted

const ACTION_SET_SCREEN_SHAKE_ENABLED := StringName("vfx/set_screen_shake_enabled")
const ACTION_SET_SCREEN_SHAKE_INTENSITY := StringName("vfx/set_screen_shake_intensity")
const ACTION_SET_DAMAGE_FLASH_ENABLED := StringName("vfx/set_damage_flash_enabled")

## Static initializer - automatically registers actions
static func _static_init() -> void:
	U_ActionRegistry.register_action(ACTION_SET_SCREEN_SHAKE_ENABLED)
	U_ActionRegistry.register_action(ACTION_SET_SCREEN_SHAKE_INTENSITY)
	U_ActionRegistry.register_action(ACTION_SET_DAMAGE_FLASH_ENABLED)

static func set_screen_shake_enabled(enabled: bool) -> Dictionary:
	return {
		"type": ACTION_SET_SCREEN_SHAKE_ENABLED,
		"payload": {"enabled": enabled}
	}

static func set_screen_shake_intensity(intensity: float) -> Dictionary:
	return {
		"type": ACTION_SET_SCREEN_SHAKE_INTENSITY,
		"payload": {"intensity": intensity}
	}

static func set_damage_flash_enabled(enabled: bool) -> Dictionary:
	return {
		"type": ACTION_SET_DAMAGE_FLASH_ENABLED,
		"payload": {"enabled": enabled}
	}
```

**FR-003: VFX Reducer**
The system SHALL implement `U_VFXReducer` with:
- Immutable state updates (no mutations)
- Intensity clamping to 0.0-2.0 range
- Unknown action handling (return unchanged state)

```gdscript
class_name U_VFXReducer
extends RefCounted

const U_VFX_ACTIONS := preload("res://scripts/state/actions/u_vfx_actions.gd")

static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
	var action_type: StringName = action.get("type", StringName(""))
	var payload: Dictionary = action.get("payload", {})

	match action_type:
		U_VFX_ACTIONS.ACTION_SET_SCREEN_SHAKE_ENABLED:
			var new_state := state.duplicate(true)
			new_state["screen_shake_enabled"] = payload.get("enabled", true)
			return new_state

		U_VFX_ACTIONS.ACTION_SET_SCREEN_SHAKE_INTENSITY:
			var new_state := state.duplicate(true)
			var intensity: float = payload.get("intensity", 1.0)
			new_state["screen_shake_intensity"] = clampf(intensity, 0.0, 2.0)
			return new_state

		U_VFX_ACTIONS.ACTION_SET_DAMAGE_FLASH_ENABLED:
			var new_state := state.duplicate(true)
			new_state["damage_flash_enabled"] = payload.get("enabled", true)
			return new_state

		_:
			return state
```

**FR-004: VFX Selectors**
The system SHALL provide selectors in `U_VFXSelectors`:

```gdscript
class_name U_VFXSelectors
extends RefCounted

static func is_screen_shake_enabled(state: Dictionary) -> bool:
	var vfx_slice: Dictionary = state.get("vfx", {})
	return vfx_slice.get("screen_shake_enabled", true)

static func get_screen_shake_intensity(state: Dictionary) -> float:
	var vfx_slice: Dictionary = state.get("vfx", {})
	return vfx_slice.get("screen_shake_intensity", 1.0)

static func is_damage_flash_enabled(state: Dictionary) -> bool:
	var vfx_slice: Dictionary = state.get("vfx", {})
	return vfx_slice.get("damage_flash_enabled", true)
```

**FR-005: VFX Initial State Resource**
The system SHALL define `RS_VFXInitialState` resource:

```gdscript
class_name RS_VFXInitialState
extends Resource

@export var screen_shake_enabled: bool = true
@export var screen_shake_intensity: float = 1.0
@export var damage_flash_enabled: bool = true

func to_dictionary() -> Dictionary:
	return {
		"screen_shake_enabled": screen_shake_enabled,
		"screen_shake_intensity": screen_shake_intensity,
		"damage_flash_enabled": damage_flash_enabled,
	}
```

### Phase 1: Core Manager (FR-006 to FR-010)

**FR-006: M_VFXManager Lifecycle**
The VFX Manager SHALL:
- Extend `Node` with `process_mode = PROCESS_MODE_ALWAYS`
- Add itself to `"vfx_manager"` group on `_ready()`
- Register with `U_ServiceLocator` as `"vfx_manager"`
- Maintain single instance pattern (only one VFX manager in scene tree)

```gdscript
@icon("res://resources/editor_icons/manager.svg")
class_name M_VFXManager
extends Node

const U_ServiceLocator := preload("res://scripts/core/u_service_locator.gd")

var _state_store: I_StateStore
var _camera_manager: M_CameraManager
var _trauma: float = 0.0
var _event_unsubscribes: Array[Callable] = []

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	add_to_group("vfx_manager")
	U_ServiceLocator.register(StringName("vfx_manager"), self)

	_state_store = U_StateUtils.get_store(self)
	_camera_manager = U_ServiceLocator.get_service(StringName("camera_manager")) as M_CameraManager

	if _state_store != null:
		_state_store.slice_updated.connect(_on_slice_updated)

	_subscribe_events()
```

**FR-007: Redux State Subscription**
The manager SHALL subscribe to `M_StateStore.slice_updated` signal and apply VFX settings changes in real-time.

```gdscript
func _on_slice_updated(slice_name: StringName, _new_slice: Variant) -> void:
	if slice_name != StringName("vfx"):
		return

	# Settings changes are applied immediately
	# Screen shake respects enabled/intensity in _apply_shake()
	# Damage flash respects enabled in trigger_damage_flash()
```

**FR-008: ECS Event Subscriptions**
The manager SHALL subscribe to the following ECS events via `U_ECSEventBus`:

| Event Name | Priority | Handler | Description |
|------------|----------|---------|-------------|
| `health_changed` | 0 | `_on_health_changed` | Add trauma + trigger flash based on damage amount |
| `entity_landed` | 0 | `_on_landed` | Add trauma if landing velocity > 15.0 |
| `entity_death` | 0 | `_on_death` | Add trauma 0.5 + trigger flash |

```gdscript
func _subscribe_events() -> void:
	_event_unsubscribes.append(
		U_ECSEventBus.subscribe(StringName("health_changed"), _on_health_changed)
	)
	_event_unsubscribes.append(
		U_ECSEventBus.subscribe(StringName("entity_landed"), _on_landed)
	)
	_event_unsubscribes.append(
		U_ECSEventBus.subscribe(StringName("entity_death"), _on_death)
	)

func _exit_tree() -> void:
	for unsubscribe in _event_unsubscribes:
		if unsubscribe != null and (unsubscribe as Callable).is_valid():
			(unsubscribe as Callable).call()
	_event_unsubscribes.clear()

func _on_health_changed(event: Dictionary) -> void:
	var payload: Dictionary = event.get("payload", {})
	var previous_health: float = payload.get("previous_health", 0.0)
	var new_health: float = payload.get("new_health", 0.0)
	var damage_amount: float = previous_health - new_health

	if damage_amount > 0.0:  # Only trigger on damage, not healing
		var trauma := remap(damage_amount, 0.0, 100.0, 0.3, 0.6)
		add_trauma(trauma)
		trigger_damage_flash(clamp(damage_amount / 50.0, 0.5, 1.0))

func _on_landed(event: Dictionary) -> void:
	var payload: Dictionary = event.get("payload", {})
	var fall_speed: float = abs(payload.get("vertical_velocity", 0.0))
	if fall_speed > 15.0:  # Heavy landing threshold
		var trauma := remap(fall_speed, 15.0, 40.0, 0.2, 0.4)
		add_trauma(trauma)

func _on_death(_event: Dictionary) -> void:
	add_trauma(0.5)
	trigger_damage_flash(1.0)
```

**FR-009: Trauma State Management**
The manager SHALL maintain trauma state with decay in `_physics_process`:
- Trauma ranges from 0.0 (no shake) to 1.0 (maximum shake)
- Trauma decays at rate of 2.0 per second
- Trauma clamps to maximum 1.0 when accumulated

```gdscript
const TRAUMA_DECAY_RATE := 2.0

func _physics_process(delta: float) -> void:
	if _trauma > 0.0:
		_trauma = max(_trauma - TRAUMA_DECAY_RATE * delta, 0.0)
		_apply_shake()
	else:
		if _camera_manager != null:
			_camera_manager.clear_shake_offset()
```

**FR-010: Public API Methods**
The manager SHALL expose a minimal public API for trauma control:

```gdscript
## Add trauma amount (accumulates up to 1.0)
func add_trauma(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)

## Get current trauma value
func get_trauma() -> float:
	return _trauma
```

Damage flash triggering remains an internal manager concern (wired from ECS events) until a concrete use-case requires a public API.

### Phase 2: Screen Shake System (FR-011 to FR-014)

**FR-011: U_ScreenShake Helper**
The system SHALL implement `U_ScreenShake` helper class for trauma-based shake calculation using `FastNoiseLite`:

```gdscript
class_name U_ScreenShake
extends RefCounted

var max_offset := Vector2(10.0, 8.0)  # Maximum pixel offset (X, Y)
var max_rotation := 0.05  # Maximum rotation in radians
var noise_speed := 5.0  # Perlin noise sample speed

var _noise: FastNoiseLite
var _time: float = 0.0

func _init() -> void:
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_noise.frequency = 1.0

func calculate_shake(trauma: float, settings_multiplier: float, delta: float) -> Dictionary:
	_time += delta * noise_speed

	# Quadratic falloff for smooth feel
	var shake_amount := trauma * trauma

	var offset := Vector2(
		max_offset.x * shake_amount * _noise.get_noise_1d(_time),
		max_offset.y * shake_amount * _noise.get_noise_1d(_time + 100.0)
	) * settings_multiplier

	var rotation := max_rotation * shake_amount * _noise.get_noise_1d(_time + 200.0) * settings_multiplier

	return {
		"offset": offset,
		"rotation": rotation
	}
```

**FR-012: Shake Parameters**
The shake system SHALL use the following default parameters:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `max_offset` | Vector2(10, 8) | Maximum camera offset in pixels (X, Y) |
| `max_rotation` | 0.05 radians | Maximum camera rotation (~2.86°) |
| `decay_rate` | 2.0 | Trauma decay per second |
| `noise_speed` | 5.0 | Perlin noise sample speed multiplier |

**FR-013: Shake Calculation**
The shake SHALL apply quadratic falloff (`trauma^2`) and settings multiplier from Redux state:

```gdscript
func _apply_shake() -> void:
	if _camera_manager == null or _screen_shake == null:
		return

	var state := _state_store.get_state() if _state_store != null else {}

	# Early return if shake disabled
	if not U_VFXSelectors.is_screen_shake_enabled(state):
		_camera_manager.clear_shake_offset()
		return

	var settings_multiplier := U_VFXSelectors.get_screen_shake_intensity(state)
	var shake_data := _screen_shake.calculate_shake(_trauma, settings_multiplier, get_physics_process_delta_time())

	_camera_manager.apply_shake_offset(shake_data["offset"], shake_data["rotation"])
```

**FR-014: Shake Toggle Behavior**
When `screen_shake_enabled` is `false`, the system SHALL:
- Early return from shake calculation (no CPU overhead)
- Clear camera shake offset immediately
- Continue trauma decay (state maintained for when re-enabled)

### Phase 3: Camera Manager Integration (FR-015 to FR-016)

**FR-015: apply_shake_offset() Method**
`M_CameraManager` SHALL expose `apply_shake_offset(offset: Vector2, rotation: float) -> void` and apply shake to a ShakeParent Node3D above the active camera:
- During camera blending, shake is applied to the TransitionCamera parent.
- Otherwise, shake is applied to the active scene camera parent (inserting a runtime ShakeParent above the active camera if needed).

Clearing shake is performed by calling `apply_shake_offset(Vector2.ZERO, 0.0)`.

**FR-016: clear_shake_offset() Method**
Optional convenience wrapper around `apply_shake_offset(Vector2.ZERO, 0.0)`.

### Phase 4: Damage Flash System (FR-017 to FR-019)

**FR-017: M_DamageFlash Helper**
The system SHALL implement `M_DamageFlash` extending `RefCounted`:

```gdscript
class_name M_DamageFlash
extends RefCounted

const U_VFX_SELECTORS := preload("res://scripts/state/selectors/u_vfx_selectors.gd")

@export var flash_color := Color(1.0, 0.0, 0.0, 0.3)  # Red, 30% alpha
@export var fade_duration := 0.4  # Seconds
@export var max_alpha := 0.4

@onready var _overlay: ColorRect = $ColorRect
var _tween: Tween
var _state_store: I_StateStore

func _ready() -> void:
	layer = 50  # Recommended: keep below `LoadingOverlay.layer = 100` in `scenes/root.tscn` (choose final layering based on whether you want UI tinted)
	_state_store = U_StateUtils.get_store(self)

	_overlay.modulate = flash_color
	_overlay.modulate.a = 0.0

func trigger(intensity: float = 1.0) -> void:
	if _state_store != null:
		var state := _state_store.get_state()
		if not U_VFX_SELECTORS.is_damage_flash_enabled(state):
			return

	if _tween != null and _tween.is_valid():
		_tween.kill()

	var target_alpha := clampf(max_alpha * intensity, 0.0, max_alpha)
	_overlay.modulate.a = target_alpha

	_tween = create_tween()
	_tween.tween_property(_overlay, "modulate:a", 0.0, fade_duration)

func is_active() -> bool:
	return _overlay.modulate.a > 0.01
```

**FR-018: Flash Parameters**
The damage flash SHALL use the following default parameters:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `flash_color` | Color(1, 0, 0, 0.3) | Red with 30% alpha |
| `fade_duration` | 0.4 seconds | Time to fade from max to zero |
| `max_alpha` | 0.4 | Maximum overlay alpha |
| `layer` | 100 | CanvasLayer order (above game, below UI) |

**FR-019: Flash Trigger Behavior**
The damage flash SHALL:
- Jump to `max_alpha * intensity` immediately when triggered
- Fade to alpha 0.0 over `fade_duration` using Tween
- Restart animation if triggered during existing fade (no stacking)
- Respect `damage_flash_enabled` toggle (early return if disabled)

### Phase 5: Settings UI Integration (FR-020)

**FR-020: VFX Settings Panel**
The settings UI SHALL integrate VFX controls with:
- Screen shake toggle (CheckBox)
- Screen shake intensity slider (HSlider, range 0.0-2.0, step 0.1)
- Damage flash toggle (CheckBox)
- Apply/Cancel/Reset pattern (dispatch on Apply)

```gdscript
# In settings overlay Apply handler

func _on_apply_pressed() -> void:
	if _store == null:
		return

	_store.dispatch(U_VFXActions.set_screen_shake_enabled(_shake_enabled_toggle.button_pressed))
	_store.dispatch(U_VFXActions.set_screen_shake_intensity(_intensity_slider.value))
	_store.dispatch(U_VFXActions.set_damage_flash_enabled(_flash_enabled_toggle.button_pressed))
```

## Key Entities

### Redux State Shape

```gdscript
# State shape for vfx slice
{
	"vfx": {
		"screen_shake_enabled": bool,      # Global shake toggle (default: true)
		"screen_shake_intensity": float,   # Multiplier 0.0-2.0 (default: 1.0)
		"damage_flash_enabled": bool       # Flash toggle (default: true)
	}
}
```

### Event Payloads

**health_changed Event** (Typed: `Evn_HealthChanged`):
```gdscript
{
	"name": StringName("health_changed"),
	"payload": {
		"entity_id": StringName,      # Entity that took damage/healed
		"previous_health": float,     # Health before change
		"new_health": float,          # Health after change
		"is_dead": bool               # Whether entity died
	},
	"timestamp": float
}
```

**entity_landed Event**:
```gdscript
{
	"name": StringName("entity_landed"),
	"payload": {
		"entity": CharacterBody3D,
		"jump_component": C_JumpComponent,
		"floating_component": C_FloatingComponent,
		"position": Vector3,
		"velocity": Vector3,          # Full velocity vector
		"vertical_velocity": float,   # Y-component for fall speed check
		"landing_time": float
	},
	"timestamp": float
}
```

**entity_death Event** (Typed: `Evn_EntityDeath`):
```gdscript
{
	"name": StringName("entity_death"),
	"payload": {
		"entity_id": StringName,
		"previous_health": float,     # Health before death
		"new_health": float,          # Always 0.0
		"is_dead": bool               # Always true
	},
	"timestamp": float
}
```

### Trauma Mapping

| Event | Damage/Velocity | Trauma Range | Formula |
|-------|-----------------|--------------|---------|
| Health Changed (damage) | 0-100 damage | 0.3-0.6 | `remap(damage_taken, 0, 100, 0.3, 0.6)` |
| Heavy Landing | 15-40 fall speed | 0.2-0.4 | `remap(abs(vertical_velocity), 15, 40, 0.2, 0.4)` |
| Death | N/A | 0.5 | Fixed trauma |

## Acceptance Scenarios

### Scenario 1: Screen Shake on Damage

**Given**: Player entity with M_VFXManager active and `screen_shake_enabled = true`
**When**: `C_HealthComponent` publishes `health_changed` event (previous=100, new=50, damage=50)
**Then**:
- Manager receives `health_changed` event via `_on_health_changed()`
- Damage calculated as `previous_health - new_health = 50`
- Trauma increases by ~0.45 (remap 50 in 0-100 to 0.3-0.6)
- Camera shake offset applied via M_CameraManager
- Shake decays over 0.225 seconds (0.45 / 2.0 decay rate)

### Scenario 2: Damage Flash Trigger

**Given**: Player with `damage_flash_enabled = true`
**When**: `C_HealthComponent` publishes `health_changed` event (damage=75)
**Then**:
- Damage flash overlay alpha jumps to 0.4 (max_alpha)
- Flash fades to 0.0 over 0.4 seconds
- Overlay becomes invisible when alpha < 0.01

### Scenario 3: Settings Disable Shake

**Given**: Active screen shake with trauma = 0.8
**When**: Dispatch `U_VFXActions.set_screen_shake_enabled(false)`
**Then**:
- `_apply_shake()` early returns
- `M_CameraManager.clear_shake_offset()` called immediately
- Camera offset resets to Vector2.ZERO
- Trauma continues decaying (state maintained)

### Scenario 4: Heavy Landing Shake

**Given**: Player falls and lands with vertical velocity = -25.0
**When**: `S_JumpSystem` publishes `entity_landed` event
**Then**:
- M_VFXManager receives event via `_on_landed()`
- Fall speed = abs(vertical_velocity) = 25.0 > threshold 15.0, triggers shake
- Trauma = remap(25, 15, 40, 0.2, 0.4) = 0.28
- Camera shakes for ~0.14 seconds

### Scenario 5: Intensity Multiplier

**Given**: Trauma = 0.5, `screen_shake_intensity = 2.0`
**When**: Shake calculation runs
**Then**:
- Base shake = trauma^2 = 0.25
- Offset = max_offset * 0.25 * noise * 2.0 (doubled)
- Rotation = max_rotation * 0.25 * noise * 2.0 (doubled)

### Scenario 6: Multiple Trauma Sources

**Given**: Trauma = 0.4
**When**: Call `add_trauma(0.5)`, then `add_trauma(0.3)`
**Then**:
- First call: trauma = min(0.4 + 0.5, 1.0) = 0.9
- Second call: trauma = min(0.9 + 0.3, 1.0) = 1.0 (clamped)

### Scenario 7: Flash Restart on Damage

**Given**: Damage flash active with alpha = 0.2 (mid-fade)
**When**: Trigger new damage flash with intensity = 1.0
**Then**:
- Existing tween killed
- Alpha resets to 0.4 (max_alpha)
- New fade tween starts (0.4 → 0.0 over 0.4s)

### Scenario 8: Settings Persistence

**Given**: User sets `screen_shake_intensity = 0.5`, `damage_flash_enabled = false`
**When**: Save game to slot, then load save
**Then**:
- VFX settings restored from save file
- Shake intensity = 0.5 (halved shake)
- Damage flash disabled (no flash on damage)

## Implementation Phases

### Phase 0: Redux Foundation (Days 1-2)

**Objective**: Implement VFX Redux layer with immutable state management

**Deliverables**:
1. `scripts/state/resources/rs_vfx_initial_state.gd` - Initial state resource
2. `scripts/state/actions/u_vfx_actions.gd` - 3 action creators
3. `scripts/state/reducers/u_vfx_reducer.gd` - Reducer with clamping
4. `scripts/state/selectors/u_vfx_selectors.gd` - 3 selector functions
5. `tests/unit/state/test_vfx_reducer.gd` - 15 unit tests

**Commit 1: VFX Initial State Resource**
- Create `RS_VFXInitialState` with 3 exported fields
- Implement `to_dictionary()` method
- Default values: shake enabled=true, intensity=1.0, flash enabled=true

**Commit 2: VFX Actions and Reducer**
- Implement `U_VFXActions` with 3 action creators
- Implement `U_VFXReducer.reduce()` with intensity clamping
- Register action types with `U_ActionRegistry`

**Commit 3: VFX Selectors and Tests**
- Implement 3 selectors in `U_VFXSelectors`
- Write 15 unit tests for reducer (clamping, immutability, unknown actions)
- All tests pass with GUT

**Dependencies**: None (pure Redux layer)

**Success Criteria**: All reducer tests pass, actions dispatch correctly, selectors return expected values

---

### Phase 1: Core Manager (Days 3-4)

**Objective**: Implement M_VFXManager with event subscriptions and trauma state

**Deliverables**:
1. `scripts/managers/m_vfx_manager.gd` - Core manager
2. Update `scenes/root.tscn` - Add M_VFXManager node (persistent root scene)
3. Update `scripts/scene_structure/main.gd` - ServiceLocator registration (Root bootstrap)
4. `tests/unit/managers/test_vfx_manager.gd` - 20 unit tests

**Commit 1: Manager Scaffolding**
- Create `M_VFXManager` extending Node
- Implement `_ready()`, group registration, ServiceLocator registration
- Add `_trauma` field with `_physics_process()` decay logic

**Commit 2: Event Subscriptions**
- Subscribe to `gameplay/take_damage`, `entity_landed`, `entity_death`
- Implement event handlers: `_on_damage()`, `_on_landed()`, `_on_death()`
- Unsubscribe on `_exit_tree()`

**Commit 3: Public API and Tests**
- Implement public API: `add_trauma()`, `set_trauma()`, `get_trauma()`
- Write 20 unit tests with `MockStateStore` + real `U_ECSEventBus` (call `U_ECSEventBus.reset()` in `before_each()` to prevent subscription leaks)
- Add M_VFXManager to `scenes/root.tscn`, register in `scripts/scene_structure/main.gd`

**Dependencies**: Phase 0, M_StateStore, U_ECSEventBus, U_ServiceLocator

**Success Criteria**: Manager subscribes to events, trauma accumulates/decays, settings changes apply

---

### Phase 2: Screen Shake System (Days 5-7)

**Objective**: Implement trauma-based shake calculation with FastNoiseLite

**Deliverables**:
1. `scripts/managers/helpers/u_screen_shake.gd` - Shake helper
2. Shake algorithm integration in M_VFXManager
3. `tests/unit/managers/helpers/test_screen_shake.gd` - 15 unit tests

**Commit 1: U_ScreenShake Helper**
- Create `U_ScreenShake` class with FastNoiseLite
- Implement `calculate_shake()` with quadratic falloff
- Parameters: max_offset, max_rotation, noise_speed

**Commit 2: Shake Integration**
- Add `_screen_shake` instance to M_VFXManager
- Implement `_apply_shake()` with settings multiplier
- Respect `screen_shake_enabled` toggle (early return)

**Commit 3: Tests and Refinement**
- Write 15 unit tests for shake calculations
- Test: zero trauma = zero offset, max trauma = max offset
- Test: disabled shake returns zero, intensity multiplier doubles shake

**Dependencies**: Phase 1

**Success Criteria**: Shake calculations produce expected offsets, settings multiplier applies, disabled toggle prevents shake

---

### Phase 3: Camera Manager Integration (Days 8-9)

**Objective**: Add shake offset methods to M_CameraManager

**Deliverables**:
1. Update `scripts/managers/m_camera_manager.gd` - Add shake methods
2. `tests/unit/managers/test_camera_manager_shake.gd` - 10 integration tests

**Commit 1: Camera Shake Methods**
- Add `_shake_offset` and `_shake_rotation` fields to M_CameraManager
- Implement `apply_shake_offset(offset, rotation)`
- Implement `clear_shake_offset()`

**Commit 2: Parent Node Approach**
- Apply shake to camera parent node (prevents gimbal lock)
- Convert 2D offset to 3D using camera basis vectors
- Handle transition camera and active camera cases

**Commit 3: Integration Tests**
- Write 10 integration tests for camera shake
- Test: offset applies to camera position/rotation
- Test: clear resets to zero, no gimbal lock at extreme angles

**Dependencies**: Phase 2, M_CameraManager

**Success Criteria**: Camera shakes during trauma, offset clears when trauma = 0, no gimbal lock

---

### Phase 4: Damage Flash System (Days 10-11)

**Objective**: Implement damage flash overlay with fade animation

**Deliverables**:
1. `scripts/managers/helpers/u_damage_flash.gd` - Flash helper
2. `scenes/ui/ui_damage_flash_overlay.tscn` - CanvasLayer scene
3. `tests/unit/managers/helpers/test_damage_flash.gd` - 10 unit tests

**Commit 1: Damage Flash Scene**
- Create `ui_damage_flash_overlay.tscn` with CanvasLayer (recommend `layer = 50` to stay below `LoadingOverlay.layer = 100` in `scenes/root.tscn`)
- Add ColorRect child covering full screen
- Set flash_color = Color(1, 0, 0, 0.3)

**Commit 2: M_DamageFlash Script**
- Implement `trigger(intensity)` with Tween fade
- Respect `damage_flash_enabled` toggle
- Multiple triggers restart animation (kill existing tween)

**Commit 3: Manager Integration and Tests**
- Add M_DamageFlash instance to M_VFXManager
- Implement `trigger_damage_flash()` and `is_damage_flash_active()`
- Write 10 unit tests for flash behavior

**Dependencies**: Phase 1

**Success Criteria**: Flash triggers on damage, fades over 0.4s, respects enabled toggle

---

### Phase 5: Settings UI Integration (Days 12-14)

**Objective**: Add VFX settings panel to game settings

**Deliverables**:
1. VFX settings tab UI controls
2. Apply/Cancel/Reset pattern implementation
3. `tests/integration/vfx/test_vfx_camera_integration.gd` - integration tests
4. `tests/integration/vfx/test_vfx_settings_ui.gd` - UI integration tests

**Commit 1: Settings UI Controls**
- Add VFX tab to settings panel (or Accessibility tab)
- Screen shake toggle (CheckBox)
- Screen shake intensity slider (HSlider, 0.0-2.0, step 0.1)
- Damage flash toggle (CheckBox)

**Commit 2: Apply/Cancel Pattern**
- Changes remain local until Apply
- Apply dispatches `U_VFXActions` updates
- Cancel closes without dispatching changes

**Commit 3: Integration Tests**
- Write 15 integration tests for full VFX system
- Test: damage action triggers shake + flash
- Test: settings disable prevents effects
- Test: persistence saves/loads correctly
- Write 10 UI integration tests for settings panel

**Dependencies**: All previous phases, existing settings panel architecture

**Success Criteria**: Settings UI updates Redux state, VFX responds in real-time, persistence works

## Success Criteria

**SC-001: Redux Immutability**
VFX reducer SHALL NOT mutate state. Verify by checking object identity: `old_state is not new_state` after action dispatch.

**SC-002: Intensity Clamping**
Intensity SHALL clamp to 0.0-2.0 range. Edge cases tested:
- Input: -0.5 → Output: 0.0
- Input: 5.0 → Output: 2.0
- Input: 1.5 → Output: 1.5 (within range)

**SC-003: Selector Correctness**
Selectors SHALL return correct values for all state combinations:
- Empty state → defaults (shake enabled=true, intensity=1.0, flash enabled=true)
- Partial state → defaults for missing fields
- Complete state → exact values from state

**SC-004: Manager Lifecycle**
M_VFXManager SHALL register with ServiceLocator and `vfx_manager` group on `_ready()`. Verify with:
- `U_ServiceLocator.get_service("vfx_manager")` returns manager instance
- Manager in `get_tree().get_nodes_in_group("vfx_manager")`

**SC-005: Event Subscription**
Manager SHALL subscribe to Redux and ECS events without memory leaks. Verify:
- Redux state changes trigger `_on_slice_updated()`
- ECS events trigger handlers (`_on_damage`, `_on_landed`, `_on_death`)
- `_exit_tree()` calls all unsubscribe callables

**SC-006: Trauma Decay**
Trauma SHALL decay from 1.0 to 0.0 in 0.5 seconds at decay rate 2.0:
- Formula: `trauma = max(trauma - 2.0 * delta, 0.0)`
- Verification: Set trauma=1.0, wait 0.5s, check trauma=0.0

**SC-007: Trauma Accumulation**
Trauma SHALL accumulate from multiple sources and clamp to 1.0:
- Start: trauma=0.6
- Add 0.3: trauma=0.9
- Add 0.4: trauma=1.0 (clamped, not 1.3)

**SC-008: Shake Settings Multiplier**
Shake offset SHALL respect intensity multiplier:
- intensity=2.0 doubles shake magnitude
- intensity=0.5 halves shake magnitude
- intensity=0.0 disables shake (zero offset)

**SC-009: Shake Disabled Toggle**
When `screen_shake_enabled=false`, shake SHALL not apply:
- Camera offset remains Vector2.ZERO
- No CPU overhead (early return in `_apply_shake()`)
- Trauma continues decaying (state preserved)

**SC-010: Heavy Landing Threshold**
Heavy landing (velocity > 15) SHALL trigger shake:
- velocity=10: No shake (below threshold)
- velocity=15: Trauma=0.2 (minimum)
- velocity=25: Trauma=0.28 (interpolated)
- velocity=40: Trauma=0.4 (maximum)

**SC-011: Flash Fade Animation**
Damage flash SHALL fade from max alpha to 0.0 over 0.4 seconds:
- t=0.0s: alpha=0.4
- t=0.2s: alpha≈0.2
- t=0.4s: alpha=0.0

**SC-012: Flash Restart**
Multiple damage events SHALL restart flash (no stacking):
- Flash at alpha=0.2 (mid-fade)
- New damage triggers
- Alpha resets to 0.4, new fade starts

**SC-013: Flash Disabled Toggle**
When `damage_flash_enabled=false`, flash SHALL not trigger:
- Overlay alpha remains 0.0
- No tween created
- `trigger()` early returns

**SC-014: Settings UI Dispatch**
Settings panel SHALL dispatch Redux actions on change:
- Toggle change → `set_screen_shake_enabled(value)`
- Slider change → `set_screen_shake_intensity(value)`
- Actions reflected in Redux state within 1 frame

**SC-015: Settings Persistence**
VFX settings SHALL persist to save files and restore on load:
- Change settings → save game → load save
- Settings restored exactly as saved
- No data loss or corruption

## Testing Strategy

### Unit Tests (60 tests)

**Redux Layer Tests** (`test_vfx_reducer.gd` - 15 tests):

```gdscript
# Test set_screen_shake_enabled(true)
func test_set_screen_shake_enabled_true():
	Given: Initial state with screen_shake_enabled = false
	When: Dispatch U_VFXActions.set_screen_shake_enabled(true)
	Then: New state has screen_shake_enabled = true, other fields unchanged

# Test intensity clamping (lower bound)
func test_set_screen_shake_intensity_clamp_lower():
	Given: Initial state
	When: Dispatch U_VFXActions.set_screen_shake_intensity(-0.5)
	Then: New state has screen_shake_intensity = 0.0 (clamped)

# Test intensity clamping (upper bound)
func test_set_screen_shake_intensity_clamp_upper():
	Given: Initial state
	When: Dispatch U_VFXActions.set_screen_shake_intensity(3.5)
	Then: New state has screen_shake_intensity = 2.0 (clamped)

# Test intensity within range
func test_set_screen_shake_intensity_valid():
	Given: Initial state
	When: Dispatch U_VFXActions.set_screen_shake_intensity(1.5)
	Then: New state has screen_shake_intensity = 1.5 (no clamping)

# Test damage flash toggle
func test_set_damage_flash_enabled_false():
	Given: Initial state with damage_flash_enabled = true
	When: Dispatch U_VFXActions.set_damage_flash_enabled(false)
	Then: New state has damage_flash_enabled = false

# Test immutability
func test_reducer_immutability():
	Given: Initial state
	When: Dispatch any action
	Then: old_state is not new_state (different object references)

# Test unknown action
func test_reducer_unknown_action():
	Given: Initial state
	When: Dispatch action with unknown type
	Then: State reference unchanged (returns same object)

# ... (8 more tests for selectors, edge cases)
```

**Manager Core Tests** (`test_vfx_manager.gd` - 20 tests):

```gdscript
# Test manager adds to group
func test_manager_adds_to_group_on_ready():
	Given: M_VFXManager instance
	When: Added to tree and _ready() called
	Then: Manager in "vfx_manager" group

# Test trauma accumulation
func test_add_trauma_accumulates():
	Given: Manager with trauma = 0.3
	When: Call add_trauma(0.4)
	Then: get_trauma() returns 0.7

# Test trauma clamping
func test_add_trauma_clamps_to_max():
	Given: Manager with trauma = 0.8
	When: Call add_trauma(0.5)
	Then: get_trauma() returns 1.0 (clamped)

# Test trauma decay
func test_trauma_decays_over_time():
	Given: Manager with trauma = 1.0
	When: Simulate _physics_process(0.5) at decay_rate 2.0
	Then: get_trauma() returns 0.0 (1.0 - 2.0 * 0.5 = 0.0)

# Test damage event triggers trauma
func test_health_changed_event_triggers_trauma():
	Given: Manager subscribed to health_changed
	When: Publish health_changed with previous=100, new=50
	Then: get_trauma() > 0.0 (trauma added from damage)

# Test heavy landing triggers trauma
func test_heavy_landing_triggers_trauma():
	Given: Manager subscribed to entity_landed
	When: Publish entity_landed with velocity = 20.0
	Then: get_trauma() in range 0.2-0.4

# Test death event
func test_death_event_triggers_trauma_and_flash():
	Given: Manager with damage flash helper
	When: Publish entity_death event
	Then: get_trauma() = 0.5 AND is_damage_flash_active() = true

# ... (13 more tests for settings, API methods)
```

**Screen Shake Tests** (`test_screen_shake.gd` - 15 tests):

```gdscript
# Test zero trauma
func test_shake_offset_zero_trauma():
	Given: U_ScreenShake with trauma = 0.0
	When: calculate_shake(0.0, 1.0, 0.016)
	Then: offset = Vector2.ZERO, rotation = 0.0

# Test max trauma
func test_shake_offset_max_trauma():
	Given: U_ScreenShake with trauma = 1.0
	When: calculate_shake(1.0, 1.0, 0.016)
	Then: offset magnitude <= Vector2(10, 8), rotation <= 0.05

# Test intensity multiplier
func test_shake_respects_intensity_multiplier():
	Given: U_ScreenShake
	When: calculate_shake(0.5, 2.0, 0.016)
	Then: offset magnitude ~2x baseline

# Test quadratic falloff
func test_shake_quadratic_falloff():
	Given: U_ScreenShake
	When: calculate_shake(0.5, 1.0, 0.016)
	Then: shake_amount = 0.5 * 0.5 = 0.25 (verify in offset calculation)

# Test noise variation
func test_noise_generates_organic_movement():
	Given: U_ScreenShake
	When: calculate_shake at t=0.0, t=0.1, t=0.2
	Then: offset values differ (noise varies over time)

# ... (10 more tests for noise, parameters, edge cases)
```

**Damage Flash Tests** (`test_damage_flash.gd` - 10 tests):

```gdscript
# Test flash trigger
func test_flash_trigger_sets_alpha():
	Given: M_DamageFlash with alpha = 0.0
	When: Call trigger(1.0)
	Then: overlay.modulate.a = 0.4 (max_alpha)

# Test flash fade
func test_flash_fades_to_zero():
	Given: M_DamageFlash with triggered flash
	When: Wait fade_duration (0.4s)
	Then: overlay.modulate.a = 0.0

# Test multiple triggers
func test_flash_multiple_triggers_restart():
	Given: M_DamageFlash at alpha = 0.2 (mid-fade)
	When: Call trigger(1.0)
	Then: alpha resets to 0.4, new tween starts

# Test disabled toggle
func test_flash_disabled_prevents_trigger():
	Given: M_DamageFlash with damage_flash_enabled = false
	When: Call trigger(1.0)
	Then: overlay.modulate.a remains 0.0

# Test intensity scaling
func test_flash_intensity_scales_alpha():
	Given: M_DamageFlash
	When: Call trigger(0.5)
	Then: overlay.modulate.a = 0.2 (max_alpha * 0.5)

# ... (5 more tests for tween, layer order, is_active)
```

### Integration Tests (35 tests)

**Full VFX System Tests** (`test_vfx_integration.gd` - 15 tests):

```gdscript
# Test damage triggers shake + flash
func test_health_changed_triggers_vfx():
	Given: Full scene with M_VFXManager, M_StateStore, player with C_HealthComponent
	When: C_HealthComponent.apply_damage(50.0) publishes health_changed event
	Then: manager.get_trauma() > 0.0 AND is_damage_flash_active() = true

# Test settings disable shake
func test_settings_disable_shake_prevents_camera_movement():
	Given: VFX manager with trauma = 1.0
	When: Dispatch U_VFXActions.set_screen_shake_enabled(false)
	Then: camera offset remains Vector2.ZERO

# Test intensity slider
func test_intensity_slider_affects_shake():
	Given: VFX manager with trauma = 0.5, intensity = 1.0
	When: Dispatch U_VFXActions.set_screen_shake_intensity(2.0)
	Then: camera shake magnitude doubles

# Test persistence
func test_vfx_settings_persist():
	Given: VFX settings changed to non-default
	When: Save game → load save
	Then: VFX settings restored correctly

# ... (11 more integration tests)
```

**Settings UI Tests** (`test_vfx_settings_ui.gd` - 10 tests):

```gdscript
# Test toggle dispatches action
func test_shake_toggle_dispatches_action():
	Given: Settings panel with VFX tab
	When: Toggle screen shake checkbox
	Then: U_VFXActions.set_screen_shake_enabled dispatched

# Test slider dispatches action
func test_intensity_slider_dispatches_action():
	Given: Settings panel
	When: Move intensity slider to 1.5
	Then: U_VFXActions.set_screen_shake_intensity(1.5) dispatched

# Test initial state reflects Redux
func test_ui_reflects_redux_state():
	Given: Redux state with shake_enabled=false, intensity=0.5
	When: Open settings panel
	Then: toggle unchecked, slider at 0.5

# ... (7 more UI tests)
```

### TDD Workflow

**Phase 0-1** (Redux + Manager):
1. Write test file with 15 test cases for reducer
2. Run tests → All fail (red)
3. Implement reducer with clamping
4. Run tests → All pass (green)
5. Repeat for manager core (20 tests)

**Phase 2-5** (Features):
1. Write integration test for feature (e.g., shake triggers on damage)
2. Write unit tests for components (e.g., U_ScreenShake calculations)
3. Run tests → Fail (red)
4. Implement feature
5. Run tests → Pass (green)
6. Verify no regressions in existing tests

**Total Test Coverage**: ~95 tests (60 unit + 35 integration)

## File Structure

```
scripts/managers/
  m_vfx_manager.gd                     # Core VFX orchestration manager

scripts/managers/helpers/
  u_screen_shake.gd                    # Trauma-based shake calculation
  u_damage_flash.gd                    # Flash overlay helper

scripts/state/resources/
  rs_vfx_initial_state.gd              # Initial Redux state resource

scripts/state/actions/
  u_vfx_actions.gd                     # VFX action creators (3 actions)

scripts/state/reducers/
  u_vfx_reducer.gd                     # VFX state reducer with clamping

scripts/state/selectors/
  u_vfx_selectors.gd                   # VFX state selectors (3 selectors)

scenes/ui/
  ui_damage_flash_overlay.tscn         # CanvasLayer with ColorRect

tests/unit/state/
  test_vfx_reducer.gd                  # Redux reducer tests (15 tests)

tests/unit/managers/
  test_vfx_manager.gd                  # Manager core tests (20 tests)

tests/unit/managers/helpers/
  test_screen_shake.gd                 # Shake calculation tests (15 tests)
  test_damage_flash.gd                 # Flash overlay tests (10 tests)

tests/integration/vfx/
  test_vfx_integration.gd              # Full system integration (15 tests)
  test_vfx_settings_ui.gd              # Settings UI integration (10 tests)
```

## Dependencies & Integration Points

### Existing Code Modifications

**1. M_CameraManager** (`scripts/managers/m_camera_manager.gd`):
- **Add Fields**:
  - `var _shake_offset: Vector2 = Vector2.ZERO`
  - `var _shake_rotation: float = 0.0`
  - `var _shake_parent: Node3D = null`
- **Add Methods**:
  - `func _create_shake_parent() -> void` (call in `_ready()` after `_create_transition_camera()`)
  - `func apply_shake_offset(offset: Vector2, rotation: float) -> void`
  - `func clear_shake_offset() -> void`
- **Modify `_create_transition_camera()`**: After creating transition camera, call `_create_shake_parent()` to reparent camera
- **Note**: Parent node approach isolates shake from camera rotation, future-proofing for camera rotation features

**2. scenes/root.tscn**:
- Add `M_VFXManager` node under `Managers` group
- Position after M_StateStore, M_CameraManager in tree

**3. scripts/scene_structure/main.gd**:
- Add ServiceLocator registration:
  ```gdscript
  var vfx_manager := get_node("Managers/M_VFXManager") as M_VFXManager
  U_ServiceLocator.register(StringName("vfx_manager"), vfx_manager)
  ```

**4. M_StateStore** (`scripts/state/m_state_store.gd`):
- **Add Reducer Preload** (after line 27):
  ```gdscript
  const U_VFX_REDUCER := preload("res://scripts/state/reducers/u_vfx_reducer.gd")
  ```
- **Add Export Variable** (after line 56):
  ```gdscript
  @export var vfx_initial_state: RS_VFXInitialState
  ```
- **Update `_initialize_slices()` call** (line 164):
  ```gdscript
  U_STATE_SLICE_MANAGER.initialize_slices(
      _slice_configs,
      _state,
      boot_initial_state,
      menu_initial_state,
      navigation_initial_state,
      settings_initial_state,
      gameplay_initial_state,
      scene_initial_state,
      debug_initial_state,
      vfx_initial_state  # ADD THIS
  )
  ```

**5. Settings Panel UI** (existing architecture):
- Add VFX settings overlay to settings menu
- Follow Apply/Cancel/Reset pattern (dispatch on Apply)
- Use `U_FocusConfigurator` for gamepad focus navigation

### Integration Order

1. **Phase 0** (Redux): Independent, no dependencies
2. **Phase 1** (Manager Core): Depends on M_StateStore, U_ECSEventBus, U_ServiceLocator
3. **Phase 2** (Screen Shake): Depends on Phase 1
4. **Phase 3** (Camera Integration): Depends on Phase 2, M_CameraManager
5. **Phase 4** (Damage Flash): Depends on Phase 1 (parallel to Phase 2-3)
6. **Phase 5** (Settings UI): Depends on all previous phases, settings panel architecture

### External Dependencies

- **M_StateStore**: Redux store for VFX slice
- **U_ECSEventBus**: Event subscription for gameplay events
- **M_CameraManager**: Camera shake offset application
- **U_ServiceLocator**: Manager discovery
- **U_StateUtils**: Store lookup utility

## Deployment Strategy

### Feature Flags

**VFX Feature Flag** (`is_vfx_enabled`):
- Default: `true` (VFX enabled by default)
- Environment variable: `VFX_ENABLED=false` to disable
- Debug toggle: F4 menu option "Disable VFX"

```gdscript
# In M_VFXManager

var _feature_enabled := true

func _ready() -> void:
	# Check environment variable
	if OS.has_environment("VFX_ENABLED"):
		_feature_enabled = OS.get_environment("VFX_ENABLED") == "true"

	# Check debug flag
	if OS.is_debug_build():
		var debug_state := _state_store.get_state().get("debug", {})
		if debug_state.get("vfx_disabled", false):
			_feature_enabled = false

	if not _feature_enabled:
		set_physics_process(false)
		return

	# Normal initialization...
```

### Gradual Rollout

**Phase 1** (Week 1):
- Deploy Redux layer and manager core
- VFX disabled by default (`_feature_enabled = false`)
- Internal testing only

**Phase 2** (Week 2):
- Enable screen shake only (damage flash disabled)
- Enable for 10% of players via feature flag
- Monitor performance and feedback

**Phase 3** (Week 3):
- Enable both shake and flash for 50% of players
- Monitor for motion sickness reports
- Ensure settings toggles work correctly

**Phase 4** (Week 4):
- Full rollout (100% of players)
- VFX enabled by default
- Settings panel provides opt-out

### Rollback Steps

**If critical issues occur**:

1. **Immediate Rollback** (< 5 minutes):
   - Set environment variable: `VFX_ENABLED=false`
   - Push config update via game launcher
   - All VFX disabled, no gameplay impact

2. **Partial Rollback** (shake only):
   - Disable damage flash via Redux default state
   - Set `damage_flash_enabled = false` in `RS_VFXInitialState`
   - Keep screen shake active

3. **Full Rollback** (remove feature):
   - Revert commits from Phase 5 → Phase 0
   - Restore previous version of M_CameraManager
   - Remove M_VFXManager from `scenes/root.tscn`

### Backward Compatibility

**Save File Compatibility**:
- **Pre-VFX saves**: Load with default VFX settings (shake enabled, intensity 1.0)
- **Post-VFX saves**: VFX settings persist in save file
- **Migration**: No migration needed (VFX slice defaults handle missing data)

**Redux State Migration**:
```gdscript
# If save file missing VFX slice, use defaults
if not loaded_state.has("vfx"):
	loaded_state["vfx"] = RS_VFXInitialState.new().to_dictionary()
```

### Performance Considerations

**CPU Overhead**:
- Screen shake: ~0.05ms per frame (FastNoiseLite + calculation)
- Damage flash: ~0.01ms per frame (Tween animation)
- Event subscriptions: Negligible (only fires on events)

**Memory Footprint**:
- M_VFXManager: ~2KB
- U_ScreenShake: ~1KB (noise instance)
- Damage flash scene: ~5KB (CanvasLayer + ColorRect)
- **Total**: ~8KB memory overhead

**Optimization**:
- Shake only processes when `_trauma > 0.0` (no overhead when idle)
- Flash only allocates Tween when triggered (not persistent)
- Disabled toggles early return (zero CPU cost when disabled)

## Edge Cases

### Q1: What happens if user sets intensity to 0.0?
**Resolution**: Intensity 0.0 is valid and results in zero shake (offset = Vector2.ZERO). This is functionally equivalent to disabling shake but maintains the distinction between "disabled" (toggle off) and "reduced to zero" (slider at minimum).

### Q2: Can trauma exceed 1.0 due to rapid event spam?
**Resolution**: No. `add_trauma()` uses `minf(_trauma + amount, 1.0)` to clamp. Multiple rapid events will max out at trauma = 1.0.

### Q3: What if M_CameraManager is not in scene?
**Resolution**: M_VFXManager checks `if _camera_manager == null` before calling shake methods. Shake is skipped silently (no errors). Trauma still decays normally.

### Q4: Does damage flash stack if multiple damage events occur rapidly?
**Resolution**: No. Each trigger kills the existing tween and restarts the fade. This prevents additive stacking (which would exceed max_alpha).

### Q5: What if settings change during active shake?
**Resolution**: Settings apply immediately on next frame. If shake is disabled mid-shake, camera offset clears instantly via `clear_shake_offset()`. If intensity changes, next `_apply_shake()` uses new multiplier.

### Q6: How does trauma behave during pause?
**Resolution**: M_VFXManager has `process_mode = PROCESS_MODE_ALWAYS`, so trauma continues decaying during pause. This is intentional (shake doesn't freeze when paused). Damage flash also continues fading during pause.

### Q7: What if damage flash overlay blocks critical UI?
**Resolution**: Flash layer is 100 (below UI at 128+). UI remains visible and clickable. Flash is semi-transparent (max alpha 0.4), so UI is readable through overlay.

### Q8: Can players disable shake but keep flash?
**Resolution**: Yes. `screen_shake_enabled` and `damage_flash_enabled` are independent toggles. Any combination is valid (both on, both off, shake only, flash only).

## Open Questions

**Q1: Should heavy landing shake scale with fall height, or have a fixed threshold?**
**Status**: Resolved - Use velocity-based scaling (remap 15-40 to trauma 0.2-0.4). Falls below 15 trigger no shake.

**Q2: Should death shake trigger even if damage flash is disabled?**
**Status**: Resolved - Yes. Shake and flash are independent. Death always triggers both if their respective toggles are enabled.

**Q3: Should shake intensity affect decay rate?**
**Status**: Resolved - No. Decay rate is fixed at 2.0/second. Intensity only affects magnitude, not duration.

**Q4: Should VFX settings have separate "Graphics" tab or live in "Accessibility"?**
**Status**: Pending - Implementation can place VFX controls in either location based on UI architecture.

**Q5: Should there be a "screen shake test" button in settings to preview intensity?**
**Status**: Future enhancement - Not in initial implementation. Add in future iteration if user feedback requests it.

---

**End of VFX Manager PRD**
**Total Lines**: ~890
**Review Status**: Ready for Implementation
**Next Steps**: Create Audio Manager PRD, then begin Phase 0 implementation
