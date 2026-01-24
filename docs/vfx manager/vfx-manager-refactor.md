# VFX Manager Refactoring Plan

## Overview

**Status (2026-01-16)**: Phase 8 complete (UI Settings Preview). Next up: Phase 9 (Documentation Updates).

This plan addresses issues identified in the VFX Manager system, organized into 10 incremental phases. The refactoring improves architecture, correctness, scalability, code health, and testing while maintaining backward compatibility.

## Current State Analysis

### Verified Issues
1. **Alpha bug** - Resolved in Phase 5 (damage flash alpha corrected).
2. **No gating** - Resolved in Phase 3 (player-only + transition blocking).
3. **Magic numbers** - Resolved in Phase 4 (tuning resources).
4. **Missing preview** - Resolved in Phase 8 (settings preview + test shake).
5. **Tight coupling** - Resolved in Phase 1 (publisher systems + request events).
6. **Runtime load** - Resolved in Phase 6 (preload damage flash scene).
7. **Individual unsubscribes** - Resolved in Phase 6 (unsubscribe array cleanup).

### Key Files
- `scripts/managers/m_vfx_manager.gd` (201 lines)
- `scripts/managers/helpers/u_screen_shake.gd` (52 lines)
- `scripts/managers/helpers/u_damage_flash.gd` (31 lines)
- `scenes/ui/ui_damage_flash_overlay.tscn`
- `scripts/ui/settings/ui_vfx_settings_overlay.gd` (231 lines)

---

## Phase 1: Event Architecture Refactor

**Goal**: Decouple VFX Manager from raw gameplay events by introducing VFX request events.

### New Event Classes

**File**: `scripts/ecs/events/evn_screen_shake_request.gd`
```gdscript
extends BaseECSEvent
class_name Evn_ScreenShakeRequest

## Event published when a system requests screen shake.
##
## Published by: S_ScreenShakePublisherSystem
## Subscribers: M_VFXManager

var entity_id: StringName
var trauma_amount: float
var source: StringName

func _init(p_entity_id: StringName, p_trauma_amount: float, p_source: StringName) -> void:
	entity_id = p_entity_id
	trauma_amount = p_trauma_amount
	source = p_source

	const U_ECS_UTILS := preload("res://scripts/utils/u_ecs_utils.gd")
	timestamp = U_ECS_UTILS.get_current_time()

	_payload = {
		"entity_id": entity_id,
		"trauma_amount": trauma_amount,
		"source": source
	}
```

**File**: `scripts/ecs/events/evn_damage_flash_request.gd`
```gdscript
extends BaseECSEvent
class_name Evn_DamageFlashRequest

## Event published when a system requests damage flash.
##
## Published by: S_DamageFlashPublisherSystem
## Subscribers: M_VFXManager

var entity_id: StringName
var intensity: float
var source: StringName

func _init(p_entity_id: StringName, p_intensity: float, p_source: StringName) -> void:
	entity_id = p_entity_id
	intensity = p_intensity
	source = p_source

	const U_ECS_UTILS := preload("res://scripts/utils/u_ecs_utils.gd")
	timestamp = U_ECS_UTILS.get_current_time()

	_payload = {
		"entity_id": entity_id,
		"intensity": intensity,
		"source": source
	}
```

### Publisher Systems

**File**: `scripts/ecs/systems/s_screen_shake_publisher_system.gd`
```gdscript
@icon("res://resources/editor_icons/system.svg")
extends BaseECSSystem
class_name S_ScreenShakePublisherSystem

## Translates gameplay events into screen shake requests.
##
## Subscribes to: health_changed, entity_landed, entity_death
## Publishes: screen_shake_request

const U_ECS_EVENT_BUS := preload("res://scripts/ecs/u_ecs_event_bus.gd")
const Evn_ScreenShakeRequest := preload("res://scripts/ecs/events/evn_screen_shake_request.gd")

## Magic numbers (Phase 4 will move to RS_ScreenShakeTuning)
const DAMAGE_MIN_TRAUMA := 0.3
const DAMAGE_MAX_TRAUMA := 0.6
const DAMAGE_MAX_VALUE := 100.0
const LANDING_THRESHOLD := 15.0
const LANDING_MAX_SPEED := 30.0
const LANDING_MIN_TRAUMA := 0.2
const LANDING_MAX_TRAUMA := 0.4
const DEATH_TRAUMA := 0.5

var _unsubscribe_health: Callable
var _unsubscribe_landed: Callable
var _unsubscribe_death: Callable

func on_configured() -> void:
	_unsubscribe_health = U_ECS_EVENT_BUS.subscribe(StringName("health_changed"), _on_health_changed)
	_unsubscribe_landed = U_ECS_EVENT_BUS.subscribe(StringName("entity_landed"), _on_landed)
	_unsubscribe_death = U_ECS_EVENT_BUS.subscribe(StringName("entity_death"), _on_death)

func _exit_tree() -> void:
	if _unsubscribe_health.is_valid():
		_unsubscribe_health.call()
	if _unsubscribe_landed.is_valid():
		_unsubscribe_landed.call()
	if _unsubscribe_death.is_valid():
		_unsubscribe_death.call()

func _on_health_changed(event_data: Dictionary) -> void:
	var payload: Dictionary = event_data.get("payload", {})
	var entity_id: StringName = StringName(str(payload.get("entity_id", "")))
	var is_dead: bool = bool(payload.get("is_dead", false))
	if is_dead:
		return

	var damage_amount: float = 0.0
	if payload.has("damage"):
		damage_amount = float(payload.get("damage", 0.0))
	else:
		var previous_health: float = float(payload.get("previous_health", 0.0))
		var new_health: float = float(payload.get("new_health", previous_health))
		damage_amount = maxf(previous_health - new_health, 0.0)

	if damage_amount <= 0.0:
		return

	var damage_ratio: float = clampf(damage_amount / DAMAGE_MAX_VALUE, 0.0, 1.0)
	var trauma_amount: float = lerpf(DAMAGE_MIN_TRAUMA, DAMAGE_MAX_TRAUMA, damage_ratio)

	var event := Evn_ScreenShakeRequest.new(entity_id, trauma_amount, StringName("damage"))
	U_ECS_EVENT_BUS.publish_typed(event)

func _on_landed(event_data: Dictionary) -> void:
	var payload: Dictionary = event_data.get("payload", {})
	var entity_id: StringName = StringName(str(payload.get("entity_id", "")))

	var fall_speed: float = 0.0
	if payload.has("fall_speed"):
		fall_speed = float(payload.get("fall_speed", 0.0))
	else:
		fall_speed = absf(float(payload.get("vertical_velocity", 0.0)))

	if fall_speed <= LANDING_THRESHOLD:
		return

	var speed_ratio: float = clampf((fall_speed - LANDING_THRESHOLD) / (LANDING_MAX_SPEED - LANDING_THRESHOLD), 0.0, 1.0)
	var trauma_amount: float = lerpf(LANDING_MIN_TRAUMA, LANDING_MAX_TRAUMA, speed_ratio)

	var event := Evn_ScreenShakeRequest.new(entity_id, trauma_amount, StringName("landing"))
	U_ECS_EVENT_BUS.publish_typed(event)

func _on_death(event_data: Dictionary) -> void:
	var payload: Dictionary = event_data.get("payload", {})
	var entity_id: StringName = StringName(str(payload.get("entity_id", "")))

	var event := Evn_ScreenShakeRequest.new(entity_id, DEATH_TRAUMA, StringName("death"))
	U_ECS_EVENT_BUS.publish_typed(event)
```

**File**: `scripts/ecs/systems/s_damage_flash_publisher_system.gd`
```gdscript
@icon("res://resources/editor_icons/system.svg")
extends BaseECSSystem
class_name S_DamageFlashPublisherSystem

## Translates gameplay events into damage flash requests.
##
## Subscribes to: health_changed, entity_death
## Publishes: damage_flash_request

const U_ECS_EVENT_BUS := preload("res://scripts/ecs/u_ecs_event_bus.gd")
const Evn_DamageFlashRequest := preload("res://scripts/ecs/events/evn_damage_flash_request.gd")

var _unsubscribe_health: Callable
var _unsubscribe_death: Callable

func on_configured() -> void:
	_unsubscribe_health = U_ECS_EVENT_BUS.subscribe(StringName("health_changed"), _on_health_changed)
	_unsubscribe_death = U_ECS_EVENT_BUS.subscribe(StringName("entity_death"), _on_death)

func _exit_tree() -> void:
	if _unsubscribe_health.is_valid():
		_unsubscribe_health.call()
	if _unsubscribe_death.is_valid():
		_unsubscribe_death.call()

func _on_health_changed(event_data: Dictionary) -> void:
	var payload: Dictionary = event_data.get("payload", {})
	var entity_id: StringName = StringName(str(payload.get("entity_id", "")))
	var is_dead: bool = bool(payload.get("is_dead", false))
	if is_dead:
		return

	var damage_amount: float = 0.0
	if payload.has("damage"):
		damage_amount = float(payload.get("damage", 0.0))
	else:
		var previous_health: float = float(payload.get("previous_health", 0.0))
		var new_health: float = float(payload.get("new_health", previous_health))
		damage_amount = maxf(previous_health - new_health, 0.0)

	if damage_amount <= 0.0:
		return

	# Intensity 1.0 for all damage (Phase 5 will scale with damage amount)
	var event := Evn_DamageFlashRequest.new(entity_id, 1.0, StringName("damage"))
	U_ECS_EVENT_BUS.publish_typed(event)

func _on_death(event_data: Dictionary) -> void:
	var payload: Dictionary = event_data.get("payload", {})
	var entity_id: StringName = StringName(str(payload.get("entity_id", "")))

	var event := Evn_DamageFlashRequest.new(entity_id, 1.0, StringName("death"))
	U_ECS_EVENT_BUS.publish_typed(event)
```

### M_VFXManager Updates

**Changes to** `scripts/managers/m_vfx_manager.gd`:

1. Remove gameplay event subscriptions (lines 89-92)
2. Add VFX request event subscriptions
3. Remove trauma calculation logic from handlers (moved to publishers)

```gdscript
# Replace lines 89-92 with:
_unsubscribe_shake = U_ECS_EVENT_BUS.subscribe(StringName("screen_shake_request"), _on_screen_shake_request)
_unsubscribe_flash = U_ECS_EVENT_BUS.subscribe(StringName("damage_flash_request"), _on_damage_flash_request)

# Replace _on_health_changed, _on_landed, _on_death with:
func _on_screen_shake_request(event_data: Dictionary) -> void:
	var payload: Dictionary = event_data.get("payload", {})
	var trauma_amount: float = float(payload.get("trauma_amount", 0.0))
	add_trauma(trauma_amount)

func _on_damage_flash_request(event_data: Dictionary) -> void:
	if _state_store == null or _damage_flash == null:
		return
	var state: Dictionary = _state_store.get_state()
	if not U_VFX_SELECTORS.is_damage_flash_enabled(state):
		return
	var payload: Dictionary = event_data.get("payload", {})
	var intensity: float = float(payload.get("intensity", 1.0))
	_damage_flash.trigger_flash(intensity)
```

### Scene Integration

Add publisher systems to `scenes/gameplay/gameplay_base.tscn` under Systems node:
- `S_ScreenShakePublisherSystem`
- `S_DamageFlashPublisherSystem`

---

## Phase 2: Service Locator & Dependency Injection

**Goal**: Centralize registration and add explicit dependency declarations.

### Changes to `scripts/scene_structure/main.gd`

Add VFX manager to service registration (after camera_manager):
```gdscript
# In _register_services() or equivalent:
var vfx_manager := get_node_or_null("M_VFXManager")
if vfx_manager != null:
	U_SERVICE_LOCATOR.register(StringName("vfx_manager"), vfx_manager)
```

### Changes to `scripts/managers/m_vfx_manager.gd`

Add dependency injection exports (after line 27):
```gdscript
## Injected dependencies (for testing)
@export var state_store: I_StateStore = null
@export var camera_manager: M_CameraManager = null
```

Update `_ready()` to use injected dependencies first:
```gdscript
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("vfx_manager")

	# Use injected or discover
	if state_store != null:
		_state_store = state_store
	else:
		_state_store = U_STATE_UTILS.try_get_store(self)

	if camera_manager != null:
		_camera_manager = camera_manager
	else:
		_camera_manager = U_SERVICE_LOCATOR.try_get_service(StringName("camera_manager"))

	# ... rest of _ready()
```

Remove self-registration from M_VFXManager (line 61) since main.gd handles it.

---

## Phase 3: Player-Only & Transition Gating

**Goal**: Prevent non-player entities and inappropriate states from triggering VFX.

### Add Helper Methods to M_VFXManager

```gdscript
const U_GAMEPLAY_SELECTORS := preload("res://scripts/state/selectors/u_gameplay_selectors.gd")
const U_SCENE_SELECTORS := preload("res://scripts/state/selectors/u_scene_selectors.gd")
const U_NAVIGATION_SELECTORS := preload("res://scripts/state/selectors/u_navigation_selectors.gd")

## Check if entity_id matches the player entity
func _is_player_entity(entity_id: StringName) -> bool:
	if _state_store == null:
		return true  # Fallback: allow if no store
	var state: Dictionary = _state_store.get_state()
	var gameplay: Dictionary = state.get("gameplay", {})
	var player_entity_id: StringName = StringName(str(gameplay.get("player_entity_id", "")))
	if player_entity_id.is_empty():
		return true  # Fallback: allow if no player registered
	return entity_id == player_entity_id

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

### Update Event Handlers

```gdscript
func _on_screen_shake_request(event_data: Dictionary) -> void:
	var payload: Dictionary = event_data.get("payload", {})
	var entity_id: StringName = StringName(str(payload.get("entity_id", "")))

	# Gating: player-only and transition check
	if not _is_player_entity(entity_id):
		return
	if _is_transition_blocked():
		return

	var trauma_amount: float = float(payload.get("trauma_amount", 0.0))
	add_trauma(trauma_amount)

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

	var state: Dictionary = _state_store.get_state()
	if not U_VFX_SELECTORS.is_damage_flash_enabled(state):
		return

	var intensity: float = float(payload.get("intensity", 1.0))
	_damage_flash.trigger_flash(intensity)
```

---

## Phase 4: Resource-Driven Configuration

**Goal**: Move magic numbers to resources for easy tuning.

### New Resource: `scripts/ecs/resources/rs_screen_shake_tuning.gd`

```gdscript
extends Resource
class_name RS_ScreenShakeTuning

## Tuning parameters for screen shake trauma calculations.

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

func calculate_damage_trauma(damage_amount: float) -> float:
	if damage_amount <= 0.0:
		return 0.0
	var damage_ratio: float = clampf(damage_amount / damage_max_value, 0.0, 1.0)
	return lerpf(damage_min_trauma, damage_max_trauma, damage_ratio)

func calculate_landing_trauma(fall_speed: float) -> float:
	if fall_speed <= landing_threshold:
		return 0.0
	var speed_ratio: float = clampf((fall_speed - landing_threshold) / (landing_max_speed - landing_threshold), 0.0, 1.0)
	return lerpf(landing_min_trauma, landing_max_trauma, speed_ratio)
```

### New Resource: `scripts/ecs/resources/rs_screen_shake_config.gd`

```gdscript
extends Resource
class_name RS_ScreenShakeConfig

## Configuration for screen shake visual parameters.

@export var max_offset: Vector2 = Vector2(10.0, 8.0)
@export var max_rotation: float = 0.05
@export var noise_speed: float = 50.0
```

### Default Resource File: `resources/vfx/rs_screen_shake_tuning.tres`

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

### Update Publisher Systems

Replace constants with tuning resource in `S_ScreenShakePublisherSystem`:
```gdscript
const RS_ScreenShakeTuning := preload("res://scripts/ecs/resources/rs_screen_shake_tuning.gd")

@export var tuning: RS_ScreenShakeTuning = null

func _on_health_changed(event_data: Dictionary) -> void:
	# ... payload extraction ...
	var trauma_amount := _get_tuning().calculate_damage_trauma(damage_amount)
	if trauma_amount <= 0.0:
		return
	# ... publish event ...

func _get_tuning() -> RS_ScreenShakeTuning:
	if tuning != null:
		return tuning
	# Fallback to default
	return preload("res://resources/vfx/rs_screen_shake_tuning.tres")
```

---

## Phase 5: Typed Results & Helper Fixes

**Goal**: Fix alpha bug, improve helper APIs, add testing hooks.

### Fix Alpha Bug in Scene

**File**: `scenes/ui/ui_damage_flash_overlay.tscn`

Change line 14 from:
```
color = Color(1, 0, 0, 0.3)
```
To:
```
color = Color(1, 0, 0, 1.0)
```

### Add Tween Pause Mode in U_DamageFlash

**File**: `scripts/managers/helpers/u_damage_flash.gd`

Add pause mode after creating tween (line 29):
```gdscript
_tween = _scene_tree.create_tween()
_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)  # Add this line
_tween.tween_property(_flash_rect, "modulate:a", 0.0, FADE_DURATION)
```

### New Typed Result Class

**File**: `scripts/managers/helpers/u_shake_result.gd`

```gdscript
class_name U_ShakeResult
extends RefCounted

## Typed result from screen shake calculation.

var offset: Vector2
var rotation: float

func _init(p_offset: Vector2 = Vector2.ZERO, p_rotation: float = 0.0) -> void:
	offset = p_offset
	rotation = p_rotation
```

### Update U_ScreenShake

**File**: `scripts/managers/helpers/u_screen_shake.gd`

Add testing hooks and typed return:
```gdscript
const U_ShakeResult := preload("res://scripts/managers/helpers/u_shake_result.gd")

var _test_seed: int = -1
var _test_time: float = -1.0

func set_noise_seed_for_testing(seed: int) -> void:
	_test_seed = seed
	if seed >= 0:
		_noise.seed = seed

func set_sample_time_for_testing(time: float) -> void:
	_test_time = time

func get_sample_time() -> float:
	return _time

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

### Update M_VFXManager to Use U_ShakeResult

```gdscript
var shake_result = _screen_shake.calculate_shake(_trauma, intensity, delta)
_camera_manager.apply_shake_offset(shake_result.offset, shake_result.rotation)
```

---

## Phase 6: Request Queue Pattern & Event Constants

**Goal**: Deterministic ordering and eliminate string literals.

### New Constants File

**File**: `scripts/ecs/u_ecs_event_names.gd`

```gdscript
class_name U_ECSEventNames
extends RefCounted

## Centralized event name constants.

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

### Add Request Queues to M_VFXManager

```gdscript
var _shake_requests: Array = []
var _flash_requests: Array = []

func _on_screen_shake_request(event_data: Dictionary) -> void:
	_shake_requests.append(event_data)

func _on_damage_flash_request(event_data: Dictionary) -> void:
	_flash_requests.append(event_data)

func _physics_process(delta: float) -> void:
	# Process shake requests
	for request in _shake_requests:
		_process_shake_request(request)
	_shake_requests.clear()

	# Process flash requests
	for request in _flash_requests:
		_process_flash_request(request)
	_flash_requests.clear()

	# Decay and apply trauma
	_trauma = maxf(_trauma - TRAUMA_DECAY_RATE * delta, 0.0)
	# ... apply shake to camera ...

func _process_shake_request(event_data: Dictionary) -> void:
	var payload: Dictionary = event_data.get("payload", {})
	var entity_id: StringName = StringName(str(payload.get("entity_id", "")))

	if not _is_player_entity(entity_id):
		return
	if _is_transition_blocked():
		return

	var trauma_amount: float = float(payload.get("trauma_amount", 0.0))
	add_trauma(trauma_amount)

func _process_flash_request(event_data: Dictionary) -> void:
	# ... similar gating and processing ...
```

---

## Phase 7: Unsubscribe Array & Preload

**Goal**: Consolidate cleanup logic, use compile-time loading.

### Changes to M_VFXManager

Replace individual unsubscribe fields:
```gdscript
# Before:
var _unsubscribe_health: Callable
var _unsubscribe_landed: Callable
var _unsubscribe_death: Callable

# After:
var _event_unsubscribes: Array[Callable] = []
```

Update subscription:
```gdscript
_event_unsubscribes.append(U_ECS_EVENT_BUS.subscribe(U_ECSEventNames.EVENT_SCREEN_SHAKE_REQUEST, _on_screen_shake_request))
_event_unsubscribes.append(U_ECS_EVENT_BUS.subscribe(U_ECSEventNames.EVENT_DAMAGE_FLASH_REQUEST, _on_damage_flash_request))
```

Update cleanup:
```gdscript
func _exit_tree() -> void:
	for unsubscribe in _event_unsubscribes:
		if unsubscribe.is_valid():
			unsubscribe.call()
	_event_unsubscribes.clear()
```

Add preload for damage flash scene:
```gdscript
const DAMAGE_FLASH_SCENE := preload("res://scenes/ui/ui_damage_flash_overlay.tscn")

# In _ready(), replace load() with:
var flash_instance: CanvasLayer = DAMAGE_FLASH_SCENE.instantiate()
```

---

## Phase 8: Testing Improvements

**Goal**: Comprehensive test coverage for new gating and behavior.

### New Test Files

1. `tests/integration/vfx/test_vfx_player_gating.gd` - Verify only player entity triggers VFX
2. `tests/integration/vfx/test_vfx_transition_gating.gd` - Verify VFX blocked during transitions
3. `tests/unit/managers/helpers/test_screen_shake.gd` - Deterministic tests with seed
4. `tests/unit/managers/helpers/test_damage_flash.gd` - Alpha correctness tests

### Update Existing Tests

Update `tests/unit/managers/test_vfx_manager.gd`:
- Use new VFX request events instead of gameplay events
- Add gating verification tests

---

## Phase 9: UI Settings Preview

**Goal**: Add live preview to VFX settings (matching audio settings pattern).

### Add Preview Methods to M_VFXManager

```gdscript
var _preview_settings: Dictionary = {}
var _is_previewing: bool = false

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
```

### Update UI_VFXSettingsOverlay

Add preview functionality (similar to `ui_audio_settings_tab.gd` lines 466-491):

```gdscript
var _vfx_manager: M_VFXManager = null

func _ready() -> void:
	# ... existing setup ...
	_vfx_manager = U_ServiceLocator.try_get_service(StringName("vfx_manager")) as M_VFXManager

func _exit_tree() -> void:
	_clear_vfx_settings_preview()
	# ... existing cleanup ...

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

func _on_cancel_pressed() -> void:
	U_UISoundPlayer.play_cancel()
	_has_local_edits = false
	_clear_vfx_settings_preview()
	_close_overlay()

func _update_vfx_settings_preview_from_ui() -> void:
	if _vfx_manager == null:
		return
	_vfx_manager.set_vfx_settings_preview({
		"screen_shake_enabled": _shake_enabled_toggle.button_pressed if _shake_enabled_toggle != null else true,
		"screen_shake_intensity": _intensity_slider.value if _intensity_slider != null else 1.0,
		"damage_flash_enabled": _flash_enabled_toggle.button_pressed if _flash_enabled_toggle != null else true,
	})

func _clear_vfx_settings_preview() -> void:
	if _vfx_manager == null:
		return
	_vfx_manager.clear_vfx_settings_preview()
```

---

## Phase 10: Documentation Updates

**Goal**: Update docs to reflect new architecture.

### Update AGENTS.md

Add VFX Manager patterns section:
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

### Update DEV_PITFALLS.md

Add VFX-specific pitfalls:
```markdown
## VFX Pitfalls

### Alpha Bug
- ColorRect.color.a multiplies with modulate.a
- Set color.a = 1.0 in scene, control visibility via modulate.a only

### Tween Pause Mode
- Use `tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)` for effects that should continue during pause

### Preload vs Load
- Use `preload()` for VFX scenes loaded at startup
- `load()` only for dynamically determined paths
```

---

## Verification Strategy

1. **Phase 1**: Run existing VFX tests, verify event flow
2. **Phase 2**: Verify ServiceLocator registration, test injection
3. **Phase 3**: Test player-only gating, transition blocking
4. **Phase 4**: Test resource calculations, verify tuning works
5. **Phase 5**: Visual test - damage flash should be clearly visible (alpha ~0.3)
6. **Phase 6**: Test request queue ordering
7. **Phase 7**: Verify cleanup, no memory leaks
8. **Phase 8**: Full test suite pass
9. **Phase 9**: Manual test - slider changes trigger test shake
10. **Phase 10**: Documentation review

**Test command**:
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

---

## Implementation Order

**Critical path** (sequential): Phase 1 → Phase 2 → Phase 3

**Parallelizable after Phase 3**:
- Phase 4 (resources)
- Phase 5 (helper fixes)
- Phase 6 (request queue)
- Phase 7 (cleanup)

**Final phases**:
- Phase 8 (testing) - after Phases 1-7
- Phase 9 (UI preview) - after Phase 1
- Phase 10 (docs) - last
